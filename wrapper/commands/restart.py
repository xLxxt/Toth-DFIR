from utils import config, docker_manager


def run(args):
    svc = config.service(args.profile)
    code = docker_manager.restart(svc)
    if code == 0:
        print(f"[+] {svc} restarted")
    return code
