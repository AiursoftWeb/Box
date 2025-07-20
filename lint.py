#!/usr/bin/env python3
import os
import sys
import yaml

# 要检查的字段路径及默认值说明（仅用于检测，不做写回）
CHECK_FIELDS = {
    ('deploy', 'resources', 'limits', 'cpus'): "如 '4.0'",
    ('deploy', 'resources', 'limits', 'memory'): "如 '8G'",
    ('deploy', 'update_config', 'order'): "如 'stop-first'",
    ('deploy', 'update_config', 'delay'): "如 '20s'",
    ('stop_grace_period',): "如 '60s'"
}

def check_service(name: str, conf: dict):
    """
    检查单个 service 配置，返回缺失的字段列表
    """
    missing = []
    for path, example in CHECK_FIELDS.items():
        node = conf
        for key in path:
            if not isinstance(node, dict) or key not in node:
                missing.append(".".join(path))
                break
            node = node[key]
    return missing

def process_file(path: str):
    print(f"\n→ 检查文件: {path}")
    with open(path, 'r') as f:
        data = yaml.safe_load(f) or {}

    services = data.get('services')
    if not isinstance(services, dict):
        print("  ⚠️ 未发现 services 节点或格式不正确，跳过")
        return

    any_missing = False
    for svc_name, svc_conf in services.items():
        missing = check_service(svc_name, svc_conf or {})
        if missing:
            any_missing = True
            print(f"  ❌ 服务 '{svc_name}', 位于目录: {os.path.dirname(path)}")
            print(f"  缺少字段:")
            for fld in missing:
                print(f"    - {fld} ({CHECK_FIELDS[tuple(fld.split('.'))]})")
    if not any_missing:
        print("  ✅ 全部 service 都包含所需字段")

def main(root='.'):
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            if fn in ('docker-compose.yml', 'docker.compose.yml'):
                process_file(os.path.join(dirpath, fn))

if __name__ == '__main__':
    root_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
    main(root_dir)
