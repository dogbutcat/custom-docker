#!/usr/bin/env python3
# Emulate Xray CLI responses and record startup boundaries without opening sockets.
"""Fake Xray for isolated runtime-generator subprocess regressions."""

import base64
import hashlib
import json
import os
from pathlib import Path
import sys


def encoded(size: int, value: int) -> str:
    """Return a deterministic, canonical raw URL-safe Base64 test value."""
    return base64.urlsafe_b64encode(bytes([value]) * size).decode().rstrip("=")


def main() -> int:
    """Record the invocation and emulate the selected Xray command."""
    args = sys.argv[1:]
    trace = Path(os.environ["FAKE_TRACE"])
    phase = args[0] if args else "server"
    if phase == "run" or phase.startswith("--config="):
        phase = "test" if "-test" in args else "server"
    with trace.open("a") as stream:
        stream.write(json.dumps({"phase": phase, "args": args, "pid": os.getpid()}) + "\n")
    if os.environ.get("FAKE_FAIL_HELPER") == phase:
        print("synthetic helper failure", file=sys.stderr)
        return 17
    if phase == "uuid":
        print(os.environ.get("FAKE_UUID", "12345678-1234-4234-9234-123456789abc"))
        return 0
    if phase == "x25519":
        mode = os.environ.get("FAKE_X25519", "current")
        if mode == "empty":
            return 0
        if mode == "invalid":
            print("Invalid length of X25519 private key.")
            return 0
        private = args[args.index("-i") + 1] if "-i" in args else encoded(32, 7)
        public = base64.urlsafe_b64encode(hashlib.sha256(private.encode()).digest()).decode().rstrip("=")
        if mode == "malformed":
            public = "not-a-key"
        label = "Password:" if mode == "legacy" else "Password (PublicKey):"
        print(f"PrivateKey: {private}\n{label} {public}\nHash32: {encoded(32, 9)}")
        if mode == "duplicate":
            print(f"{label} {public}")
        if mode == "mixed":
            print(f"Password: {public}")
        if mode == "bad_extra":
            print("PrivateKey: ")
        return 0
    if phase == "vlessenc":
        mode = os.environ.get("FAKE_VLESSENC", "current")
        if mode == "empty":
            return 0
        if mode == "malformed":
            print('"decryption": "mlkem768broken"')
            print('"encryption": "wrong"')
            return 0
        pairs = [
            ("X25519", encoded(32, 1), encoded(32, 2)),
            ("ML-KEM-768", encoded(64, 3), encoded(1184, 4)),
        ]
        print("Choose one Authentication to use, do not mix them.")
        for name, private, public in pairs:
            print(f"\nAuthentication: {name}")
            print(f'"decryption": "mlkem768x25519plus.native.600s.{private}"')
            if mode != "missing":
                print(f'"encryption": "mlkem768x25519plus.native.0rtt.{public}"')
        if mode == "unpaired":
            print('"encryption": "extra"')
        return 0
    if phase in ("test", "server"):
        config_arg = next((arg.split("=", 1)[1] for arg in args if arg.startswith("--config=")), None)
        if config_arg is None:
            config_arg = args[args.index("-config") + 1]
        try:
            config = json.loads(Path(config_arg).read_text())
            if not isinstance(config, dict):
                raise ValueError("expected configuration object")
        except (OSError, ValueError) as error:
            print(f"synthetic config rejection: {error}", file=sys.stderr)
            return 23
        if phase == "test":
            if os.environ.get("FAKE_TEST_EXIT"):
                print("synthetic config error containing a private CONFIG secret", file=sys.stderr)
                return int(os.environ["FAKE_TEST_EXIT"])
            print("Configuration OK.")
            return 0
        return int(os.environ.get("FAKE_SERVER_EXIT", "0"))
    print("unsupported synthetic command", file=sys.stderr)
    return 64


if __name__ == "__main__":
    raise SystemExit(main())
