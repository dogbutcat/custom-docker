#!/usr/bin/env python3
# Verify image installers offline with synthetic assets and isolated system paths.
"""Stdlib regressions; XRAY_INSTALLER_ROOT selects the source copy under test."""

import fnmatch
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile


ROOT = Path(os.environ.get(
    "XRAY_INSTALLER_ROOT", str(Path(__file__).resolve().parents[2]),
)).resolve()
CORE = b"Synthetic core fixture; never execute this file.\n"
SCANNER = struct.pack("<16sHHIQQQIHHHHHH", b"\x7fELF\x02\x01\x01" + bytes(9),
                      2, 62, 1, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0)
DOWNLOAD_FLAGS = {"--fail", "--retry", "--retry-max-time", "--connect-timeout", "--max-time"}

# Fake only transport/architecture/checksum commands; filesystem tools stay native.
FAKE_COMMAND = r'''
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
with Path(os.environ["FAKE_TRACE"]).open("a") as stream:
    stream.write(json.dumps({"command": name, "args": args}) + "\n")
if os.environ.get("FAIL_COMMAND") == name:
    sys.exit(71)
if name == "uname":
    print(os.environ.get("FAKE_ARCH", "x86_64"))
elif name == "sha256sum":
    for filename in args:
        print(hashlib.sha256(Path(filename).read_bytes()).hexdigest(), " ", filename, sep="")
elif name == "apk":
    sys.exit(0)
elif name == "curl":
    url = args[-1]
    target = Path(args[args.index("-o") + 1])
    mode = os.environ.get("FAKE_MODE", "valid")
    suffix = os.environ.get("FAKE_HTTP_SUFFIX", "")
    http_error = mode == "http" or (suffix and url.endswith(suffix))
    if mode == "missing_digest" and url.endswith(".dgst"):
        http_error = True
    if http_error:
        target.write_bytes(b"Not Found")
        sys.exit(22 if "--fail" in args or "-f" in args else 0)
    if mode == "network":
        target.write_bytes(b"partial transfer")
        sys.exit(7)
    fixture = Path(os.environ["FAKE_FIXTURES"])
    if url.endswith(".dgst"):
        digest = hashlib.sha256((fixture / "core.zip").read_bytes()).hexdigest()
        text = "SHA2-256= " + digest + "\n"
        if mode == "mismatch":
            text = "SHA2-256= " + "0" * 64 + "\n"
        elif mode == "bad_digest":
            text = "SHA2-256= " + "z" * 64 + "\n"
        elif mode == "short_digest":
            text = "SHA2-256= " + digest[:63] + "\n"
        elif mode == "unparseable":
            text = "SHA512= " + "a" * 128 + "\n"
        elif mode == "duplicate_digest":
            text += text
        elif mode == "sha256_compat":
            text = "SHA256= " + digest.upper() + "\r\n"
        elif mode == "named_digest":
            text = "SHA2-256(Xray-linux-64.zip)= " + digest + "\n"
        elif mode == "empty_digest":
            text = ""
        elif mode == "not_found_digest":
            text = "Not Found"
        target.write_text(text)
    elif url.endswith(".zip"):
        shutil.copyfile(fixture / "core.zip", target)
    elif "RealiTLScanner" in url:
        target.write_bytes(b"<html>unexpected response</html>" if mode == "html"
                           else (fixture / "scanner").read_bytes())
    else:
        filename = url.rsplit("/", 1)[-1]
        asset = filename.removesuffix(".sha256sum")
        data = (fixture / asset).read_bytes()
        if filename.endswith(".sha256sum"):
            digest = hashlib.sha256(data).hexdigest()
            if mode == "mismatch":
                digest = "0" * 64
            target.write_text(digest + "  " + asset + "\n")
        else:
            target.write_bytes(data)
else:
    executable = shutil.which(name, path=os.defpath)
    if executable is None:
        sys.exit("Missing native filesystem utility: " + name)
    os.execv(executable, [name, *args])
'''


