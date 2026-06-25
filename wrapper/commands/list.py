from utils import config


def run(_args):
    print("Available profiles:\n")
    for profile, service in config.PROFILES.items():
        default = " (default)" if profile == config.DEFAULT_PROFILE else ""
        print(f"  {profile:<8} {service:<14} {config.image(profile)}{default}")
    return 0
