#!/usr/bin/env python3
"""Run a PowerShell .ps1 script on the Windows VM via WinRM NTLM transport.

Connection settings are read from the environment. The defaults fit the local dev VM —
change them with env vars rather than by editing this file:

    WINRM_HOST   (default: localhost; use 172.20.0.2 from the devcontainer)
    WINRM_PORT   (default: 5985; 5986/SSL is broken with pywinrm)
    WINRM_USER   (default: douda)
    WINRM_PASS   (default: aurelien)

SEPM credentials are forwarded into the remote process, so a script running on the VM reads the
same SEPM_USER / SEPM_PASS as the caller. That is how rotated credentials reach the PS 5.1 smoke
suites. The SEPM address is deliberately *not* forwarded: inside the VM it is always localhost,
while the caller reaches it at the container's bridge address.

Usage:
    python3 Scripts/invoke-winrm.py <vm-script-path>
    # Or override: WINRM_USER=... WINRM_PASS=... python3 Scripts/invoke-winrm.py <path>
"""

import base64, os, sys, winrm

HOST = os.environ.get('WINRM_HOST', 'localhost')
PORT = int(os.environ.get('WINRM_PORT', '5985'))
USER = os.environ.get('WINRM_USER', 'douda')
PASS = os.environ.get('WINRM_PASS', 'aurelien')

# Forwarded verbatim into the remote process. Credentials only: the SEPM address differs
# between the two sides (localhost in the VM, the bridge address from the devcontainer), so
# forwarding it would point the in-VM scripts at an address they cannot reach.
FORWARDED_ENV = ('SEPM_USER', 'SEPM_PASS')

if not USER or not PASS:
    print("Set WINRM_USER and WINRM_PASS environment variables.", file=sys.stderr)
    sys.exit(1)

script_path = sys.argv[1] if len(sys.argv) > 1 else None
if not script_path:
    print(f"Usage: WINRM_USER=... WINRM_PASS=... {sys.argv[0]} <path-to-ps1-on-vm>", file=sys.stderr)
    sys.exit(1)


def ps_literal(value):
    """Quote a value as a PowerShell single-quoted string."""
    return "'" + value.replace("'", "''") + "'"


def build_command(path):
    # -EncodedCommand (UTF-16LE, base64) instead of -Command: cmd.exe expands %VAR% even
    # inside quotes, so a password containing % would otherwise be mangled. The price is
    # that the remote host serializes its error stream as CLIXML on stderr.
    lines = ["$ProgressPreference = 'SilentlyContinue'"]
    lines += [f"$env:{name} = {ps_literal(os.environ[name])}"
              for name in FORWARDED_ENV if os.environ.get(name)]
    lines.append(f"& {ps_literal(path)}")
    encoded = base64.b64encode("\n".join(lines).encode('utf-16-le')).decode('ascii')
    return f'powershell -ExecutionPolicy Bypass -EncodedCommand {encoded}'


try:
    session = winrm.Session(f'{HOST}:{PORT}', auth=(USER, PASS), transport='ntlm')
    result = session.run_cmd(build_command(script_path))
except Exception as exc:
    print(f"WinRM to {HOST}:{PORT} as '{USER}' failed: {exc}", file=sys.stderr)
    print("Set WINRM_HOST / WINRM_PORT / WINRM_USER / WINRM_PASS for this VM.", file=sys.stderr)
    sys.exit(1)

print(result.std_out.decode('utf-8', errors='replace'))
if result.std_err:
    err = result.std_err.decode('utf-8', errors='replace').strip()
    if err:
        print('STDERR:', err[:500], file=sys.stderr)

# Propagate the remote exit code so a failing script is visible to the caller.
sys.exit(result.status_code)
