#!/usr/bin/env python3
"""Strip PSID/RSID header + 2-byte embedded load address from a .sid file.

Usage: python strip_sid_header.py <input.sid> <output.bin>
Output is raw C64 binary (no load address), suitable for .import binary in KickAss.
"""
import struct, sys

def strip_sid(inpath, outpath):
    with open(inpath, 'rb') as f:
        data = f.read()

    magic = data[0:4]
    if magic not in (b'PSID', b'RSID'):
        raise ValueError(f"Not a SID file (magic: {magic!r})")

    version = struct.unpack('>H', data[4:6])[0]
    header_size = struct.unpack('>H', data[6:8])[0]
    load_addr_header = struct.unpack('>H', data[8:10])[0]
    init_addr = struct.unpack('>H', data[10:12])[0]
    play_addr = struct.unpack('>H', data[12:14])[0]

    print(f"SID v{version}, header={header_size} bytes")
    print(f"Load=${load_addr_header:04X}, Init=${init_addr:04X}, Play=${play_addr:04X}")

    payload = data[header_size:]

    # If load address in header is 0, first 2 bytes of payload are the load address
    if load_addr_header == 0:
        embedded_load = struct.unpack('<H', payload[0:2])[0]
        print(f"Embedded load address: ${embedded_load:04X}")
        raw = payload[2:]
    else:
        embedded_load = load_addr_header
        raw = payload

    print(f"Raw binary: {len(raw)} bytes (${len(raw):04X})")
    print(f"Range: ${embedded_load:04X}-${embedded_load + len(raw) - 1:04X}")

    with open(outpath, 'wb') as f:
        f.write(raw)
    print(f"Written to {outpath}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.sid> <output.bin>")
        sys.exit(1)
    strip_sid(sys.argv[1], sys.argv[2])
