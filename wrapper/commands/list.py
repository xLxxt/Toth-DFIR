from utils import config


def run(_args):
    print("Available profiles:\n")
    print(f"  {'PROFILE':<8} {'SERVICE':<14} {'LOCAL IMAGE':<20} REMOTE IMAGE")
    for profile, service in config.PROFILES.items():
        default = " (default)" if profile == config.DEFAULT_PROFILE else ""
        print(
            f"  {profile:<8} {service:<14} {config.image(profile):<20} "
            f"{config.remote_image(profile)}{default}"
        )
    return 0
