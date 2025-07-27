#!/usr/bin/env python3
import os
import json
import time
import signal
import errno
import threading
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

import uvloop
import asyncio

from clickhouse_connect import get_client

STATE_PATH = os.getenv('STATE_PATH', '/state/offset.json')
LOG_FILE = os.getenv('LOG_FILE', '/data/caddy/logs/web.log')

CH_URL = os.getenv('CLICKHOUSE_URL', 'http://clickhouse:8123')
CH_USER = os.getenv('CLICKHOUSE_USER', 'default')
CH_PASS = os.getenv('CLICKHOUSE_PASSWORD', '')
CH_DB = os.getenv('CLICKHOUSE_DATABASE', 'logs')
CH_TABLE = os.getenv('CLICKHOUSE_TABLE', 'caddy_requests')

BATCH_SIZE = int(os.getenv('BATCH_SIZE', '1000'))
FLUSH_INTERVAL = float(os.getenv('FLUSH_INTERVAL_SEC', '2'))
TZ = ZoneInfo(os.getenv('TZ', 'Asia/Singapore'))

# clickhouse-connect 的 insert 需要列名顺序
COLUMNS = [
    'ts', 'level', 'logger', 'msg',
    'remote_ip', 'remote_port', 'method', 'host', 'uri',
    'status', 'duration_ms', 'bytes_sent',
    'user_agent', 'err_id', 'err_trace'
]

stop_event = threading.Event()


def load_state():
    try:
        with open(STATE_PATH, 'r') as f:
            st = json.load(f)
            return st.get('inode'), st.get('position', 0)
    except FileNotFoundError:
        return None, 0
    except Exception:
        return None, 0


def save_state(inode, pos):
    tmp = {'inode': inode, 'position': pos}
    os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
    with open(STATE_PATH, 'w') as f:
        json.dump(tmp, f)


def open_log(inode_expected=None, position=0):
    """
    打开 LOG_FILE，并复位到 position。
    处理 inode 变化（日志轮转）。
    """
    f = open(LOG_FILE, 'r', encoding='utf-8', errors='ignore')
    st = os.fstat(f.fileno())
    if inode_expected is not None and st.st_ino != inode_expected:
        # 日志轮转，新文件，从头开始
        position = 0
    # 如果文件比 position 小（被truncate），也从头
    if st.st_size < position:
        position = 0
    f.seek(position, 0)
    return f, st.st_ino


def to_datetime(ts_float):
    # Caddy ts 是浮点秒（UTC）
    # ClickHouse 列是 DateTime64(3,'Asia/Singapore'), 用本地化时间戳
    dt_utc = datetime.fromtimestamp(ts_float, tz=timezone.utc)
    return dt_utc.astimezone(TZ)


def extract_first(hdrs, key):
    try:
        v = hdrs.get(key)
        if isinstance(v, list):
            return v[0]
        if isinstance(v, str):
            return v
    except Exception:
        pass
    return ""


def transform(rec):
    """
    rec 是 caddy 一行 JSON dict
    返回 tuple 对应 COLUMNS 顺序
    """
    # 有些行可能不是 access
    level = rec.get('level', '')
    logger = rec.get('logger', '')
    msg = rec.get('msg', '')

    # 过滤非 http.log.access 的行可在这里判断，或者上游判断
    request = rec.get('request', {}) or {}
    headers = request.get('headers', {}) or {}

    ts = rec.get('ts', 0.0)
    try:
        ts_dt = to_datetime(float(ts))
    except Exception:
        ts_dt = datetime.now(TZ)

    duration = rec.get('duration', None)
    if duration is None:
        # 有的日志字段是 duration_ms 直接 float
        duration_ms = float(rec.get('duration_ms', 0))  # fallback
    else:
        duration_ms = float(duration) * 1000.0

    row = (
        ts_dt,                                 # ts
        str(level),                            # level
        str(logger),                           # logger
        str(msg),                              # msg
        str(request.get('remote_ip', '')),     # remote_ip
        int(request.get('remote_port', 0) or 0),   # remote_port
        str(request.get('method', '')),        # method
        str(request.get('host', '')),          # host
        str(request.get('uri', '')),           # uri
        int(rec.get('status', 0) or 0),        # status
        float(duration_ms),                    # duration_ms
        int(rec.get('size', rec.get('bytes_sent', 0)) or 0),  # bytes_sent
        str(extract_first(headers, 'User-Agent')),            # user_agent
        str(rec.get('err_id', '')),            # err_id
        str(rec.get('err_trace', ''))          # err_trace
    )
    return row


async def flusher(queue):
    """
    定时/积累批量 flush 到 ClickHouse
    """
    client = get_client(
        host=CH_URL.split('://')[-1].split(':')[0],
        port=int(CH_URL.split(':')[-1]) if ':' in CH_URL.split('://')[-1] else 8123,
        username=CH_USER,
        password=CH_PASS,
        database=CH_DB,
        secure=CH_URL.startswith('https'),
    )

    batch = []
    last_flush = time.time()

    while not stop_event.is_set():
        try:
            item = await asyncio.wait_for(queue.get(), timeout=FLUSH_INTERVAL)
            batch.append(item)
        except asyncio.TimeoutError:
            pass

        now = time.time()
        if batch and (len(batch) >= BATCH_SIZE or now - last_flush >= FLUSH_INTERVAL):
            try:
                client.insert(CH_TABLE, batch, column_names=COLUMNS)
            except Exception as e:
                # 打印错误，继续尝试（避免丢失），可考虑写死信队列
                print(f"[ERROR] insert failed: {e}", flush=True)
            else:
                batch.clear()
                last_flush = now

    # 退出前 flush 一次
    if batch:
        try:
            client.insert(CH_TABLE, batch, column_names=COLUMNS)
        except Exception as e:
            print(f"[ERROR] final insert failed: {e}", flush=True)


async def reader(queue):
    """
    读取文件，按行解析 JSON，送入队列
    处理轮转/offset
    """
    inode, pos = load_state()
    f, inode = open_log(inode, pos)
    offset = pos

    while not stop_event.is_set():
        line = f.readline()
        if not line:
            # 可能 EOF 或轮转
            try:
                st = os.stat(LOG_FILE)
            except OSError as e:
                if e.errno == errno.ENOENT:
                    # 文件暂时不存在
                    await asyncio.sleep(0.5)
                    continue
                else:
                    raise

            if st.st_ino != inode:
                # 轮转了
                f.close()
                f, inode = open_log(inode_expected=None, position=0)
                offset = 0
                save_state(inode, offset)
            else:
                await asyncio.sleep(0.2)
            continue

        offset += len(line.encode('utf-8', errors='ignore'))
        # 一行 JSON
        try:
            rec = json.loads(line)
        except Exception:
            # 丢弃坏行
            continue

        # 只要 access
        if rec.get('logger') != 'http.log.access':
            continue

        try:
            row = transform(rec)
        except Exception:
            continue

        await queue.put(row)
        # 定期保存 offset
        if offset % (1024 * 1024) < len(line):  # 每 ~1MB 保存一次，简单点
            save_state(inode, offset)


def handle_signal(*_):
    stop_event.set()


def main():
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    uvloop.install()
    loop = asyncio.get_event_loop()

    queue = asyncio.Queue(maxsize=50000)
    tasks = [
        loop.create_task(reader(queue)),
        loop.create_task(flusher(queue)),
    ]

    try:
        loop.run_until_complete(asyncio.gather(*tasks))
    finally:
        for t in tasks:
            t.cancel()
        loop.stop()
        loop.close()


if __name__ == '__main__':
    main()
