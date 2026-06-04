#!/usr/bin/env python3
"""Run a PowerShell .ps1 script on the Windows VM via WinRM SSL transport.

Usage: python3 Scripts/invoke-winrm.py <path-to-ps1-on-vm>
Example: python3 Scripts/invoke-winrm.py 'C:\\Users\\douda\\Desktop\\Shared\\test-module.ps1'
"""
import sys, winrm

HOST = '172.17.0.1'
PORT = 5986
USER = 'douda'
PASS = 'aurelien'

script_path = sys.argv[1] if len(sys.argv) > 1 else r'C:\Users\douda\Desktop\Shared\test-module.ps1'
cmd = f'powershell -ExecutionPolicy Bypass -File "{script_path}"'

s = winrm.Session(f'{HOST}:{PORT}', auth=(USER, PASS), transport='ssl', server_cert_validation='ignore')
r = s.run_cmd(cmd)
print(r.std_out.decode())
if r.std_err:
    err = r.std_err.decode().strip()
    if err:
        print('STDERR:', err[:500], file=sys.stderr)
