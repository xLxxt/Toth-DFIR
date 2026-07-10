from utils import config, docker_manager


def run(args):
    svc = config.service(args.profile)
    code = docker_manager.remove(svc)
    if code == 0:
        print(f"[+] {svc} removed")
    return code
