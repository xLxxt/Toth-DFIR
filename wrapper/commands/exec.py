from utils import config, docker_manager


def run(args):
    svc = config.service(args.profile)
    code = docker_manager.up(svc, gui=args.gui)
    if code != 0:
        return code
    command = args.cmd if args.cmd else ["/bin/bash"]
    return docker_manager.shell(svc, command, gui=args.gui)
