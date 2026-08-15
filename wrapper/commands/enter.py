from utils import config, docker_manager


def run(args):
    svc = config.service(args.profile)
    command = args.cmd if args.cmd else ["/bin/bash"]
    return docker_manager.enter(svc, command)
