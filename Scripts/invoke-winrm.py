#!/usr/bin/env python3
"""Run a PowerShell .ps1 script on the Windows VM via WinRM SSL transport.

Credentials are read from environment variables:
    WINRM_HOST   (default: 172.17.0.1)
    WINRM_PORT   (default: 5986)
    WINRM_USER   (required)
    WINRM_PASS   (required)

Usage:
    WINRM_USER=<username> WINRM_PASS=<password> python3 Scripts/invoke-winrm.py <vm-script-path>
"""

import os, sys, winrm

HOST = os.environ.get('WINRM_HOST', 'localhost')
PORT = int(os.environ.get('WINRM_PORT', '5986'))
USER = os.environ.get('WINRM_USER', '')
PASS = os.environ.get('WINRM_PASS', '')

if not USER or not PASS:
    print("Set WINRM_USER and WINRM_PASS environment variables.", file=sys.stderr)
    sys.exit(1)

script_path = sys.argv[1] if len(sys.argv) > 1 else None
if not script_path:
    print(f"Usage: WINRM_USER=... WINRM_PASS=... {sys.argv[0]} <path-to-ps1-on-vm>", file=sys.stderr)
    sys.exit(1)

cmd = f'powershell -ExecutionPolicy Bypass -File "{script_path}"'
s = winrm.Session(f'{HOST}:{PORT}', auth=(USER, PASS), transport='ssl', server_cert_validation='ignore')
r = s.run_cmd(cmd)
print(r.std_out.decode())
if r.std_err:
    err = r.std_err.decode().strip()
    if err:
        print('STDERR:', err[:500], file=sys.stderr)
