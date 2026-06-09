from utils import config, docker_manager


def run(args):
    if args.profile == "all":
        for profile in config.PROFILES:
            code = docker_manager.build(profile)
            if code != 0:
                return code
        return 0
    return docker_manager.build(args.profile)
