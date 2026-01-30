#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 
# 始業時刻を与えるか現在時刻から規定の終業時刻を表示するスクリプト

import argparse
import re
import sys
import json
from datetime import datetime, timedelta

work_time = 8.5

def main():
    parser = argparse.ArgumentParser(description="show time to go home")
    parser.add_argument("-s", "--starttime", type=str, help="start time")
    parser.add_argument("-r", "--referencetime", type=str, help="referencetime for overtime calculation (test purpose)")
    parser.add_argument("-o", "--overtime", action="store_true", help="show over time (use with starttime option)")
    parser.add_argument("-j", "--json", action="store_true", help="output json")
    parser.add_argument("-d", "--debug", action="store_true", help="use debug")
    args = parser.parse_args()

    today = datetime.today()
    today_str = today.strftime("%Y-%m-%d")

    if args.starttime : 
        pattern = r"^\d{1,2}:\d{1,2}$"

        if not re.match(pattern, args.starttime):
            sys.stderr.write(f"error : incorrect time format. only 'hh:mm' format is acceptable: {args.starttime}\n")
            return(-1)

        time_str = f"{today_str} {args.starttime}"
        start_time = datetime.strptime(time_str, "%Y-%m-%d %H:%M")
    else :
        start_time = datetime.now()

    end_time = start_time + timedelta(hours=work_time)

    over_time = "00:00"
    now_time = None
    if args.overtime :
        # overtime計算用の時刻を決定
        if args.referencetime:
            # referencetimeはhh:mm形式
            pattern = r"^\d{1,2}:\d{1,2}$"
            if not re.match(pattern, args.referencetime):
                sys.stderr.write(f"error : incorrect referencetime format. only 'hh:mm' format is acceptable: {args.referencetime}\n")
                return(-1)
            ref_time_str = f"{today_str} {args.referencetime}"
            now_time = datetime.strptime(ref_time_str, "%Y-%m-%d %H:%M")
        else:
            now_time = datetime.now()
        # Over time計算（マイナスも対応）
        time_diff = now_time - end_time
        total_minutes = int(time_diff.total_seconds() // 60)
        sign = "-" if total_minutes < 0 else ""
        total_minutes = abs(total_minutes)
        diff_hour = total_minutes // 60
        diff_min = total_minutes % 60
        over_time = f"{sign}{diff_hour:02}:{diff_min:02}"
    else:
        now_time = datetime.now()

    if args.debug :
        debug_msg = f"Start time = {start_time.strftime('%H:%M')}, End time = {end_time.strftime('%H:%M')}, Reference time = {now_time.strftime('%H:%M')}, Over time = {over_time}\n"
        sys.stderr.write(debug_msg)

    if args.json : 
        result = {
            "items": [
                {
                    "title": "time to go home",
                    "start-time": start_time.strftime("%H:%M"),
                    "end-time": end_time.strftime("%H:%M"),
                    "over-time": over_time if args.overtime else None
                }
            ]
        }
        print(json.dumps(result))        
    else :
        if args.overtime:
            print(f"EndTime={end_time.strftime('%H:%M')}/OverTime={over_time}")
        else:
            print(f"EndTime={end_time.strftime('%H:%M')}")

    return(0)

if __name__ == "__main__":
    main()
