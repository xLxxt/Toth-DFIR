from utils import config, docker_manager


def run(args):
    svc = config.service(args.profile)
    code = docker_manager.stop(svc)
    if code == 0:
        print(f"[+] {svc} stopped")
    return code
