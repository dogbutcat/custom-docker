#!/usr/bin/env python3
# Exercise full runtime startup using temporary files and a fake Xray executable.
"""Stdlib startup regressions; set XRAY_RUNTIME_SCRIPT to test another copy."""

import base64
from dataclasses import dataclass
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(os.environ.get(
    "XRAY_RUNTIME_SCRIPT",
    str(Path(__file__).resolve().parents[1] / "runtime" / "start-xray.sh"),
)).resolve()
FIXTURE = Path(__file__).resolve().parent / "fixtures" / "fake_xray.py"
SHELL = os.environ.get("XRAY_TEST_SHELL", "/bin/sh")
SENTINEL = "f2707fb2-70fa-6b38-c9b2-81d6f1efa323"
CUSTOM_ID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
PRIVATE = base64.urlsafe_b64encode(bytes([7]) * 32).decode().rstrip("=")
DECRYPTION = "mlkem768x25519plus.native.600s." + base64.urlsafe_b64encode(bytes([3]) * 64).decode().rstrip("=")
ENCRYPTION = "mlkem768x25519plus.native.0rtt." + base64.urlsafe_b64encode(bytes([4]) * 1184).decode().rstrip("=")


@dataclass
class Startup:
    """Keep a subprocess result and the fake CLI trace for assertions."""

    status: int
    stdout: str
    stderr: str
    calls: list[dict[str, object]]
    pid: int

    @property
    def phases(self) -> list[str]:
        """Return invocation phases in observed order."""
        return [str(call["phase"]) for call in self.calls]


