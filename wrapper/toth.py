import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from commands import start, stop, update
from commands import exec as exec_cmd
from utils import config


def build_parser():
    parser = argparse.ArgumentParser(prog="toth", description="Blue Team Docker distribution for DFIR")
    parser.add_argument("--version", action="version", version=f"toth {config.VERSION}")
    sub = parser.add_subparsers(dest="command", required=True)

    p_start = sub.add_parser("start", help="start a container")
    p_start.add_argument("profile", nargs="?", default=config.DEFAULT_PROFILE, choices=config.PROFILES)
    p_start.set_defaults(func=start.run)

    p_stop = sub.add_parser("stop", help="stop a container")
    p_stop.add_argument("profile", nargs="?", default=config.DEFAULT_PROFILE, choices=config.PROFILES)
    p_stop.set_defaults(func=stop.run)

    p_exec = sub.add_parser("exec", help="open a shell or run a command")
    p_exec.add_argument("profile", nargs="?", default=config.DEFAULT_PROFILE, choices=config.PROFILES)
    p_exec.add_argument("cmd", nargs=argparse.REMAINDER)
    p_exec.set_defaults(func=exec_cmd.run)

    p_update = sub.add_parser("update", help="build or rebuild images")
    p_update.add_argument("profile", nargs="?", default="all", choices=list(config.PROFILES) + ["all"])
    p_update.set_defaults(func=update.run)

    return parser


def main():
    args = build_parser().parse_args()
    sys.exit(args.func(args) or 0)


if __name__ == "__main__":
    main()
