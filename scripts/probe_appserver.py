#!/usr/bin/env python3
"""
Codex app-server probe.

Spawns `codex app-server --listen stdio://`, performs the JSON-RPC handshake,
and captures real responses for `account/read` and `account/rateLimits/read`,
plus any unsolicited notifications during a short listen window.

Output:
  Docs/captured/<timestamp>/{initialize,account_read,rate_limits_read,notifications}.json

Sensitive fields (email, loginId, authUrl, accessToken) are redacted in a
second `*.redacted.json` copy committed to the repo.
"""
from __future__ import annotations

import json
import os
import pathlib
import re
import select
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_DIR = REPO_ROOT / "Docs" / "captured" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
OUT_DIR.mkdir(parents=True, exist_ok=True)

REDACT_KEYS = {"email", "loginId", "authUrl", "verificationUrl", "userCode", "accessToken", "refreshToken", "apiKey", "chatgptAccountId"}


def redact(obj):
    if isinstance(obj, dict):
        return {k: ("<redacted>" if k in REDACT_KEYS and v is not None else redact(v)) for k, v in obj.items()}
    if isinstance(obj, list):
        return [redact(x) for x in obj]
    return obj


def write_pair(name: str, data):
    raw_path = OUT_DIR / f"{name}.json"
    red_path = OUT_DIR / f"{name}.redacted.json"
    raw_path.write_text(json.dumps(data, indent=2) + "\n")
    red_path.write_text(json.dumps(redact(data), indent=2) + "\n")
    # raw_path stays gitignored; redacted copy is the one to commit.
    print(f"  wrote {raw_path.name} (+ redacted)")


class AppServerClient:
    def __init__(self, codex_bin: str = "codex"):
        self.proc = subprocess.Popen(
            [codex_bin, "app-server", "--listen", "stdio://"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
        )
        self._next_id = 0
        self._pending: dict[int, dict] = {}
        self._notifications: list[dict] = []
        self._stderr_lines: list[str] = []
        self._reader = threading.Thread(target=self._read_loop, daemon=True)
        self._stderr_reader = threading.Thread(target=self._stderr_loop, daemon=True)
        self._reader.start()
        self._stderr_reader.start()

    def _read_loop(self):
        assert self.proc.stdout is not None
        while True:
            line = self.proc.stdout.readline()
            if not line:
                return
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                print(f"  [non-json stdout] {line!r}", file=sys.stderr)
                continue
            if "id" in msg and ("result" in msg or "error" in msg):
                self._pending[msg["id"]] = msg
            elif "method" in msg:
                self._notifications.append(msg)

    def _stderr_loop(self):
        assert self.proc.stderr is not None
        for line in self.proc.stderr:
            self._stderr_lines.append(line.decode(errors="replace"))

    def _send(self, msg: dict):
        assert self.proc.stdin is not None
        data = (json.dumps(msg) + "\n").encode()
        self.proc.stdin.write(data)
        self.proc.stdin.flush()

    def request(self, method: str, params=None, timeout: float = 10.0) -> dict:
        rid = self._next_id
        self._next_id += 1
        msg = {"jsonrpc": "2.0", "id": rid, "method": method}
        if params is not None:
            msg["params"] = params
        self._send(msg)
        deadline = time.time() + timeout
        while time.time() < deadline:
            if rid in self._pending:
                return self._pending.pop(rid)
            time.sleep(0.02)
        raise TimeoutError(f"no response to {method} within {timeout}s")

    def notify(self, method: str, params=None):
        msg = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            msg["params"] = params
        self._send(msg)

    def drain_notifications(self) -> list[dict]:
        out, self._notifications = self._notifications, []
        return out

    def close(self):
        try:
            self.proc.stdin.close()  # type: ignore[union-attr]
        except Exception:
            pass
        try:
            self.proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self.proc.terminate()


def main():
    print(f"out dir: {OUT_DIR.relative_to(REPO_ROOT)}")
    client = AppServerClient()
    try:
        print("> initialize")
        init = client.request("initialize", {
            "clientInfo": {"name": "codex-meter-probe", "title": "codex-meter probe", "version": "0.0.1"},
            "capabilities": {"experimentalApi": False, "requestAttestation": False},
        })
        write_pair("01_initialize", init)

        client.notify("initialized", {})

        # give server a beat to emit any post-init notifications
        time.sleep(0.3)

        print("> account/read")
        acct = client.request("account/read", {"refreshToken": False})
        write_pair("02_account_read", acct)

        print("> account/rateLimits/read")
        limits = client.request("account/rateLimits/read")
        write_pair("03_rate_limits_read", limits)

        # passive listen for a few seconds to catch any unsolicited pushes
        print("> passive listen 3s for notifications")
        time.sleep(3.0)
        write_pair("04_notifications", client.drain_notifications())

        if client._stderr_lines:
            (OUT_DIR / "stderr.log").write_text("".join(client._stderr_lines))
            print(f"  wrote stderr.log ({len(client._stderr_lines)} lines)")

        print("done.")
    finally:
        client.close()


if __name__ == "__main__":
    main()
