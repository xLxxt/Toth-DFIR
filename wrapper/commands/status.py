from utils import docker_manager


def run(_args):
    return docker_manager.status()
