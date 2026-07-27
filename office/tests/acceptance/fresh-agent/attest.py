#!/usr/bin/env python3
"""Run one Office command and bind its completion-time result and file bytes."""

import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import tempfile


MAX_RESULT_BYTES = 8 * 1024 * 1024
MAX_BOUND_FILE_BYTES = 128 * 1024 * 1024
SAFE_RELATIVE = re.compile(r"^[a-z0-9][a-z0-9._/-]*$")
BOUND_SUFFIXES = (".xlsx", ".docx", ".html")
ATTESTATION_PREFIX = "OFFICE_F1B_ATTESTATION\t"


class AttestationError(Exception):
    pass


def safe_relative_path(value, label):
    if not SAFE_RELATIVE.fullmatch(value or ""):
        raise AttestationError("%s is not a portable lowercase relative path" % label)
    if value.endswith("/") or "//" in value:
        raise AttestationError("%s is not canonical" % label)
    parts = value.split("/")
    if any(part in ("", ".", "..") for part in parts):
        raise AttestationError("%s traverses a non-canonical path" % label)
    current = os.getcwd()
    for part in parts[:-1]:
        current = os.path.join(current, part)
        info = os.lstat(current)
        if not stat.S_ISDIR(info.st_mode) or stat.S_ISLNK(info.st_mode):
            raise AttestationError("%s parent is not a physical directory" % label)
    return value


def digest_regular_file(path, limit, label):
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(path, flags)
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
            raise AttestationError("%s is not a single-link regular file" % label)
        if before.st_uid != os.geteuid():
            raise AttestationError("%s is not owned by the probe user" % label)
        if before.st_size <= 0 or before.st_size > limit:
            raise AttestationError("%s size is outside the accepted domain" % label)
        digest = hashlib.sha256()
        total = 0
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            total += len(chunk)
            if total > limit:
                raise AttestationError("%s grew beyond the accepted limit" % label)
            digest.update(chunk)
        after = os.fstat(descriptor)
        identity_before = (
            before.st_dev,
            before.st_ino,
            before.st_mode,
            before.st_uid,
            before.st_nlink,
            before.st_size,
            before.st_mtime_ns,
        )
        identity_after = (
            after.st_dev,
            after.st_ino,
            after.st_mode,
            after.st_uid,
            after.st_nlink,
            after.st_size,
            after.st_mtime_ns,
        )
        if identity_before != identity_after or total != before.st_size:
            raise AttestationError("%s changed while it was hashed" % label)
        return {"bytes": total, "path": path, "sha256": digest.hexdigest()}
    finally:
        os.close(descriptor)


def validate_target(path):
    if not os.path.isabs(path):
        raise AttestationError("Office target must be absolute")
    info = os.lstat(path)
    if not stat.S_ISREG(info.st_mode) or stat.S_ISLNK(info.st_mode):
        raise AttestationError("Office target is not a physical regular file")
    if not os.access(path, os.X_OK):
        raise AttestationError("Office target is not executable")


def run_and_attest(target, result_path, arguments):
    validate_target(target)
    safe_relative_path(result_path, "result path")
    if not result_path.endswith(".json"):
        raise AttestationError("result path must end in .json")
    if os.path.lexists(result_path):
        raise AttestationError("result path already exists")
    if not arguments or arguments[-1] != "--json":
        raise AttestationError("Office product arguments must end in --json")

    result_parent = os.path.dirname(result_path) or "."
    descriptor, temporary = tempfile.mkstemp(
        prefix=".office-attest.", suffix=".json", dir=result_parent
    )
    published = False
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "wb", closefd=True) as stream:
            process = subprocess.Popen([target] + arguments, stdout=stream)
            status_code = process.wait()
            stream.flush()
            os.fsync(stream.fileno())
        if status_code != 0:
            return status_code
        result_info = os.lstat(temporary)
        if result_info.st_size <= 0 or result_info.st_size > MAX_RESULT_BYTES:
            raise AttestationError("Office JSON result size is outside the accepted domain")
        with open(temporary, "r", encoding="utf-8") as stream:
            json.load(stream)
            if stream.read(1):
                raise AttestationError("Office JSON result has trailing content")
        os.link(temporary, result_path, follow_symlinks=False)
        os.unlink(temporary)
        temporary = None
        published = True

        result = digest_regular_file(result_path, MAX_RESULT_BYTES, "Office JSON result")
        paths = sorted(
            {
                argument
                for argument in arguments
                if not argument.startswith("-")
                and argument.lower().endswith(BOUND_SUFFIXES)
            }
        )
        if not paths:
            raise AttestationError("Office command names no package or preview file")
        files = []
        for path in paths:
            safe_relative_path(path, "bound file path")
            files.append(
                digest_regular_file(path, MAX_BOUND_FILE_BYTES, "bound Office file")
            )
        value = {
            "files": files,
            "result": result,
            "schema": "office.fresh-agent.command-attestation/1",
        }
        payload = json.dumps(value, sort_keys=True, separators=(",", ":"))
        sys.stdout.write(ATTESTATION_PREFIX + payload + "\n")
        sys.stdout.flush()
        return 0
    except Exception:
        if published:
            try:
                os.unlink(result_path)
            except FileNotFoundError:
                pass
        raise
    finally:
        if temporary is not None:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass


def main():
    if len(sys.argv) < 5:
        print(
            "usage: attest.py OFFICE_TARGET RESULT_PATH VERB ... --json",
            file=sys.stderr,
        )
        return 64
    return run_and_attest(sys.argv[1], sys.argv[2], sys.argv[3:])


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (AttestationError, OSError, UnicodeError, ValueError) as exc:
        print("office attestation failed: %s" % exc, file=sys.stderr)
        sys.exit(70)
