#!/usr/bin/env python3
"""Run a PowerShell .ps1 script on the Windows VM via WinRM NTLM transport.

Credentials are read from environment variables:
    WINRM_HOST   (default: localhost)
    WINRM_PORT   (default: 5985)
    WINRM_USER   (default: smokeuser)
    WINRM_PASS   (default: smokepassword)

Usage:
    python3 Scripts/invoke-winrm.py <vm-script-path>
    # Or override: WINRM_USER=... WINRM_PASS=... python3 Scripts/invoke-winrm.py <path>
"""

import os, sys, winrm

HOST = os.environ.get('WINRM_HOST', 'localhost')
PORT = int(os.environ.get('WINRM_PORT', '5985'))
USER = os.environ.get('WINRM_USER', 'smokeuser')
PASS = os.environ.get('WINRM_PASS', 'smokepassword')

if not USER or not PASS:
    print("Set WINRM_USER and WINRM_PASS environment variables.", file=sys.stderr)
    sys.exit(1)

script_path = sys.argv[1] if len(sys.argv) > 1 else None
if not script_path:
    print(f"Usage: WINRM_USER=... WINRM_PASS=... {sys.argv[0]} <path-to-ps1-on-vm>", file=sys.stderr)
    sys.exit(1)

cmd = f'powershell -ExecutionPolicy Bypass -File "{script_path}"'
s = winrm.Session(f'{HOST}:{PORT}', auth=(USER, PASS), transport='ntlm')
r = s.run_cmd(cmd)
print(r.std_out.decode('utf-8', errors='replace'))
if r.std_err:
    err = r.std_err.decode().strip()
    if err:
        print('STDERR:', err[:500], file=sys.stderr)
