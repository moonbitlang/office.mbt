#!/usr/bin/env python3
"""Adversarial tests for the held-FD Codex credential guard."""

from __future__ import annotations

import hashlib
import json
import os
import select
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, Tuple


SCHEMA = "office.fresh-agent.auth-guard/1"
SECRET = b'{"tokens":{"access_token":"fixture-secret"}}\n'


def fail(message: str) -> None:
    raise AssertionError(message)


def write_private(path: Path, data: bytes = SECRET, mode: int = 0o600) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
    try:
        os.fchmod(fd, mode)
        os.write(fd, data)
    finally:
        os.close(fd)


class Guard:
    def __init__(self, policy: str, root: Path, source: Path) -> None:
        self.request_path = root / "request.fifo"
        self.response_path = root / "response.fifo"
        os.mkfifo(self.request_path, 0o600)
        os.mkfifo(self.response_path, 0o600)
        self.request_fd = os.open(self.request_path, os.O_RDWR | os.O_NONBLOCK)
        self.response_fd = os.open(self.response_path, os.O_RDWR | os.O_NONBLOCK)
        self.process = subprocess.Popen(
            [sys.executable, "-I", policy, "serve", str(source), str(self.request_path), str(self.response_path)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            env={"LANG": "C", "LC_ALL": "C", "PATH": "/usr/bin:/bin"},
        )
        self.buffer = b""

    def read(self, timeout: float = 5.0) -> Dict[str, Any]:
        deadline = timeout
        while b"\n" not in self.buffer:
            ready, _, _ = select.select([self.response_fd], [], [], deadline)
            if not ready:
                fail("auth guard response timed out")
            chunk = os.read(self.response_fd, 4096)
            if not chunk:
                fail("auth guard response closed")
            self.buffer += chunk
        line, self.buffer = self.buffer.split(b"\n", 1)
        value = json.loads(line.decode("utf-8"))
        if not isinstance(value, dict):
            fail("auth guard response was not an object")
        return value

    def send(self, value: Dict[str, Any]) -> None:
        payload = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8") + b"\n"
        os.write(self.request_fd, payload)

    def finish(self, expected: int) -> str:
        stderr = self.process.communicate(timeout=5.0)[1].decode("utf-8", errors="replace")
        if self.process.returncode != expected:
            fail(f"auth guard exit: expected {expected}, found {self.process.returncode}: {stderr}")
        os.close(self.request_fd)
        os.close(self.response_fd)
        return stderr


def expect_initial_error(policy: str, root: Path, source: Path, code: str) -> None:
    guard = Guard(policy, root, source)
    response = guard.read()
    if response != {"code": code, "schema": SCHEMA, "status": "error"}:
        fail(f"expected {code}, found {response!r}")
    stderr = guard.finish(1)
    if SECRET.decode("utf-8").strip() in stderr:
        fail("auth guard leaked credential bytes")


def expect_stage_error(guard: Guard, destination: Path, code: str) -> None:
    guard.send({"destination": str(destination), "op": "stage"})
    response = guard.read()
    if response != {"code": code, "schema": SCHEMA, "status": "error"}:
        fail(f"expected {code}, found {response!r}")
    guard.finish(1)
    if destination.exists() or destination.is_symlink():
        fail(f"failed staging left a destination: {destination}")


def make_case(root: Path, name: str) -> Path:
    case = root / name
    case.mkdir(mode=0o700)
    return case


def test_happy_and_path_replacement(policy: str, root: Path) -> None:
    case = make_case(root, "happy")
    source = case / "auth.json"
    write_private(source)
    guard = Guard(policy, case, source)
    ready = guard.read()
    digest = hashlib.sha256(SECRET).hexdigest()
    if ready != {
        "schema": SCHEMA,
        "source": {"bytes": len(SECRET), "sha256": digest},
        "status": "ready",
    }:
        fail(f"unexpected ready response: {ready!r}")

    held_source = case / "held-source.json"
    source.rename(held_source)
    replacement = b'{"tokens":{"access_token":"replacement"}}\n'
    write_private(source, replacement)
    destination = case / "state" / "auth.json"
    destination.parent.mkdir(mode=0o700)
    guard.send({"destination": str(destination), "op": "stage"})
    staged = guard.read()
    if staged != {
        "destination": {"bytes": len(SECRET), "sha256": digest},
        "schema": SCHEMA,
        "status": "staged",
    }:
        fail(f"unexpected staged response: {staged!r}")
    guard.finish(0)
    if destination.read_bytes() != SECRET:
        fail("guard reopened the replaced source path")
    if destination.stat().st_mode & 0o777 != 0o600:
        fail("staged credential mode was not 0600")


def test_shutdown(policy: str, root: Path) -> None:
    case = make_case(root, "shutdown")
    source = case / "auth.json"
    write_private(source)
    guard = Guard(policy, case, source)
    if guard.read().get("status") != "ready":
        fail("shutdown guard was not ready")
    guard.send({"op": "shutdown"})
    if guard.read() != {"schema": SCHEMA, "status": "stopped"}:
        fail("shutdown response mismatch")
    guard.finish(0)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: auth_guard_test.py AUTH_GUARD", file=sys.stderr)
        return 2
    policy = str(Path(argv[1]).resolve(strict=True))
    with tempfile.TemporaryDirectory(prefix="office-auth-guard-") as temporary:
        root = Path(temporary).resolve(strict=True)
        root.chmod(0o700)
        test_happy_and_path_replacement(policy, root)
        test_shutdown(policy, root)

        case = make_case(root, "symlink")
        target = case / "target.json"
        write_private(target)
        source = case / "auth.json"
        source.symlink_to(target.name)
        expect_initial_error(policy, case, source, "PATH_SYMLINK")

        case = make_case(root, "fifo")
        source = case / "auth.json"
        os.mkfifo(source, 0o600)
        expect_initial_error(policy, case, source, "SOURCE_NOT_REGULAR")

        case = make_case(root, "hardlink")
        source = case / "auth.json"
        write_private(source)
        os.link(source, case / "alias.json")
        expect_initial_error(policy, case, source, "SOURCE_LINK_COUNT")

        case = make_case(root, "permissions")
        source = case / "auth.json"
        write_private(source, mode=0o644)
        expect_initial_error(policy, case, source, "SOURCE_PERMISSIONS")

        case = make_case(root, "duplicate-json")
        source = case / "auth.json"
        write_private(source, b'{"a":1,"a":2}\n')
        expect_initial_error(policy, case, source, "SOURCE_JSON_DUPLICATE_KEY")

        case = make_case(root, "source-mutation")
        source = case / "auth.json"
        write_private(source)
        guard = Guard(policy, case, source)
        if guard.read().get("status") != "ready":
            fail("source-mutation guard was not ready")
        changed = b'{"tokens":{"access_token":"changed-secret"}}\n'
        if len(changed) != len(SECRET):
            fail("source mutation fixture must preserve size")
        source.write_bytes(changed)
        source.chmod(0o600)
        state = case / "state"
        state.mkdir(mode=0o700)
        expect_stage_error(guard, state / "auth.json", "SOURCE_CONTENT_CHANGED")

        case = make_case(root, "destination-symlink-parent")
        source = case / "auth.json"
        write_private(source)
        guard = Guard(policy, case, source)
        if guard.read().get("status") != "ready":
            fail("destination-symlink guard was not ready")
        real_state = case / "real-state"
        real_state.mkdir(mode=0o700)
        alias_state = case / "state"
        alias_state.symlink_to(real_state.name, target_is_directory=True)
        expect_stage_error(guard, alias_state / "auth.json", "PATH_SYMLINK")

        case = make_case(root, "destination-exists")
        source = case / "auth.json"
        write_private(source)
        guard = Guard(policy, case, source)
        if guard.read().get("status") != "ready":
            fail("destination-exists guard was not ready")
        state = case / "state"
        state.mkdir(mode=0o700)
        destination = state / "auth.json"
        write_private(destination, b"decoy\n")
        guard.send({"destination": str(destination), "op": "stage"})
        response = guard.read()
        if response != {"code": "DESTINATION_EXISTS", "schema": SCHEMA, "status": "error"}:
            fail(f"expected DESTINATION_EXISTS, found {response!r}")
        guard.finish(1)
        if destination.read_bytes() != b"decoy\n":
            fail("guard changed a pre-existing destination")

    print("AUTH GUARD TEST PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
