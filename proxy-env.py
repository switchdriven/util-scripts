#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Manage and check proxy settings
# This script manages the proxy server settings using the networksetup utility.

import os
import subprocess
import argparse
import sys

network_ports = [
    {'name': 'wifi',  'interface': 'Wi-Fi'},
    {'name': 'ether', 'interface': 'USB 10/100/1000 LAN'},
    {'name': 'fxz',   'interface': 'FXZ'},
]

network_ports_names = [item["name"] for item in network_ports]

proxy_config = [
    {'name': 'socks',  'url': 'http://localhost:8080/proxy/proxy-socks.pac'},  # nuc.local socks
    {'name': 'squid',  'url': 'http://localhost:8080/proxy/proxy-squid.pac'},  # nuc.local squid
    {'name': 'local',  'url': 'http://localhost:8080/proxy/proxy-local.pac'},  # localhost squid
    {'name': 'office', 'url': 'http://wpad.iiji.jp/proxy.pac'},                # IIJ Office proxy
]

proxy_config_names = [item["name"] for item in proxy_config]

networksetup = '/usr/sbin/networksetup'


def parse_proxy_output(output: str) -> dict:
    """Parse networksetup -getautoproxyurl output into a dict."""
    result = {}
    for line in output.splitlines():
        if ': ' in line:
            key, value = line.split(': ', 1)
            result[key.strip()] = value.strip()
    return result


def print_proxy_info(interface: str, output: str) -> None:
    """Print proxy info for an interface in a consistent format."""
    parsed = parse_proxy_output(output)
    url = parsed.get('URL', '(none)')
    enabled = parsed.get('Enabled', '(unknown)')
    print(f"{interface}:")
    print(f"  URL:     {url}")
    print(f"  Enabled: {enabled}")


def show_port_proxy(port: str) -> None:
    """Show proxy settings for a specific network interface."""
    try:
        result = subprocess.run(
            [networksetup, "-getautoproxyurl", port],
            capture_output=True, check=True
        )
        print_proxy_info(port, result.stdout.decode('utf-8'))
    except subprocess.CalledProcessError as e:
        print(f"error: {e}")
        sys.exit(1)


def show_all_proxy_status() -> None:
    """Show proxy status for all network interfaces and system proxy."""
    for port in network_ports:
        try:
            result = subprocess.run(
                [networksetup, "-getautoproxyurl", port['interface']],
                capture_output=True, check=True
            )
            print_proxy_info(port['interface'], result.stdout.decode('utf-8'))
        except subprocess.CalledProcessError as e:
            print(f"{port['interface']}:")
            print(f"  error: {e}")
        print()

    print("System (scutil):")
    try:
        result = subprocess.run(
            ["scutil", "--proxy"],
            capture_output=True, check=True
        )
        scutil = {}
        for line in result.stdout.decode('utf-8').splitlines():
            if ' : ' in line:
                key, value = line.strip().split(' : ', 1)
                scutil[key] = value
        enabled = scutil.get('ProxyAutoConfigEnable', '0') == '1'
        url = scutil.get('ProxyAutoConfigURLString', '(null)') if enabled else '(null)'
        print(f"  URL:     {url}")
        print(f"  Enabled: {'Yes' if enabled else 'No'}")
    except subprocess.CalledProcessError as e:
        print(f"  error: {e}")


def show_squid_status() -> None:
    """Show squid configuration and process status."""
    squid_conf = "/opt/homebrew/etc/squid.conf"
    print("Squid Conf:")
    try:
        target = os.readlink(squid_conf)
        print(f"  {target}")
    except OSError:
        if os.path.exists(squid_conf):
            print(f"  {squid_conf} (not a symlink)")
        else:
            print("  (not found)")

    print()
    print("Squid process:")
    try:
        result = subprocess.run(["ps", "-ea"], capture_output=True, check=True)
        lines = [
            line for line in result.stdout.decode('utf-8').splitlines()
            if "squid" in line and "grep" not in line and "proxy-env.py" not in line
        ]
        if lines:
            for line in lines:
                print(f"  {line.strip()}")
        else:
            print("  (not running)")
    except subprocess.CalledProcessError as e:
        print(f"  error: {e}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Manage and check proxy settings")
    parser.add_argument("-d", "--debug", action="store_true", help="enable debug output")
    parser.add_argument("-n", "--name", choices=proxy_config_names, help="proxy config name")
    parser.add_argument("action", choices=['on', 'off', 'show', 'squid', 'list'], help="action to perform")
    parser.add_argument("port", nargs='?', help="target network interface (required for on/off)")
    args = parser.parse_args()

    if args.action == 'show':
        if args.port:
            show_port_proxy(args.port)
        else:
            show_all_proxy_status()
        return

    if args.action == 'squid':
        show_squid_status()
        return

    if args.action == 'list':
        width = max(len(p['name']) for p in proxy_config)
        for p in proxy_config:
            print(f"  {p['name']:<{width}}  {p['url']}")
        return

    # on / off require port
    if not args.port:
        print(f"error: port is required for action '{args.action}'")
        sys.exit(1)

    if args.action == 'on':
        if not args.name:
            print("error: --name is required for action 'on'")
            sys.exit(1)

        result = [item for item in proxy_config if item["name"] == args.name]
        if not result:
            print(f"error: proxy '{args.name}' not found")
            sys.exit(1)

        proxy_server = result[0]['url']

        if args.debug:
            print(f"cmd = {networksetup} -setautoproxyurl {args.port} {proxy_server}")

        try:
            subprocess.run(
                [networksetup, "-setautoproxyurl", args.port, proxy_server],
                check=True
            )
        except subprocess.CalledProcessError as e:
            print(f"error: {e}")
            sys.exit(1)

    if args.debug:
        print(f"cmd = {networksetup} -setautoproxystate {args.port} {args.action}")

    try:
        subprocess.run(
            [networksetup, "-setautoproxystate", args.port, args.action],
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"error: {e}")
        sys.exit(1)

    # Show result after on/off
    show_port_proxy(args.port)


if __name__ == "__main__":
    main()
