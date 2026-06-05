#!/usr/bin/env python3
"""Build Samsung Exynos boot.img with DTBH + SEANDROIDENFORCE.
Usage: python3 mkboot_samsung.py <kernel_image> <ramdisk.gz> <dtbh.bin> <output.img>
"""
import struct, math, sys

if len(sys.argv) != 5:
    print(f"Usage: {sys.argv[0]} <kernel-Image> <ramdisk.gz> <dtbh.bin> <output.img>")
    sys.exit(1)

with open(sys.argv[1],'rb') as f: k = f.read()
with open(sys.argv[2],'rb') as f: r = f.read()
with open(sys.argv[3],'rb') as f: d = f.read()

p = 2048  # page size
h = bytearray(p)
h[0:8] = b'ANDROID!'
struct.pack_into('<I',h,8, len(k));  struct.pack_into('<I',h,12,0x10008000)
struct.pack_into('<I',h,16,len(r));  struct.pack_into('<I',h,20,0x11000000)
struct.pack_into('<I',h,32,0x10000100)
struct.pack_into('<I',h,36,p)
struct.pack_into('<I',h,40,len(d))  # DTBH size (Samsung extension)
struct.pack_into('<I',h,44,0)       # flags
h[48:64] = b'SRPQG24A001RU' + b'\x00'*2
c = b'androidboot.selinux=permissive androidboot.selinux=permissive' + b'\x00'*(512-66)
h[64:576] = c

ko = p
ro = ko + math.ceil(len(k)/p)*p
do_= ro + math.ceil(len(r)/p)*p
so = do_+ math.ceil(len(d)/p)*p

boot = bytearray(so+16)
boot[0:p] = h
boot[ko:ko+len(k)] = k
boot[ro:ro+len(r)] = r
boot[do_:do_+len(d)] = d
boot[so:so+16] = b'SEANDROIDENFORCE'

with open(sys.argv[4],'wb') as f: f.write(boot)
print(f"Boot image: {sys.argv[4]} ({len(boot)} bytes)")
print(f"  Kernel: {len(k)} bytes")
print(f"  Ramdisk: {len(r)} bytes")
print(f"  DTBH: {len(d)} bytes")
print(f"  SEANDROIDENFORCE: appended")