class RuntimeTests(unittest.TestCase):
    """Run each startup inside an isolated filesystem and CLI environment."""

    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="xray-startup-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.keys = self.root / "keys"
        self.override = self.root / "override.json"
        self.config = self.root / "config.json"
        self.trace = self.root / "trace.jsonl"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        executable = self.bin / "xray"
        source = FIXTURE.read_text().split("\n", 1)[1]
        executable.write_text(f"#!{sys.executable}\n{source}")
        executable.chmod(0o700)
        # Only standard filesystem paths are transformed; startup logic is unchanged.
        script = SCRIPT.read_text()
        for before, after in (
            ("/opt/xray/keys", str(self.keys)),
            ("/opt/xray/config/config.json", str(self.override)),
            ("/tmp/config.json", str(self.config)),
        ):
            script = script.replace(before, after)
        self.script = self.root / "start-xray.sh"
        self.script.write_text(script)
        self.env = {
            "PATH": str(self.bin) + os.pathsep + os.environ["PATH"],
            "HOME": os.environ.get("HOME", str(self.root)),
            "CONFIG": "{}",
            "INBOUNDS": "[]",
            "CLIENTS": json.dumps([{"id": CUSTOM_ID, "level": 0}]),
            "OUTBOUNDS": '[{"protocol":"freedom"}]',
            "ROUTING": '{"rules":[]}',
            "TRANSPORT": "{}",
            "DNS": "{}",
            "LOGLEVEL": '"warning"',
            "VLESS_PORT": "443",
            "VLESSENC_PORT": "8443",
            "VLESSENC_NETWORK": "tcp",
            "VLESSENC_KEY": "",
            "REALITY_PRIVATE_KEY": "",
            "REALITY_SHORT_ID": "",
            "REALITY_DEST": "example.com:443",
            "REALITY_SNI": "example.com",
            "SS": "",
            "FAKE_TRACE": str(self.trace),
        }

    def start(self, **values: str) -> Startup:
        """Run the entire shell entrypoint with the supplied environment values."""
        self.trace.write_text("")
        process = subprocess.Popen(
            [SHELL, str(self.script)],
            cwd=self.root,
            env=self.env | values,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        try:
            stdout, stderr = process.communicate(timeout=15)
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()
            self.fail("Startup did not finish within 15 seconds")
        calls = [json.loads(line) for line in self.trace.read_text().splitlines()]
        evidence = os.environ.get("XRAY_TEST_EVIDENCE")
        if evidence:
            record = {
                "test": self.id(), "input": self.env | values,
                "command": [SHELL, str(self.script)], "exit_status": process.returncode,
                "stdout": stdout, "stderr": stderr, "xray_calls": calls,
                "configuration": self.config.read_text() if self.config.is_file() else None,
            }
            with Path(evidence).open("a") as stream:
                stream.write(json.dumps(record) + "\n")
        return Startup(process.returncode, stdout, stderr, calls, process.pid)

    def configuration(self) -> dict[str, object]:
        """Load the emitted configuration object."""
        return json.loads(self.config.read_text())

    def inbounds(self) -> list[dict[str, object]]:
        """Load the emitted inbound objects."""
        return json.loads(self.config.read_text())["inbounds"]

    def persisted(self, name: str, value: str) -> Path:
        """Seed a synthetic persisted value without touching standard system paths."""
        self.keys.mkdir(exist_ok=True)
        path = self.keys / name
        path.write_text(value)
        return path

    def success(self, result: Startup) -> None:
        """Require successful server startup; validation ordering has dedicated tests."""
        self.assertEqual(result.status, 0, result.stderr)
        self.assertEqual(result.phases[-1:], ["server"], result.phases)

    def rejected(self, result: Startup, diagnostic: str = "") -> None:
        """Require useful failure and no server invocation."""
        self.assertNotEqual(result.status, 0, result.stdout)
        self.assertNotIn("server", result.phases)
        self.assertIn(diagnostic, result.stderr)

    def override_only(self, result: Startup) -> None:
        """Require the override to skip all quick-setup helpers and summaries."""
        self.success(result)
        self.assertEqual(result.phases, ["test", "server"])
        self.assertFalse(self.keys.exists())
        self.assertNotIn("Public Key:", result.stdout)
        self.assertNotIn("Client Encryption:", result.stdout)
        self.assertNotIn(CUSTOM_ID, result.stdout)

    def test_whitespace_clients_existing_flow_and_nested_fields(self) -> None:
        clients = [
            {"id": CUSTOM_ID, "flow": "", "email": 'client"one\\two', "metadata": {"id": SENTINEL, "secret": "PRIVATE_METADATA"}},
            {"id": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", "flow": "xtls-rprx-vision", "level": 2},
            {"id": "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "email": "third"},
        ]
        result = self.start(CLIENTS=json.dumps(clients, indent=2))
        self.success(result)
        reality, encryption = self.inbounds()
        expected = [dict(client) for client in clients]
        expected[2]["flow"] = "xtls-rprx-vision"
        self.assertEqual(reality["settings"]["clients"], expected)
        self.assertEqual(encryption["settings"]["clients"], expected)
        self.assertNotIn("PRIVATE_METADATA", result.stdout)

    def test_supported_transports_add_vision_only_for_tcp(self) -> None:
        for network, settings, field, value in (
            ("tcp", None, None, None),
            ("ws", "wsSettings", "path", "/"),
            ("ws:/a:b", "wsSettings", "path", "/a:b"),
            ("grpc", "grpcSettings", "serviceName", "vless"),
            ("grpc:svc:part", "grpcSettings", "serviceName", "svc:part"),
            ("xhttp", "xhttpSettings", "path", "/"),
            ("xhttp:/upload", "xhttpSettings", "path", "/upload"),
        ):
            with self.subTest(network=network):
                result = self.start(VLESSENC_NETWORK=network)
                self.success(result)
                stream = self.inbounds()[1]["streamSettings"]
                self.assertEqual(stream["network"], network.split(":")[0])
                if settings is not None:
                    self.assertEqual(stream[settings][field], value)
                client = self.inbounds()[1]["settings"]["clients"][0]
                if network == "tcp":
                    self.assertEqual(client["flow"], "xtls-rprx-vision")
                else:
                    self.assertNotIn("flow", client)

    def test_explicit_flow_preserved_across_encryption_transports(self) -> None:
        clients = [
            {"id": CUSTOM_ID, "flow": "", "email": "explicit-empty"},
            {"id": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", "flow": "xtls-rprx-vision", "level": 2},
            {"id": "cccccccc-cccc-4ccc-8ccc-cccccccccccc", "email": "default-flow"},
        ]
        reality_clients = [dict(client) for client in clients]
        reality_clients[2]["flow"] = "xtls-rprx-vision"
        for network in ("tcp", "ws:/socket", "grpc:service", "xhttp:/upload"):
            with self.subTest(network=network):
                result = self.start(VLESSENC_NETWORK=network, CLIENTS=json.dumps(clients, indent=2))
                self.success(result)
                reality, encryption = self.inbounds()
                self.assertEqual(reality["settings"]["clients"], reality_clients)
                expected = reality_clients if network == "tcp" else clients
                self.assertEqual(encryption["settings"]["clients"], expected)

    def test_unknown_transport_and_invalid_parameters_fail_before_helpers(self) -> None:
        for network in ("", "udp", "TCP", "quic:/path", "tcp:ignored", "ws:bad", "xhttp:bad"):
            with self.subTest(network=network):
                result = self.start(VLESSENC_NETWORK=network)
                self.rejected(result, "transport")
                self.assertEqual(result.phases, [])
        self.assertFalse(self.keys.exists())

    def test_file_override_wins_preserves_bytes_and_skips_unused_values(self) -> None:
        content = ' {\n "inbounds": [], "tag": "file wins" \n}\n\n'
        self.override.write_text(content)
        result = self.start(CONFIG='{"tag":"env"}', INBOUNDS="broken", CLIENTS="broken",
                            VLESSENC_NETWORK="bad", FAKE_FAIL_HELPER="vlessenc")
        self.override_only(result)
        self.assertEqual(self.config.read_text(), content)

    def test_full_config_preserves_bytes_and_skips_unused_values(self) -> None:
        content = ' { "inbounds": [], "tag": "env wins" }\n'
        result = self.start(CONFIG=content, INBOUNDS="broken", CLIENTS="broken",
                            OUTBOUNDS="broken", VLESSENC_NETWORK="bad", FAKE_FAIL_HELPER="x25519")
        self.override_only(result)
        self.assertEqual(self.config.read_text(), content)

    def test_custom_inbounds_preserve_ownership_and_other_components(self) -> None:
        custom = [{"port": 1234, "protocol": "vless", "settings": {
            "clients": [{"id": SENTINEL, "flow": "", "email": "owned"}],
            "decryption": "none"}, "streamSettings": {"network": "tcp"}}]
        result = self.start(INBOUNDS=json.dumps(custom), VLESSENC_KEY=DECRYPTION,
                            CLIENTS="broken", VLESSENC_NETWORK="bad", DNS='{"hosts":{"a":"b"}}')
        self.override_only(result)
        config = self.configuration()
        self.assertEqual(config["inbounds"], custom)
        self.assertEqual(config["outbounds"], [{"protocol": "freedom"}])
        self.assertEqual(config["routing"], {"rules": []})
        self.assertEqual(config["dns"], {"hosts": {"a": "b"}})

    def test_whitespace_empty_inbounds_and_config_select_quick_setup(self) -> None:
        result = self.start(INBOUNDS=" [ \n ] ", CONFIG=" { \n } ")
        self.success(result)
        self.assertIn("vlessenc", result.phases)
        self.assertEqual(len(self.inbounds()), 2)

    def test_json_types_empty_malformed_and_multiple_documents_fail(self) -> None:
        cases = {
            "CONFIG": ("[]", "null", "", "{", '{} {"second":1}'),
            "INBOUNDS": ("{}", "null", "", "[1]", "[] []"),
            "CLIENTS": ("{}", "[]", '[{"id":1}]', '[{"id":"a","flow":null}]', "[null]", "", "[] []"),
            "OUTBOUNDS": ("{}", "[null]", "[] []"),
            "ROUTING": ("[]", "null"),
            "DNS": ("[]", "null"),
            "TRANSPORT": ("[]", "null"),
            "LOGLEVEL": ("warning", '"verbose"', "null"),
            "SS": ("[]", "null"),
        }
        for name, inputs in cases.items():
            for value in inputs:
                with self.subTest(name=name, value=value):
                    self.rejected(self.start(**{name: value}), name)

    def test_invalid_file_and_unreadable_file_do_not_fall_through(self) -> None:
        for content in ("[]", "{", "", '{} {"second":1}'):
            with self.subTest(content=content):
                self.override.write_text(content)
                result = self.start(CONFIG='{"otherwise":"valid"}')
                self.rejected(result, "Configuration file")
                self.assertEqual(result.phases, [])
        self.override.unlink()
        self.override.mkdir()
        self.rejected(self.start(), "readable file")

    def test_ports_reject_non_integer_and_out_of_range_values(self) -> None:
        for name in ("VLESS_PORT", "VLESSENC_PORT"):
            for port in ("", "0", "65536", "-1", "443.5", "443x", "1e2", " "):
                with self.subTest(name=name, port=port):
                    result = self.start(**{name: port})
                    self.rejected(result, "port")
                    self.assertEqual(result.phases, [])

    def test_public_key_parser_current_legacy_and_malformed_outputs(self) -> None:
        for style in ("current", "legacy"):
            with self.subTest(style=style):
                result = self.start(FAKE_X25519=style)
                self.success(result)
                self.assertRegex(result.stdout, r"Public Key: [A-Za-z0-9_-]{43}")
        for style in ("empty", "invalid", "malformed", "duplicate", "mixed", "bad_extra"):
            with self.subTest(style=style):
                self.rejected(self.start(FAKE_X25519=style))

    def test_helper_failure_preserves_status_and_never_starts_server(self) -> None:
        for helper in ("vlessenc", "x25519", "uuid"):
            with self.subTest(helper=helper):
                client_id = SENTINEL if helper == "uuid" else CUSTOM_ID
                result = self.start(FAKE_FAIL_HELPER=helper, CLIENTS=json.dumps([{"id": client_id}]))
                self.rejected(result, helper)
                self.assertEqual(result.status, 17)

    def test_malformed_vlessenc_outputs_do_not_fallback(self) -> None:
        for style in ("empty", "malformed", "missing", "unpaired"):
            with self.subTest(style=style):
                result = self.start(FAKE_VLESSENC=style)
                self.rejected(result)
                self.assertNotIn("test", result.phases)

    def test_invalid_persisted_keys_are_preserved_without_regeneration(self) -> None:
        for name in ("vlessenc.key", "reality.key", "reality.shortid", "client.uuid"):
            for value in ("", "broken", "mlkem768broken"):
                with self.subTest(name=name, value=value):
                    path = self.persisted(name, value)
                    result = self.start(CLIENTS=json.dumps([{"id": SENTINEL}]))
                    self.rejected(result, "persisted" if value == "" else "")
                    self.assertEqual(path.read_text(), value)
                    if name == "vlessenc.key":
                        self.assertNotIn("vlessenc", result.phases)
                    path.unlink()

    def test_persisted_key_directory_permission_failure(self) -> None:
        if os.geteuid() == 0:
            self.skipTest("Root does not enforce owner write permission")
        self.keys.mkdir()
        self.keys.chmod(0o500)
        self.addCleanup(self.keys.chmod, 0o700)
        result = self.start()
        self.rejected(result, "temporary")
        self.assertFalse((self.keys / "vlessenc.key").exists())

    def test_atomic_persistence_failure_prevents_partial_target(self) -> None:
        real_mv = shutil.which("mv")
        self.assertIsNotNone(real_mv)
        wrapper = self.bin / "mv"
        wrapper.write_text(
            f"#!{sys.executable}\n"
            "# Refuse synthetic key commits while retaining real config moves.\n"
            "import os, sys\n"
            "if sys.argv[-1].endswith('/vlessenc.key'):\n"
            "    raise SystemExit(73)\n"
            f"os.execv({real_mv!r}, [{real_mv!r}, *sys.argv[1:]])\n"
        )
        wrapper.chmod(0o700)
        self.rejected(self.start(), "persist")
        self.assertFalse((self.keys / "vlessenc.key").exists())
        self.assertEqual(list(self.keys.glob(".vlessenc.key.*")), [])

    def test_generated_identity_and_keys_are_stable_and_restrictive(self) -> None:
        clients = [{"id": SENTINEL, "level": 3, "email": "stable"}, {"id": CUSTOM_ID, "note": SENTINEL}]
        first = self.start(CLIENTS=json.dumps(clients))
        self.success(first)
        config = self.inbounds()
        state = {path.name: path.read_bytes() for path in self.keys.iterdir()}
        second = self.start(CLIENTS=json.dumps(clients))
        self.success(second)
        self.assertEqual(self.inbounds(), config)
        self.assertEqual({path.name: path.read_bytes() for path in self.keys.iterdir()}, state)
        self.assertNotIn("vlessenc", second.phases)
        self.assertNotIn("uuid", second.phases)
        self.assertEqual(second.calls[0]["args"], ["x25519", "-i", PRIVATE])
        client = config[0]["settings"]["clients"][0]
        self.assertNotEqual(client["id"], SENTINEL)
        self.assertEqual(client["email"], "stable")
        self.assertEqual(config[0]["settings"]["clients"][1]["id"], CUSTOM_ID)
        self.assertEqual(config[0]["settings"]["clients"][1]["note"], SENTINEL)
        for path in self.keys.iterdir():
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)

    def test_explicit_private_key_still_persists_and_reuses_short_id(self) -> None:
        first = self.start(REALITY_PRIVATE_KEY=PRIVATE)
        self.success(first)
        short_id = (self.keys / "reality.shortid").read_text().strip()
        self.assertRegex(short_id, r"^[0-9a-f]{16}$")
        self.assertFalse((self.keys / "reality.key").exists())
        second = self.start(REALITY_PRIVATE_KEY=PRIVATE)
        self.success(second)
        self.assertEqual(self.inbounds()[0]["streamSettings"]["realitySettings"]["shortIds"], [short_id])

    def test_explicit_keys_win_without_stale_client_summary(self) -> None:
        existing = self.persisted("vlessenc.key", "invalid unused value")
        self.persisted("vlessenc.enc", "STALE SUMMARY")
        self.persisted("reality.key", "invalid unused private key")
        result = self.start(VLESSENC_KEY=DECRYPTION, REALITY_PRIVATE_KEY=PRIVATE, REALITY_SHORT_ID="aabb")
        self.success(result)
        self.assertNotIn("vlessenc", result.phases)
        self.assertNotIn("STALE SUMMARY", result.stdout)
        self.assertIn("user-provided key", result.stdout)
        self.assertEqual(existing.read_text(), "invalid unused value")
        self.assertEqual(self.inbounds()[1]["settings"]["decryption"], DECRYPTION)

    def test_json_escaping_for_transports_reality_and_ss(self) -> None:
        payload = '/quote"back\\slash\nline'
        ss = {"port": 8388, "protocol": "shadowsocks", "settings": {"password": 'pw"\\\n'}}
        result = self.start(VLESSENC_NETWORK="xhttp:" + payload, REALITY_SNI='name"\\\n',
                            REALITY_DEST='dest"\\\n:443', SS=json.dumps(ss))
        self.success(result)
        reality, encryption, shadowsocks = self.inbounds()
        self.assertEqual(encryption["streamSettings"]["xhttpSettings"]["path"], payload)
        self.assertEqual(reality["streamSettings"]["realitySettings"]["serverNames"], ['name"\\\n'])
        self.assertEqual(shadowsocks, ss)
        self.assertNotIn(ss["settings"]["password"], result.stdout)

    def test_config_test_failure_preserves_status_and_redacts_output(self) -> None:
        for mode in ("quick", "config", "file", "inbounds"):
            with self.subTest(mode=mode):
                values = {"FAKE_TEST_EXIT": "23"}
                if mode == "config":
                    values["CONFIG"] = '{"inbounds":[]}'
                if mode == "inbounds":
                    values["INBOUNDS"] = '[{"port":1234}]'
                if mode == "file":
                    self.override.write_text('{"inbounds":[]}')
                result = self.start(**values)
                self.rejected(result, "configuration test failed")
                self.assertEqual(result.status, 23)
                self.assertNotIn("private CONFIG secret", result.stderr)
                if self.override.exists():
                    self.override.unlink()

    def test_config_validation_precedes_every_server_start(self) -> None:
        for mode in ("quick", "config", "file", "inbounds"):
            with self.subTest(mode=mode):
                values: dict[str, str] = {}
                if mode == "config":
                    values["CONFIG"] = '{"inbounds":[]}'
                if mode == "inbounds":
                    values["INBOUNDS"] = '[{"port":1234}]'
                if mode == "file":
                    self.override.write_text('{"inbounds":[]}')
                result = self.start(**values)
                self.success(result)
                self.assertEqual(result.phases[-2:], ["test", "server"])
                if self.override.exists():
                    self.override.unlink()

    def test_final_exec_preserves_process_identity_and_exit_status(self) -> None:
        result = self.start(FAKE_SERVER_EXIT="19")
        self.assertEqual(result.status, 19)
        self.assertEqual(result.phases[-2:], ["test", "server"])
        self.assertEqual(result.calls[-1]["pid"], result.pid)

    def test_debug_output_is_explicit_and_normal_logs_hide_private_keys(self) -> None:
        result = self.start()
        self.success(result)
        self.assertNotIn(PRIVATE, result.stdout + result.stderr)
        self.assertNotIn(DECRYPTION, result.stdout + result.stderr)
        result = self.start(LOGLEVEL='"debug"')
        self.success(result)
        self.assertIn("Current Config:", result.stdout)
        self.assertIn(PRIVATE, result.stdout)

    def test_orphan_summary_and_invalid_client_encryption_fail_closed(self) -> None:
        summary = self.persisted("vlessenc.enc", "broken")
        self.rejected(self.start(), "without")
        self.persisted("vlessenc.key", DECRYPTION)
        self.rejected(self.start(), "encryption")
        self.assertEqual(summary.read_text(), "broken")

    def test_invalid_explicit_keys_short_id_and_uuid_helper_fail(self) -> None:
        for values in (
            {"VLESSENC_KEY": "mlkem768invalid"},
            {"REALITY_PRIVATE_KEY": "invalid"},
            {"REALITY_SHORT_ID": "xyz"},
            {"REALITY_SHORT_ID": "abc"},
            {"REALITY_SHORT_ID": "aa" * 9},
            {"FAKE_UUID": "invalid", "CLIENTS": json.dumps([{"id": SENTINEL}])},
            {"FAKE_UUID": SENTINEL, "CLIENTS": json.dumps([{"id": SENTINEL}])},
        ):
            with self.subTest(values=values):
                self.rejected(self.start(**values))


if __name__ == "__main__":
    unittest.main(verbosity=2)
