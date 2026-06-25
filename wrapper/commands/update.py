from utils import config, docker_manager


def _profiles(selected):
    if selected == "all":
        return list(config.PROFILES)
    return [selected]


def run(args):
    action = docker_manager.build if args.build else docker_manager.pull
    for profile in _profiles(args.profile):
        code = action(profile)
        if code != 0:
            return code
    return 0
