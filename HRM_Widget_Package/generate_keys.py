"""
HRM Live Widget - Spider-Man V2 License Key Generator
Use this script to generate valid license keys for customers after receiving UPI payment.
"""

import sys
import hashlib
import random
import string
import argparse

SECRET_SALT = "HRM_SPIDER_PRO_SECRET_SALT_2026_ACODEZ"

def generate_license_key(seg1=None, seg2=None):
    if not seg1:
        seg1 = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
    if not seg2:
        seg2 = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
    
    seg1 = seg1.upper().replace("-", "").strip()[:4].ljust(4, 'X')
    seg2 = seg2.upper().replace("-", "").strip()[:4].ljust(4, 'Y')
    
    payload = f"SPID-{seg1}-{seg2}"
    to_hash = f"{payload}::{SECRET_SALT}".encode("utf-8")
    hash_hex = hashlib.sha256(to_hash).hexdigest().upper()
    checksum = hash_hex[:8]
    c1, c2 = checksum[:4], checksum[4:8]
    
    return f"{payload}-{c1}-{c2}"

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate Spider-Man V2 Theme License Keys")
    parser.add_argument("-n", "--count", type=int, default=1, help="Number of keys to generate")
    parser.add_argument("-c", "--custom", type=str, default=None, help="Custom customer tag (up to 4 chars)")
    
    args = parser.parse_args()
    
    print("=" * 55)
    print("   HRM WIDGET - SPIDER-MAN V2 LICENSE KEY GENERATOR")
    print("=" * 55)
    
    for i in range(args.count):
        key = generate_license_key(seg1=args.custom)
        print(f"[{i+1}] {key}")
    
    print("=" * 55)
