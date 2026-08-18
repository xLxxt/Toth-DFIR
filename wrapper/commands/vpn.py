from utils import case as case_utils
from utils import vpn as vpn_utils


def add(args):
    config_path, creds_path, kind = vpn_utils.add_vpn_config(
        args.case, args.file, creds_file=args.creds, force=args.force
    )
    label = "OpenVPN" if kind == "openvpn" else "WireGuard"
    print(f"[+] {label} config added to case '{args.case}': {config_path}")
    if creds_path is not None:
        print(f"[+] creds stored: {creds_path} (permissions set to 600)")
    return 0


def remove(args):
    vpn_utils.remove_vpn_config(args.case)
    print(f"[+] VPN config removed from case '{args.case}'")
    return 0


def show(args):
    case_name = args.case
    if case_name is None:
        case_name = case_utils.active_case()
        if case_name is None:
            print(
                "No case is currently active (legacy workspace mode). "
                "Specify a case: toth vpn show <case>"
            )
            return 0

    config_path, creds_path, kind = vpn_utils.vpn_paths(case_name)
    if kind is None:
        print(f"No VPN config set for case '{case_name}'.")
        return 0

    label = "OpenVPN" if kind == "openvpn" else "WireGuard"
    print(f"case: {case_name}")
    print(f"kind: {label}")
    print(f"config: {config_path}")
    print(f"creds: {'present' if creds_path is not None else 'none'}")
    return 0
