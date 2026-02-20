#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess
import argparse
from bs4 import BeautifulSoup
from pprint import pprint


proxy_servers = [
    {'name':'none',   'url':"none"},    # no proxy
    {'name':'socks',  'url':"socks://nuc.local:3228"},    # nuc.local socks
    {'name':'squid',  'url':"http://nuc.local:3128"},     # nuc.local squid
    {'name':'local',  'url':"http://localhost:3128"},     # localhost squid
    {'name':'office', 'url':"http://proxy.iiji.jp:8080"}, # IIJ Office proxy
]

proxy_servers_names = [item["name"] for item in proxy_servers]

test_target = "https://www.google.com"
detail_target = "https://env.b4iine.net"
temp_body = "/tmp/curl.out"

def main():
    global test_target

    parser = argparse.ArgumentParser(description="Check socks status")
    parser.add_argument("-d", "--debug", action="store_true", help="use debug")
    parser.add_argument("-p", "--proxy", default=None, help="set proxy server")
    parser.add_argument("-n", "--name", choices=proxy_servers_names, help="proxy server in lists")
    parser.add_argument("-l", "--list", action="store_true", help="show known proxies")
    parser.add_argument("-i", "--isp", action="store_true", help="check connection which isp")
#    parser.add_argument("-t", "--target", default=test_target, help="test target url")
    args = parser.parse_args()

    if args.list :
        pprint(proxy_servers)
        return 0

    if args.name : 
        result = [item for item in proxy_servers if item["name"] == args.name]
        if len(result) > 0 :
            proxy_server = result[0]['url']
            if args.debug :
                print(f"Set proxy to {proxy_server} by name option")
    else :
        if args.proxy is not None:
            proxy_server = args.proxy
            if args.debug :
                print(f"Set proxy to {proxy_server} by proxy option")
        else :
            proxy_server = proxy_servers[0]['url']
            if args.debug :
                print(f"Set proxy to {proxy_server} by default")

    code = 0

    if args.isp : 
        target_url = detail_target
        body_out = temp_body
    else :
        target_url = test_target
        body_out = "/dev/null"

    if args.debug :
        print(f"Trying {target_url} via proxy {proxy_server} ... ", end="")

    if proxy_server == "none" :
        proxy_str = ""
    else : 
        proxy_str = f"--proxy {proxy_server}"

    check_cmd = f"/usr/bin/curl --connect-timeout 5 -s {proxy_str} -o {body_out} -w '%{{http_code}}\n' {target_url}"

    try:
        output = subprocess.check_output(check_cmd, shell=True, stderr=subprocess.STDOUT)
        code = int(output.decode().strip().split("\n").pop(0))

    except subprocess.CalledProcessError as e:
        print(e)
    finally:
        if code == 200:
            if args.isp : 
                try:
                    with open(temp_body, 'r', encoding='utf-8') as f:
                        soup = BeautifulSoup(f.read(), "html.parser")
                        env_1box = soup.find('div', class_='env_1box')
                        isp = env_1box.find('div', class_='txt').text.strip()
                        print(f"OK/{isp}")
                except Exception as e:
                    print(f"error on reading fou {temp_body}: {e}")
            else :
                print("OK")
        else:
            print(f"NG ({code})")

    return 0

if __name__ == "__main__":
    main()
