#!/usr/bin/env python3
"""Grant operator.write scope to all paired agent devices.
Run once after 'task onboard' to allow the agent to send files/replies."""

import json
import os
import sys

path = "/opt/openclaw/config/devices/paired.json"

if not os.path.exists(path):
    print("paired.json not found — run 'task onboard' first")
    sys.exit(1)

with open(path, "r") as f:
    data = json.load(f)

changed = 0
for device_id, device in data.items():
    scopes = device.get("scopes", [])
    if "operator.write" not in scopes:
        device["scopes"] = sorted(set(scopes + ["operator.write"]))
        device["approvedScopes"] = sorted(set(device.get("approvedScopes", []) + ["operator.write"]))
        for token in device.get("tokens", {}).values():
            token_scopes = token.get("scopes", [])
            if "operator.write" not in token_scopes:
                token["scopes"] = sorted(set(token_scopes + ["operator.write"]))
        changed += 1
        print(f"  patched device: {device_id[:16]}... ({device.get('clientId', '?')})")

with open(path, "w") as f:
    json.dump(data, f, indent=2)

if changed:
    print(f"Done: {changed} device(s) updated with operator.write scope")
else:
    print("All devices already have operator.write — nothing to do")

