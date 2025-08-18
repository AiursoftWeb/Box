#!/usr/bin/env python3
import os
import sys
import yaml


def is_stateless(conf: dict) -> bool:
    """
    Determines if a service is stateless based on the following criteria:
    - stop_grace_period is '20s'
    - or deploy.replicas > 2
    - or deploy.update_config.order is 'start-first'
    """
    sgp = conf.get('stop_grace_period')
    if isinstance(sgp, str) and sgp.endswith('s') and sgp[:-1] == '20':
        return True
    replicas = conf.get('deploy', {}).get('replicas')
    if isinstance(replicas, int) and replicas > 2:
        return True
    order = conf.get('deploy', {}).get('update_config', {}).get('order')
    if order == 'start-first':
        return True
    return False


def validate_service(name: str, conf: dict):
    """
    Validates the service configuration based on its type (stateless/stateful),
    and returns a tuple of (is_stateless, error_list).
    """
    errors = []
    stateless = is_stateless(conf)
    upd = conf.get('deploy', {}).get('update_config', {})

    if stateless:
        # Rules for stateless services
        if conf.get('stop_grace_period') != '20s':
            errors.append("stop_grace_period should be '20s'")
        if upd.get('order') != 'start-first':
            errors.append("deploy.update_config.order should be 'start-first'")
        if upd.get('delay') != '5s':
            errors.append("deploy.update_config.delay should be '5s'")
    else:
        # Rules for stateful services
        if conf.get('stop_grace_period') != '60s':
            errors.append("stop_grace_period should be '60s'")
        if upd.get('order') != 'stop-first':
            errors.append("deploy.update_config.order should be 'stop-first'")
        if upd.get('delay') != '60s':
            errors.append("deploy.update_config.delay should be '60s'")
        replicas = conf.get('deploy', {}).get('replicas')
        if replicas not in (None, 1):
            errors.append("deploy.replicas should not exist or should be 1")

    return stateless, errors


def process_file(path: str) -> bool:
    """
    Processes a single docker-compose file.
    Returns True if errors are found, otherwise False.
    """
    print(f"\n→ Checking file: {path}")
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f) or {}
    except Exception as e:
        print(f"  ❌ Failed to read or parse YAML file: {e}")
        return True  # Treat file read/parse failure as an error

    services = data.get('services')
    if not isinstance(services, dict):
        print("  ⚠️ 'services' key not found or is not a dictionary, skipping")
        return False  # If 'services' key is missing, we don't consider it a linting error

    file_has_error = False
    for svc_name, svc_conf in services.items():
        stateless, errs = validate_service(svc_name, svc_conf or {})
        svc_type = 'Stateless' if stateless else 'Stateful'
        print(f"  Service '{svc_name}' detected as {svc_type}")
        if errs:
            file_has_error = True
            print("    ❌ Configuration does not meet standards:")
            for e in errs:
                print(f"      - {e}")
    
    return file_has_error


def main(root='./stage4'):
    """
    Walks through the directory and checks all docker-compose files.
    Returns True if any file fails the check.
    """
    overall_has_error = False
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            if fn in ('docker-compose.yml', 'docker-compose.yaml'): # Support both .yaml and .yml extensions
                # process_file returning True indicates an error was found
                if process_file(os.path.join(dirpath, fn)):
                    overall_has_error = True
    
    return overall_has_error


if __name__ == '__main__':
    # Determine the root directory to scan
    if len(sys.argv) > 1:
        root_dir = sys.argv[1]
    else:
        # If no argument is provided, show usage information
        print("Usage: python lint_script.py <target_directory>")
        sys.exit(1) # Invalid arguments should also exit with a non-zero code

    if not os.path.isdir(root_dir):
        print(f"Error: Directory '{root_dir}' does not exist.")
        sys.exit(1)

    # Execute the main logic
    has_errors = main(root_dir)

    # Set the exit code based on the result
    if has_errors:
        print("\n💥 Linter found errors. Exiting with a non-zero status code.")
        sys.exit(1)
    else:
        print("\n✅ Linter finished successfully. No errors found.")
        sys.exit(0)