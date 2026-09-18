#!/usr/bin/env python3
"""Hold and stage a Codex credential without reopening attacker-controlled paths."""

from __future__ import annotations

import errno
import hashlib
import json
import os
import stat
import sys
from typing import Any, BinaryIO, Dict, List, Tuple


SCHEMA = "office.fresh-agent.auth-guard/1"
MAX_AUTH_BYTES = 1024 * 1024
MAX_COMMAND_BYTES = 4096


class GuardError(Exception):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def fail(code: str) -> None:
    raise GuardError(code)


def split_absolute_path(path: str) -> Tuple[List[str], str]:
    if not isinstance(path, str) or not path.startswith("/"):
        fail("PATH_NOT_ABSOLUTE")
    if "\x00" in path or os.path.normpath(path) != path or path == "/":
        fail("PATH_NOT_CANONICAL")
    components = path.split("/")[1:]
    if not components or any(part in ("", ".", "..") for part in components):
        fail("PATH_NOT_CANONICAL")
    return components[:-1], components[-1]


def directory_flags() -> int:
    return (
        os.O_RDONLY
        | os.O_DIRECTORY
        | getattr(os, "O_CLOEXEC", 0)
        | getattr(os, "O_NOFOLLOW", 0)
    )


def open_parent(path: str) -> Tuple[int, str]:
    parents, leaf = split_absolute_path(path)
    current = os.open("/", directory_flags())
    try:
        for component in parents:
            try:
                next_fd = os.open(component, directory_flags(), dir_fd=current)
            except OSError as error:
                if error.errno in (errno.ELOOP, errno.ENOTDIR):
                    fail("PATH_SYMLINK")
                fail("PATH_PARENT_OPEN")
            os.close(current)
            current = next_fd
        return current, leaf
    except BaseException:
        os.close(current)
        raise


def open_leaf(path: str, flags: int, mode: int = 0) -> int:
    parent_fd, leaf = open_parent(path)
    try:
        try:
            return os.open(
                leaf,
                flags | getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0),
                mode,
                dir_fd=parent_fd,
            )
        except OSError as error:
            if error.errno == errno.ELOOP:
                fail("PATH_SYMLINK")
            raise
    finally:
        os.close(parent_fd)


def read_bounded_fd(fd: int, expected_size: int) -> bytes:
    os.lseek(fd, 0, os.SEEK_SET)
    chunks: List[bytes] = []
    remaining = MAX_AUTH_BYTES + 1
    while remaining > 0:
        chunk = os.read(fd, min(65536, remaining))
        if not chunk:
            break
        chunks.append(chunk)
        remaining -= len(chunk)
    data = b"".join(chunks)
    if len(data) != expected_size or not 0 < len(data) <= MAX_AUTH_BYTES:
        fail("SOURCE_SIZE_CHANGED")
    return data


def reject_duplicate_keys(pairs: List[Tuple[str, Any]]) -> Dict[str, Any]:
    result: Dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail("SOURCE_JSON_DUPLICATE_KEY")
        result[key] = value
    return result


def validate_auth_json(data: bytes) -> None:
    try:
        decoded = data.decode("utf-8")
        value = json.loads(decoded, object_pairs_hook=reject_duplicate_keys)
    except UnicodeDecodeError:
        fail("SOURCE_NOT_UTF8")
    except json.JSONDecodeError:
        fail("SOURCE_NOT_JSON")
    if not isinstance(value, dict):
        fail("SOURCE_JSON_NOT_OBJECT")


def open_source(path: str) -> Tuple[int, bytes, os.stat_result, str]:
    flags = os.O_RDONLY | getattr(os, "O_NONBLOCK", 0)
    try:
        fd = open_leaf(path, flags)
    except GuardError:
        raise
    except OSError:
        fail("SOURCE_OPEN")
    try:
        metadata = os.fstat(fd)
        if not stat.S_ISREG(metadata.st_mode):
            fail("SOURCE_NOT_REGULAR")
        if metadata.st_uid != os.getuid():
            fail("SOURCE_WRONG_OWNER")
        if metadata.st_nlink != 1:
            fail("SOURCE_LINK_COUNT")
        if metadata.st_mode & 0o077:
            fail("SOURCE_PERMISSIONS")
        if not metadata.st_mode & stat.S_IRUSR:
            fail("SOURCE_NOT_READABLE")
        if not 0 < metadata.st_size <= MAX_AUTH_BYTES:
            fail("SOURCE_SIZE")
        data = read_bounded_fd(fd, metadata.st_size)
        validate_auth_json(data)
        observed = os.fstat(fd)
        identity = (
            metadata.st_dev,
            metadata.st_ino,
            metadata.st_mode,
            metadata.st_nlink,
            metadata.st_size,
        )
        observed_identity = (
            observed.st_dev,
            observed.st_ino,
            observed.st_mode,
            observed.st_nlink,
            observed.st_size,
        )
        if observed_identity != identity:
            fail("SOURCE_METADATA_CHANGED")
        return fd, data, metadata, hashlib.sha256(data).hexdigest()
    except BaseException:
        os.close(fd)
        raise


def open_fifo(path: str, flags: int) -> int:
    try:
        fd = open_leaf(path, flags)
    except GuardError:
        raise
    except OSError:
        fail("PROTOCOL_FIFO_OPEN")
    metadata = os.fstat(fd)
    if not stat.S_ISFIFO(metadata.st_mode):
        os.close(fd)
        fail("PROTOCOL_NOT_FIFO")
    if metadata.st_uid != os.getuid() or metadata.st_mode & 0o077:
        os.close(fd)
        fail("PROTOCOL_FIFO_PERMISSIONS")
    return fd


