import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from commands import case as case_cmd
from commands import list as list_cmd
from commands import shell as shell_cmd
from commands import enter, remove, restart, start, status, stop, update
from commands import exec as exec_cmd
from utils import config
from utils.docker_manager import DockerError


def add_profile_argument(parser, default=config.DEFAULT_PROFILE):
    parser.add_argument("profile", nargs="?", default=default, choices=config.PROFILES)


def add_exec_arguments(parser):
    add_profile_argument(parser)
    parser.add_argument("cmd", nargs=argparse.REMAINDER)


def build_parser():
    parser = argparse.ArgumentParser(prog="toth", description="Blue Team Docker distribution for DFIR")
    parser.add_argument("--version", action="version", version=f"toth {config.VERSION}")
    sub = parser.add_subparsers(dest="command", required=True)

    p_list = sub.add_parser("list", help="list available profiles")
    p_list.set_defaults(func=list_cmd.run)

    p_status = sub.add_parser("status", help="show container status")
    p_status.set_defaults(func=status.run)

    p_start = sub.add_parser("start", help="start a container")
    add_profile_argument(p_start)
    p_start.set_defaults(func=start.run)

    p_enter = sub.add_parser("enter", help="enter an existing container")
    add_exec_arguments(p_enter)
    p_enter.set_defaults(func=enter.run)

    p_restart = sub.add_parser("restart", help="restart an existing container")
    add_profile_argument(p_restart)
    p_restart.set_defaults(func=restart.run)

    p_stop = sub.add_parser("stop", help="stop a container")
    add_profile_argument(p_stop)
    p_stop.set_defaults(func=stop.run)

    p_remove = sub.add_parser("remove", aliases=["rm"], help="remove an existing container")
    add_profile_argument(p_remove)
    p_remove.set_defaults(func=remove.run)

    p_exec = sub.add_parser("exec", help="open a shell or run a command")
    add_exec_arguments(p_exec)
    p_exec.set_defaults(func=exec_cmd.run)

    p_shell = sub.add_parser("shell", help="open an interactive shell")
    add_exec_arguments(p_shell)
    p_shell.set_defaults(func=shell_cmd.run)

    p_update = sub.add_parser("update", help="pull images or build them locally")
    p_update.add_argument("profile", nargs="?", default="all", choices=list(config.PROFILES) + ["all"])
    p_update.add_argument("--build", action="store_true", help="build images locally instead of pulling from GHCR")
    p_update.set_defaults(func=update.run)

    p_case = sub.add_parser("case", help="manage cases (evidence/output scoping)")
    case_sub = p_case.add_subparsers(dest="case_command", required=True)

    p_case_new = case_sub.add_parser("new", help="create and activate a new case")
    p_case_new.add_argument("name")
    p_case_new.set_defaults(func=case_cmd.new)

    p_case_list = case_sub.add_parser("list", help="list existing cases")
    p_case_list.set_defaults(func=case_cmd.list_cmd)

    p_case_use = case_sub.add_parser("use", help="switch the active case")
    p_case_use.add_argument("name")
    p_case_use.set_defaults(func=case_cmd.use)

    p_case_current = case_sub.add_parser("current", help="show the active case")
    p_case_current.set_defaults(func=case_cmd.current)

    return parser


def main():
    args = build_parser().parse_args()
    try:
        return args.func(args) or 0
    except DockerError as exc:
        print(f"[!] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
