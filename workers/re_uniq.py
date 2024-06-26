#!/usr/bin/env python
"""
Keep unique lines matching a regular expression
"""

import re
from sys import stdin, stdout

def main(input_buf, output_buf, args):
    found = -2
    matcher = re.compile(args.pattern)
    for i, line in enumerate(input_buf):
        if matcher.search(line) and (i - found != 1):
            output_buf.write(line)
            found = i
            continue
        if matcher.search(line) and (i - found == 1):
            found = i
            continue

        output_buf.write(line)

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()

    parser.add_argument("pattern", help="pattern to filter with")

    args = parser.parse_args()

    main(stdin, stdout, args)