class InstallerTests(unittest.TestCase):
    """Execute actual installer copies without network or real /usr/bin writes."""

    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory(prefix="xray-installer-", dir="/tmp")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.install = self.root / "usr/bin/xray"
        self.install.mkdir(parents=True)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.fixtures = self.root / "fixtures"
        self.fixtures.mkdir()
        with zipfile.ZipFile(self.fixtures / "core.zip", "w") as archive:
            archive.writestr("xray", CORE)
        for name, data in (("scanner", SCANNER), ("geoip.dat", b"geoip fixture"),
                           ("geosite.dat", b"geosite fixture")):
            (self.fixtures / name).write_bytes(data)
        for name in ("curl", "uname", "sha256sum", "apk", "mkdir", "chmod", "install", "mv", "unzip"):
            executable = self.bin / name
            executable.write_text(f"#!{sys.executable}\n" + FAKE_COMMAND)
            executable.chmod(0o700)
        self.trace = self.root / "trace.jsonl"
        self.trace.write_text("")
        self.env = {
            "PATH": str(self.bin) + os.pathsep + os.defpath,
            "XRAY_BINARY": "v26.9.30", "FAKE_ARCH": "x86_64",
            "FAKE_TRACE": str(self.trace), "FAKE_FIXTURES": str(self.fixtures),
        }

    def run_script(self, name: str, **values: str) -> subprocess.CompletedProcess[str]:
        """Rewrite fixed filesystem roots only, keeping installer logic intact."""
        source = (ROOT / "script/install" / name).read_text()
        source = source.replace("/usr/bin/xray", str(self.install))
        script = self.root / name
        script.write_text(source)
        return self.execute(["/bin/bash", str(script)], values)

    def execute(self, command: list[str], values: dict[str, str]) -> subprocess.CompletedProcess[str]:
        """Record the command, input, output and status for optional audit evidence."""
        self.trace.write_text("")
        result = subprocess.run(command, cwd=self.root, env=self.env | values,
                                text=True, capture_output=True, timeout=15)
        evidence = os.environ.get("XRAY_INSTALLER_EVIDENCE")
        if evidence:
            with Path(evidence).open("a") as stream:
                stream.write(json.dumps({"test": self.id(), "source_root": str(ROOT),
                                         "command": command, "input": self.env | values,
                                         "exit_status": result.returncode,
                                         "stdout": result.stdout, "stderr": result.stderr,
                                         "calls": self.calls()}) + "\n")
        return result

    def calls(self, name: str = "") -> list[dict[str, object]]:
        """Read the fake command trace, optionally filtering by utility name."""
        rows = [json.loads(line) for line in self.trace.read_text().splitlines()]
        return [row for row in rows if not name or row["command"] == name]

    def assert_download_flags(self) -> None:
        """Require HTTP rejection and positive, bounded retry/time limits."""
        for call in self.calls("curl"):
            arguments = call["args"]
            self.assertTrue(DOWNLOAD_FLAGS.issubset(arguments), arguments)
            for option in DOWNLOAD_FLAGS - {"--fail"}:
                self.assertGreater(int(arguments[arguments.index(option) + 1]), 0)

    def test_core_valid_digests_and_architecture_assets(self) -> None:
        for arch, asset in (("x86_64", "64"), ("amd64", "64"), ("aarch64", "arm64-v8a"),
                            ("arm64", "arm64-v8a"), ("armv7l", "arm32-v7a")):
            with self.subTest(arch=arch):
                result = self.run_script("install-xray.sh", FAKE_ARCH=arch)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((self.install / "xray").read_bytes(), CORE)
                self.assertIn(f"Xray-linux-{asset}.zip", str(self.calls("curl")))
                self.assert_download_flags()
        for mode in ("sha256_compat", "named_digest"):
            with self.subTest(mode=mode):
                result = self.run_script("install-xray.sh", FAKE_MODE=mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((self.install / "xray").read_bytes(), CORE)

    def test_core_invalid_digest_cannot_install(self) -> None:
        for mode in ("missing_digest", "bad_digest", "short_digest", "unparseable", "mismatch",
                     "duplicate_digest", "empty_digest", "not_found_digest"):
            with self.subTest(mode=mode):
                result = self.run_script("install-xray.sh", FAKE_MODE=mode)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertFalse((self.install / "xray").exists())
                self.assertFalse(self.calls("unzip"))

    def test_core_http_error_rejected_before_extraction(self) -> None:
        result = self.run_script("install-xray.sh", FAKE_MODE="http")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertFalse((self.install / "xray").exists())
        self.assertFalse(self.calls("unzip"))
        self.assert_download_flags()

    def test_core_unsupported_architecture_fails_before_download(self) -> None:
        for arch in ("riscv64", "i686", "", "ARM64"):
            with self.subTest(arch=arch):
                result = self.run_script("install-xray.sh", FAKE_ARCH=arch)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertFalse(self.calls("curl"))

    def test_core_extract_failure_preserves_existing_install_directory(self) -> None:
        sentinel = self.install / "keep.dat"
        sentinel.write_bytes(b"existing unrelated file")
        core = self.install / "xray"
        core.write_bytes(b"previous core")
        (self.fixtures / "core.zip").write_bytes(b"not a zip archive")
        result = self.run_script("install-xray.sh")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(sentinel.read_bytes(), b"existing unrelated file")
        self.assertEqual(core.read_bytes(), b"previous core")

    def test_core_missing_extracted_binary_or_install_error_is_fatal(self) -> None:
        with zipfile.ZipFile(self.fixtures / "core.zip", "w") as archive:
            archive.writestr("readme.txt", "No core binary")
        result = self.run_script("install-xray.sh")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        with zipfile.ZipFile(self.fixtures / "core.zip", "w") as archive:
            archive.writestr("xray", CORE)
        result = self.run_script("install-xray.sh", FAIL_COMMAND="install")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertFalse((self.install / "xray").exists())

    def test_scanner_unsupported_architecture_skips_without_request(self) -> None:
        for arch in ("aarch64", "arm64", "armv7l", "riscv64", "i686"):
            with self.subTest(arch=arch):
                result = self.run_script("install-scanner.sh", FAKE_ARCH=arch)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(self.calls("curl"))
                self.assertTrue((self.install / "optional").is_dir())
                self.assertFalse(list(self.install.rglob("RealiTLScanner")))

    def test_scanner_valid_elf_is_staged_executable(self) -> None:
        result = self.run_script("install-scanner.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        binary = self.install / "optional/RealiTLScanner"
        self.assertEqual(binary.read_bytes(), SCANNER)
        self.assertTrue(os.access(binary, os.X_OK))
        self.assertIn("RealiTLScanner-linux-64", str(self.calls("curl")))
        self.assert_download_flags()

    def test_scanner_bad_supported_response_leaves_no_executable(self) -> None:
        for mode in ("http", "network", "html"):
            with self.subTest(mode=mode):
                result = self.run_script("install-scanner.sh", FAKE_MODE=mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(list(self.install.rglob("RealiTLScanner")))
        for bad in (b"", b"\x7fELF", bytes(64), SCANNER[:18] + b"\xb7\x00" + SCANNER[20:]):
            with self.subTest(header=bad[:8]):
                (self.fixtures / "scanner").write_bytes(bad)
                result = self.run_script("install-scanner.sh")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(list(self.install.rglob("RealiTLScanner")))

    def test_scanner_failure_or_skip_removes_stale_staging_executable(self) -> None:
        for values in ({"FAKE_MODE": "http"}, {"FAKE_MODE": "html"}, {"FAKE_ARCH": "arm64"}):
            with self.subTest(values=values):
                stale = self.install / "optional/RealiTLScanner"
                stale.parent.mkdir(exist_ok=True)
                stale.write_bytes(b"previous invalid executable")
                stale.chmod(0o700)
                result = self.run_script("install-scanner.sh", **values)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(list(self.install.rglob("RealiTLScanner")))

    def test_scanner_chmod_or_rename_failure_leaves_no_executable(self) -> None:
        for command in ("chmod", "mv"):
            with self.subTest(command=command):
                result = self.run_script("install-scanner.sh", FAIL_COMMAND=command)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(list(self.install.rglob("RealiTLScanner")))

    def test_geoip_verified_data_installs(self) -> None:
        result = self.run_script("install-geoip.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in ("geoip.dat", "geosite.dat"):
            self.assertEqual((self.install / name).read_bytes(), (self.fixtures / name).read_bytes())
        self.assert_download_flags()

    def test_geoip_http_or_digest_errors_are_fatal(self) -> None:
        for suffix in ("/geoip.dat", "/geoip.dat.sha256sum", "/geosite.dat", "/geosite.dat.sha256sum"):
            with self.subTest(suffix=suffix):
                result = self.run_script("install-geoip.sh", FAKE_HTTP_SUFFIX=suffix)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertFalse((self.install / "geoip.dat").exists())
                self.assert_download_flags()
        result = self.run_script("install-geoip.sh", FAKE_MODE="mismatch")
        self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_geoip_install_failure_is_fatal_and_preserves_downloads(self) -> None:
        result = self.run_script("install-geoip.sh", FAIL_COMMAND="install")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertFalse((self.install / "geoip.dat").exists())
        self.assertTrue((self.install / "geoip.dat.new").exists())

    def test_mandatory_final_build_steps_are_not_masked(self) -> None:
        dockerfile = (ROOT / "Dockerfile").read_text()
        block = re.search(r"^RUN set -ex[^\n]*(?:\n[^\n]+)*", dockerfile, re.MULTILINE)
        self.assertIsNotNone(block)
        shell = block.group()[4:].replace("\\\n", "\n")
        shell = shell.replace("/usr/bin/xray", str(self.install)).replace("/var/log/xray/", str(self.root / "log") + "/")
        (self.install / "xray").write_bytes(CORE)
        for command in ("apk", "mkdir", "chmod"):
            with self.subTest(command=command):
                result = self.execute(["/bin/bash", "-c", shell], {"FAIL_COMMAND": command})
                self.assertNotEqual(result.returncode, 0, result.stdout)
                if (self.root / "log").exists():
                    (self.root / "log").rmdir()
        result = self.execute(["/bin/bash", "-c", shell], {})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(os.access(self.install / "xray", os.X_OK))

    def test_image_versions_routing_and_optional_copy_layout(self) -> None:
        dockerfile = (ROOT / "Dockerfile").read_text()
        for name, expected in (("VERSION", "7.2.0"), ("XRAY_BINARY", "v26.9.30")):
            values = re.findall(rf"^ENV {name}=(\S+)$", dockerfile, re.MULTILINE)
            self.assertTrue(values)
            self.assertEqual(set(values), {expected})
            final_stage = dockerfile.split("FROM alpine:latest", 1)[1]
            self.assertIn(f"ENV {name}={expected}", final_stage)
        routing = json.loads(re.search(r"^ENV ROUTING='(.*)'$", dockerfile, re.MULTILINE).group(1))
        self.assertEqual(set(routing), {"rules"})
        self.assertEqual(routing["rules"][0], {"inboundTag": ["api"], "outboundTag": "api", "type": "field"})
        self.assertEqual(routing["rules"][1], {"type": "field", "outboundTag": "blocked", "ip": [
            "0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8", "169.254.0.0/16",
            "172.16.0.0/12", "192.0.0.0/24", "192.0.2.0/24", "192.168.0.0/16", "198.18.0.0/15",
            "198.51.100.0/24", "203.0.113.0/24", "::1/128", "fc00::/7", "fe80::/10",
        ]})
        outbounds = json.loads(re.search(r"^ENV OUTBOUNDS='(.*)'$", dockerfile, re.MULTILINE).group(1))
        self.assertEqual(outbounds[0], {"protocol": "freedom", "settings": {}, "tag": "direct"})
        self.assertIn("COPY --from=builder /usr/bin/xray/optional/ /usr/bin/xray/", dockerfile)
        self.assertNotIn("touch /usr/bin/xray/RealiTLScanner", dockerfile)

    def test_dockerignore_allows_build_inputs_and_excludes_sensitive_context(self) -> None:
        lines = (ROOT / ".dockerignore").read_text().splitlines()
        rules = [line for line in lines if line and not line.startswith("#")]
        files = {"Dockerfile", "script/install/install-xray.sh", "script/install/install-geoip.sh",
                 "script/install/install-scanner.sh", "script/runtime/entrypoint.sh",
                 "script/runtime/start-xray.sh", "script/runtime/scan-sni.sh"}
        directories = {"script", "script/install", "script/runtime"}
        self.assertEqual(rules[0], "**")
        self.assertEqual({rule for rule in rules if rule.startswith("!")},
                         {"!" + name for name in files} | {"!" + name + "/" for name in directories})
        # Moby's MatchesOrParentMatches applies each rule to paths AND their parents.
        # This evaluator covers this file's exact paths and trailing ** patterns only.
        def allowed(path: str) -> bool:
            result = True
            paths = [path, *(str(parent) for parent in Path(path).parents if str(parent) != ".")]
            for rule in rules:
                negative = rule.startswith("!")
                pattern = rule.lstrip("!").rstrip("/")
                if any(fnmatch.fnmatchcase(current, pattern) for current in paths):
                    result = negative
            return result
        for path in files:
            self.assertTrue(allowed(path), path)
            self.assertTrue((ROOT / path).is_file(), path)
            for parent in Path(path).parents:
                if str(parent) != ".":
                    self.assertTrue(allowed(str(parent)), str(parent))
        for path in (".git/config", "example/config.json", "local-compose-v2.yml", "docker-compose.yml",
                     ".env", "keys/reality.key", "script/install/config.json", "script/runtime/secret.sh",
                     "script/tests/test_installers.py", "audit/T2-1/VERIFICATION.txt", "README.md"):
            self.assertFalse(allowed(path), path)


if __name__ == "__main__":
    unittest.main()