def emit(stream: BinaryIO, value: Dict[str, Any]) -> None:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    stream.write(payload + b"\n")
    stream.flush()


def read_command(stream: BinaryIO) -> Dict[str, Any]:
    line = stream.readline(MAX_COMMAND_BYTES + 1)
    if not line:
        fail("PROTOCOL_EOF")
    if len(line) > MAX_COMMAND_BYTES or not line.endswith(b"\n"):
        fail("PROTOCOL_COMMAND_SIZE")
    try:
        value = json.loads(line.decode("utf-8"), object_pairs_hook=reject_duplicate_keys)
    except (UnicodeDecodeError, json.JSONDecodeError):
        fail("PROTOCOL_COMMAND_JSON")
    if not isinstance(value, dict):
        fail("PROTOCOL_COMMAND_SHAPE")
    return value


def verify_source_snapshot(fd: int, expected: bytes, metadata: os.stat_result) -> None:
    observed = os.fstat(fd)
    if (
        observed.st_dev,
        observed.st_ino,
        observed.st_mode,
        observed.st_nlink,
        observed.st_size,
    ) != (
        metadata.st_dev,
        metadata.st_ino,
        metadata.st_mode,
        metadata.st_nlink,
        metadata.st_size,
    ):
        fail("SOURCE_METADATA_CHANGED")
    if read_bounded_fd(fd, metadata.st_size) != expected:
        fail("SOURCE_CONTENT_CHANGED")


def stage_snapshot(destination: str, data: bytes) -> None:
    parent_fd, leaf = open_parent(destination)
    created = False
    output_fd = -1
    try:
        parent = os.fstat(parent_fd)
        if not stat.S_ISDIR(parent.st_mode):
            fail("DESTINATION_PARENT_NOT_DIRECTORY")
        if parent.st_uid != os.getuid() or parent.st_mode & 0o077:
            fail("DESTINATION_PARENT_PERMISSIONS")
        try:
            output_fd = os.open(
                leaf,
                os.O_WRONLY
                | os.O_CREAT
                | os.O_EXCL
                | getattr(os, "O_CLOEXEC", 0)
                | getattr(os, "O_NOFOLLOW", 0),
                0o600,
                dir_fd=parent_fd,
            )
            created = True
        except OSError as error:
            if error.errno in (errno.EEXIST, errno.ELOOP):
                fail("DESTINATION_EXISTS")
            fail("DESTINATION_CREATE")
        offset = 0
        while offset < len(data):
            written = os.write(output_fd, data[offset:])
            if written <= 0:
                fail("DESTINATION_WRITE")
            offset += written
        os.fchmod(output_fd, 0o600)
        os.fsync(output_fd)
        observed = os.fstat(output_fd)
        if (
            not stat.S_ISREG(observed.st_mode)
            or observed.st_uid != os.getuid()
            or observed.st_nlink != 1
            or observed.st_mode & 0o077
            or observed.st_size != len(data)
        ):
            fail("DESTINATION_VERIFY")
        os.close(output_fd)
        output_fd = -1
        os.fsync(parent_fd)
    except BaseException:
        if output_fd >= 0:
            os.close(output_fd)
        if created:
            try:
                os.unlink(leaf, dir_fd=parent_fd)
            except OSError:
                pass
        raise
    finally:
        os.close(parent_fd)


def serve(source: str, request_path: str, response_path: str) -> int:
    request_fd = open_fifo(request_path, os.O_RDONLY)
    response_fd = open_fifo(response_path, os.O_WRONLY)
    request = os.fdopen(request_fd, "rb", buffering=0)
    response = os.fdopen(response_fd, "wb", buffering=0)
    source_fd = -1
    try:
        try:
            source_fd, data, metadata, digest = open_source(source)
            emit(
                response,
                {
                    "schema": SCHEMA,
                    "status": "ready",
                    "source": {"bytes": len(data), "sha256": digest},
                },
            )
            command = read_command(request)
            if sorted(command) == ["op"] and command.get("op") == "shutdown":
                emit(response, {"schema": SCHEMA, "status": "stopped"})
                return 0
            if sorted(command) != ["destination", "op"] or command.get("op") != "stage":
                fail("PROTOCOL_COMMAND_SHAPE")
            destination = command.get("destination")
            if not isinstance(destination, str):
                fail("PROTOCOL_COMMAND_SHAPE")
            verify_source_snapshot(source_fd, data, metadata)
            stage_snapshot(destination, data)
            emit(
                response,
                {
                    "destination": {"bytes": len(data), "sha256": digest},
                    "schema": SCHEMA,
                    "status": "staged",
                },
            )
            return 0
        except GuardError as error:
            emit(response, {"code": error.code, "schema": SCHEMA, "status": "error"})
            print(f"auth guard: {error.code}", file=sys.stderr)
            return 1
    finally:
        if source_fd >= 0:
            os.close(source_fd)
        request.close()
        response.close()


def main(argv: List[str]) -> int:
    if len(argv) != 5 or argv[1] != "serve":
        print("usage: auth_guard.py serve SOURCE REQUEST_FIFO RESPONSE_FIFO", file=sys.stderr)
        return 2
    try:
        return serve(argv[2], argv[3], argv[4])
    except GuardError as error:
        print(f"auth guard: {error.code}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
