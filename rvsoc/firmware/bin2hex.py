#!/usr/bin/env python3
"""Turn a raw firmware image into 32-bit little-endian words for $readmemh."""

import sys

src, dst, words = sys.argv[1], sys.argv[2], int(sys.argv[3])
data = open(src, "rb").read()
used = len(data)
if used > words * 4:
    sys.exit(f"{src}: {used} bytes does not fit in {words * 4} bytes of RAM")
data += b"\0" * (words * 4 - used)   # fill the whole RAM so $readmemh sees every word

with open(dst, "w") as f:
    for i in range(0, len(data), 4):
        f.write(f"{int.from_bytes(data[i:i + 4], 'little'):08x}\n")
print(f"{src}: {used} of {words * 4} bytes")
