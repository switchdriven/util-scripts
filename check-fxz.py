#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import subprocess
import json
import ipaddress
import argparse
from pprint import pprint

rt_command = "/sbin/route"
sc_command = "/usr/sbin/scutil"
ip_command = "/opt/homebrew/bin/ip"

# IPv4 local networks reachable via gateway (need route del + route add if uncovered)
GATEWAY_NETWORKS_V4: list[ipaddress.IPv4Network] = [
    ipaddress.ip_network('192.168.1.0/24'),
    ipaddress.ip_network('192.168.2.0/24'),
    ipaddress.ip_network('192.168.3.0/24'),
]

# Directly connected networks (only need route del, no route add needed)
DIRECT_NETWORKS_V4: list[ipaddress.IPv4Network] = [
    ipaddress.ip_network('10.211.55.0/24'),
]

# All local networks (used for FXZ route matching)
LOCAL_NETWORKS_V4 = GATEWAY_NETWORKS_V4 + DIRECT_NETWORKS_V4

# IPv6 half-default routes that VPN adds even when IPv6 is disabled
IPV6_HALF_DEFAULTS: list[ipaddress.IPv6Network] = [
    ipaddress.ip_network('::/1'),
    ipaddress.ip_network('8000::/1'),
]


def get_routing_table(addr_family: str) -> list[dict]:
    """Get routing table entries for the specified address family."""
    opt_str = {'ip_v4': '-4', 'ip_v6': '-6'}
    result = []

    if addr_family in opt_str:
        process = subprocess.Popen(
            [ip_command, '-j', opt_str[addr_family], 'route'],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        out, err = process.communicate()
        entries = json.loads(out)

        for row in entries:
            row['addr_family'] = addr_family
            result.append(row)
    return result


def get_fxz_interface() -> str | None:
    """Get the FXZ VPN interface name. Returns the first utun with multiple addresses."""
    process = subprocess.Popen(
        [ip_command, '-j', 'addr'],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    out, err = process.communicate()

    interfaces = json.loads(out)
    for iface in interfaces:
        if 'utun' in iface['ifname'] and len(iface['addr_info']) > 1:
            return iface['ifname']

    return None


def get_local_ipv6_networks(interface: str = 'en0') -> list[ipaddress.IPv6Network]:
    """Auto-detect local IPv6 /64 networks from the specified interface."""
    process = subprocess.Popen(
        [ip_command, '-j', '-6', 'addr', 'show', interface],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    out, err = process.communicate()

    networks = []
    try:
        interfaces = json.loads(out)
    except json.JSONDecodeError:
        return networks

    for iface in interfaces:
        for addr_info in iface.get('addr_info', []):
            addr_str = addr_info.get('local', '')
            prefixlen = addr_info.get('prefixlen', 64)

            try:
                addr = ipaddress.ip_address(addr_str)
            except ValueError:
                continue

            # Skip link-local addresses (fe80::/10)
            if addr.is_link_local:
                continue

            # Extract /64 network from the address
            network = ipaddress.ip_network(f'{addr_str}/{prefixlen}', strict=False)
            # Normalize to /64 if prefix is longer
            if network.prefixlen > 64:
                network = ipaddress.ip_network(f'{addr_str}/64', strict=False)
            if network not in networks:
                networks.append(network)

    return networks


def is_local_route(dst: str, local_networks_v4: list[ipaddress.IPv4Network],
                   local_networks_v6: list[ipaddress.IPv6Network]) -> bool:
    """Check if a route destination falls within any local network."""
    try:
        # Handle host routes without prefix length
        if '/' not in dst:
            addr = ipaddress.ip_address(dst)
            host_net = ipaddress.ip_network(f'{dst}/{addr.max_prefixlen}')
        else:
            host_net = ipaddress.ip_network(dst, strict=False)

        if isinstance(host_net, ipaddress.IPv4Network):
            return any(host_net.subnet_of(net) for net in local_networks_v4)
        else:
            return any(host_net.subnet_of(net) for net in local_networks_v6)
    except ValueError:
        return False


def get_default_gateway(fxz_interface: str) -> tuple[str, str] | None:
    """Get the default IPv4 gateway that's NOT via the FXZ interface.
    Returns (gateway_ip, device) or None."""
    for route in get_routing_table('ip_v4'):
        if route.get('dst') == 'default' and route.get('dev') != fxz_interface:
            gw = route.get('gateway', '')
            dev = route.get('dev', '')
            if gw and dev:
                return (gw, dev)
    return None


def get_covered_networks(local_routes: list[dict],
                         local_networks: list) -> set[int]:
    """Return indices of local networks that have at least one matching FXZ route."""
    covered = set()
    for route in local_routes:
        dst = route.get('dst', '')
        try:
            if '/' not in dst:
                addr = ipaddress.ip_address(dst)
                net = ipaddress.ip_network(f'{dst}/{addr.max_prefixlen}')
            else:
                net = ipaddress.ip_network(dst, strict=False)
            for i, local_net in enumerate(local_networks):
                if type(net) == type(local_net) and net.subnet_of(local_net):
                    covered.add(i)
        except ValueError:
            continue
    return covered


def get_ipv6_half_default_routes(fxz_routes: list[dict]) -> list[dict]:
    """Get IPv6 half-default routes (::/1, 8000::/1) via FXZ interface."""
    result = []
    for route in fxz_routes:
        if route.get('addr_family') != 'ip_v6':
            continue
        dst = route.get('dst', '')
        try:
            net = ipaddress.ip_network(dst, strict=False)
            if any(net == default for default in IPV6_HALF_DEFAULTS):
                result.append(route)
        except ValueError:
            continue
    return result


def normalize_dst(dst: str, addr_family: str) -> str:
    """Remove /32 (IPv4) or /128 (IPv6) suffix from host route destinations."""
    if addr_family == 'ip_v4' and dst.endswith('/32'):
        return dst[:-3]
    if addr_family == 'ip_v6' and dst.endswith('/128'):
        return dst[:-4]
    return dst


def main():
    parser = argparse.ArgumentParser(description='Check & fix routing when using FXZ VPN')
    parser.add_argument('-d', '--debug', action='store_true', help='show debug info')
    parser.add_argument('-f', '--fix', action='store_true', help='generate fix routing commands')
    parser.add_argument('-i', '--netif', help='target network interface (auto-detected if omitted)')
    args = parser.parse_args()

    chk_i = args.netif if args.netif else get_fxz_interface()

    if chk_i is None:
        print("No FXZ interface found.")
        sys.exit(1)

    # Auto-detect local IPv6 networks from en0
    local_networks_v6 = get_local_ipv6_networks('en0')

    if args.debug:
        print(f"FXZ interface = {chk_i}")
        print(f"Local IPv4 networks = {[str(n) for n in LOCAL_NETWORKS_V4]}")
        print(f"Local IPv6 networks = {[str(n) for n in local_networks_v6]}")

    # Collect routes through the FXZ interface
    fxz_routes = []
    for addr_family in ('ip_v4', 'ip_v6'):
        for route in get_routing_table(addr_family):
            if route.get('dev') == chk_i:
                fxz_routes.append(route)

    # Filter to local network routes only
    local_routes = []
    for route in fxz_routes:
        dst = route.get('dst', '')
        if is_local_route(dst, LOCAL_NETWORKS_V4, local_networks_v6):
            local_routes.append(route)

    if args.debug:
        print(f"\nFXZ routes total: {len(fxz_routes)}")
        print(f"Local routes to fix: {len(local_routes)}")
        pprint(local_routes)

    # Determine which gateway networks have no specific FXZ routes
    # (captured by broad VPN routes like 192.0.0/3 instead)
    covered_v4 = get_covered_networks(local_routes, GATEWAY_NETWORKS_V4)
    covered_v6 = get_covered_networks(local_routes, local_networks_v6)
    uncovered_v4 = [net for i, net in enumerate(GATEWAY_NETWORKS_V4) if i not in covered_v4]
    uncovered_v6 = [net for i, net in enumerate(local_networks_v6) if i not in covered_v6]

    # IPv6 half-default routes added by VPN (should be removed when IPv6 is disabled)
    ipv6_half_defaults = get_ipv6_half_default_routes(fxz_routes)

    if args.debug:
        if uncovered_v4:
            print(f"Uncovered IPv4 networks (need route add): {[str(n) for n in uncovered_v4]}")
        if uncovered_v6:
            print(f"Uncovered IPv6 networks (need route add): {[str(n) for n in uncovered_v6]}")

    if args.fix:
        # Delete specific FXZ routes for local networks
        for route in local_routes:
            dst = normalize_dst(route['dst'], route['addr_family'])
            if route['addr_family'] == 'ip_v6':
                print(f'ip -6 route del {dst} dev {chk_i}')
            else:
                print(f'ip route del {dst} dev {chk_i}')

        # Delete IPv6 half-default routes added by VPN (when IPv6 is disabled on FXZ)
        for route in ipv6_half_defaults:
            dst = normalize_dst(route['dst'], route['addr_family'])
            print(f'ip -6 route del {dst} dev {chk_i}')

        # Add routes for all gateway-reachable local networks
        # (some may already exist via en0 and fail harmlessly)
        gw_info = get_default_gateway(chk_i)
        if gw_info:
            gw, dev = gw_info
            for net in GATEWAY_NETWORKS_V4:
                print(f'ip route add {net} via {gw} dev {dev}')

    if not args.fix:
        v4_count = sum(1 for r in local_routes if r['addr_family'] == 'ip_v4')
        v6_count = sum(1 for r in local_routes if r['addr_family'] == 'ip_v6')
        print(f"{len(local_routes)} Dst Found (IPv4: {v4_count}, IPv6: {v6_count})")
        if ipv6_half_defaults:
            print(f"IPv6 half-default routes via FXZ: {len(ipv6_half_defaults)} (use --fix to remove)")


if __name__ == '__main__':
    main()
