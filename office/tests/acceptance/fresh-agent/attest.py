#!/usr/bin/env python3
"""Run one Office command and bind its inputs, result, and completion bytes."""

import errno
import hashlib
import importlib.util
import json
import os
import stat
import subprocess
import sys
import tempfile


MAX_RESULT_BYTES = 8 * 1024 * 1024
MAX_BOUND_FILE_BYTES = 128 * 1024 * 1024
MAX_INPUT_SNAPSHOT_BYTES = 128 * 1024 * 1024
BOUND_SUFFIXES = (".xlsx", ".docx", ".html")
SNAPSHOT_SUFFIXES = (".xlsx", ".docx", ".html", ".json", ".xml")
INPUT_EVIDENCE_ROOT = "input-evidence"
ATTESTATION_SCHEMA = "office.fresh-agent.command-attestation/2"
ATTESTATION_PREFIX = "OFFICE_F1B_ATTESTATION\t"


class AttestationError(Exception):
    pass


def load_argument_policy():
    directory = os.path.dirname(os.path.abspath(__file__))
    for name in (".office-argument-policy.py", "argument_policy.py"):
        path = os.path.join(directory, name)
        if not os.path.isfile(path):
            continue
        spec = importlib.util.spec_from_file_location(
            "fresh_agent_argument_policy", path
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    raise AttestationError("Office argument policy is unavailable")


ARGUMENT_POLICY = load_argument_policy()


def safe_relative_path(value, label):
    try:
        return ARGUMENT_POLICY.safe_relative_path(value, label)
    except ARGUMENT_POLICY.ArgumentPolicyError as exc:
        raise AttestationError(str(exc))


def directory_flags():
    return (
        os.O_RDONLY
        | os.O_DIRECTORY
        | getattr(os, "O_CLOEXEC", 0)
        | getattr(os, "O_NOFOLLOW", 0)
    )


def open_relative_parent(root_fd, path, label):
    safe_relative_path(path, label)
    parts = path.split("/")
    current = os.dup(root_fd)
    try:
        for part in parts[:-1]:
            try:
                next_fd = os.open(part, directory_flags(), dir_fd=current)
            except OSError as exc:
                if exc.errno in (errno.ELOOP, errno.ENOTDIR):
                    raise AttestationError("%s parent traverses a symlink" % label)
                raise
            os.close(current)
            current = next_fd
        return current, parts[-1]
    except BaseException:
        os.close(current)
        raise


def validate_parent(root_fd, path, label):
    parent_fd, _leaf = open_relative_parent(root_fd, path, label)
    try:
        info = os.fstat(parent_fd)
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.geteuid():
            raise AttestationError("%s parent is not a probe-owned directory" % label)
    finally:
        os.close(parent_fd)


def validate_output_path(root_fd, path, label):
    parent_fd, leaf = open_relative_parent(root_fd, path, label)
    try:
        try:
            info = os.stat(leaf, dir_fd=parent_fd, follow_symlinks=False)
        except FileNotFoundError:
            return
        if (
            not stat.S_ISREG(info.st_mode)
            or stat.S_ISLNK(info.st_mode)
            or info.st_uid != os.geteuid()
            or info.st_nlink != 1
        ):
            raise AttestationError(
                "%s existing leaf is not a single-link probe-owned file" % label
            )
    finally:
        os.close(parent_fd)


def file_identity(info):
    return (
        info.st_dev,
        info.st_ino,
        info.st_mode,
        info.st_uid,
        info.st_nlink,
        info.st_size,
        info.st_mtime_ns,
        info.st_ctime_ns,
    )


def open_regular_file(root_fd, path, limit, label):
    parent_fd, leaf = open_relative_parent(root_fd, path, label)
    flags = (
        os.O_RDONLY
        | getattr(os, "O_CLOEXEC", 0)
        | getattr(os, "O_NOFOLLOW", 0)
        | getattr(os, "O_NONBLOCK", 0)
    )
    try:
        try:
            descriptor = os.open(leaf, flags, dir_fd=parent_fd)
        except OSError as exc:
            if exc.errno == errno.ELOOP:
                raise AttestationError("%s is a symlink" % label)
            raise
    finally:
        os.close(parent_fd)
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise AttestationError("%s is not a single-link regular file" % label)
        if info.st_uid != os.geteuid():
            raise AttestationError("%s is not owned by the probe user" % label)
        if info.st_size <= 0 or info.st_size > limit:
            raise AttestationError("%s size is outside the accepted domain" % label)
        return descriptor, info
    except BaseException:
        os.close(descriptor)
        raise


def read_digest(descriptor, limit, label):
    os.lseek(descriptor, 0, os.SEEK_SET)
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
    return total, digest.hexdigest()


def digest_regular_file(root_fd, path, limit, label):
    descriptor, before = open_regular_file(root_fd, path, limit, label)
    try:
        total, digest = read_digest(descriptor, limit, label)
        after = os.fstat(descriptor)
        if file_identity(before) != file_identity(after) or total != before.st_size:
            raise AttestationError("%s changed while it was hashed" % label)
        return {"bytes": total, "path": path, "sha256": digest}
    finally:
        os.close(descriptor)


def open_or_create_snapshot_root(root_fd):
    try:
        os.mkdir(INPUT_EVIDENCE_ROOT, 0o700, dir_fd=root_fd)
    except FileExistsError:
        pass
    try:
        descriptor = os.open(INPUT_EVIDENCE_ROOT, directory_flags(), dir_fd=root_fd)
    except OSError as exc:
        if exc.errno in (errno.ELOOP, errno.ENOTDIR):
            raise AttestationError("input evidence root is not a physical directory")
        raise
    info = os.fstat(descriptor)
    if (
        not stat.S_ISDIR(info.st_mode)
        or info.st_uid != os.geteuid()
        or info.st_mode & 0o077
    ):
        os.close(descriptor)
        raise AttestationError("input evidence root is not a private probe directory")
    return descriptor


def create_snapshot_event(evidence_fd):
    for _attempt in range(32):
        name = "event-" + os.urandom(16).hex()
        try:
            os.mkdir(name, 0o700, dir_fd=evidence_fd)
            descriptor = os.open(name, directory_flags(), dir_fd=evidence_fd)
            return name, descriptor
        except FileExistsError:
            continue
    raise AttestationError("could not allocate a unique input evidence event")


def snapshot_suffix(path):
    lowered = path.lower()
    for suffix in SNAPSHOT_SUFFIXES:
        if lowered.endswith(suffix):
            return suffix
    return ".input"


def write_snapshot(source_fd, source_info, event_fd, name, label):
    flags = (
        os.O_WRONLY
        | os.O_CREAT
        | os.O_EXCL
        | getattr(os, "O_CLOEXEC", 0)
        | getattr(os, "O_NOFOLLOW", 0)
    )
    snapshot_fd = os.open(name, flags, 0o600, dir_fd=event_fd)
    digest = hashlib.sha256()
    total = 0
    try:
        os.lseek(source_fd, 0, os.SEEK_SET)
        while True:
            chunk = os.read(source_fd, 1024 * 1024)
            if not chunk:
                break
            total += len(chunk)
            if total > MAX_INPUT_SNAPSHOT_BYTES:
                raise AttestationError(
                    "Office input snapshots exceed the accepted aggregate size"
                )
            digest.update(chunk)
            offset = 0
            while offset < len(chunk):
                written = os.write(snapshot_fd, chunk[offset:])
                if written <= 0:
                    raise AttestationError("%s snapshot write made no progress" % label)
                offset += written
        after = os.fstat(source_fd)
        if file_identity(source_info) != file_identity(after) or total != source_info.st_size:
            raise AttestationError("%s changed while it was snapshotted" % label)
        os.fchmod(snapshot_fd, 0o400)
        os.fsync(snapshot_fd)
        snapshot_info = os.fstat(snapshot_fd)
        if (
            not stat.S_ISREG(snapshot_info.st_mode)
            or snapshot_info.st_uid != os.geteuid()
            or snapshot_info.st_nlink != 1
            or stat.S_IMODE(snapshot_info.st_mode) != 0o400
            or snapshot_info.st_size != total
        ):
            raise AttestationError("%s snapshot failed verification" % label)
        return total, digest.hexdigest()
    finally:
        os.close(snapshot_fd)


def remove_snapshot_event(root_fd, event):
    if event is None:
        return
    evidence_fd = open_or_create_snapshot_root(root_fd)
    event_name, names = event
    try:
        event_fd = os.open(event_name, directory_flags(), dir_fd=evidence_fd)
        try:
            os.fchmod(event_fd, 0o700)
            for name in names:
                try:
                    os.unlink(name, dir_fd=event_fd)
                except FileNotFoundError:
                    pass
        finally:
            os.close(event_fd)
        os.rmdir(event_name, dir_fd=evidence_fd)
    finally:
        os.close(evidence_fd)


def snapshot_inputs(root_fd, references):
    inputs = [
        reference
        for reference in references
        if reference["access"] in ("input", "input-output")
    ]
    if not inputs:
        return [], [], None
    logical_paths = [reference["path"] for reference in inputs]
    if len(logical_paths) != len(set(logical_paths)):
        raise AttestationError("Office input paths must be unique per command")

    evidence_fd = open_or_create_snapshot_root(root_fd)
    event_name = None
    event_fd = -1
    names = []
    handles = []
    records = []
    aggregate = 0
    try:
        event_name, event_fd = create_snapshot_event(evidence_fd)
        for ordinal, reference in enumerate(inputs):
            label = "Office %s input" % reference["role"]
            source_fd, source_info = open_regular_file(
                root_fd, reference["path"], MAX_BOUND_FILE_BYTES, label
            )
            handles.append(
                {
                    "access": reference["access"],
                    "descriptor": source_fd,
                    "info": source_info,
                    "label": label,
                    "path": reference["path"],
                }
            )
            if aggregate + source_info.st_size > MAX_INPUT_SNAPSHOT_BYTES:
                raise AttestationError(
                    "Office input snapshots exceed the accepted aggregate size"
                )
            name = "%03d%s" % (ordinal, snapshot_suffix(reference["path"]))
            names.append(name)
            size, digest = write_snapshot(
                source_fd, source_info, event_fd, name, label
            )
            handles[-1]["sha256"] = digest
            aggregate += size
            if aggregate > MAX_INPUT_SNAPSHOT_BYTES:
                raise AttestationError(
                    "Office input snapshots exceed the accepted aggregate size"
                )
            snapshot_path = "%s/%s/%s" % (
                INPUT_EVIDENCE_ROOT,
                event_name,
                name,
            )
            records.append(
                {
                    "access": reference["access"],
                    "argument_index": reference["argument_index"],
                    "path": reference["path"],
                    "role": reference["role"],
                    "snapshot": {
                        "bytes": size,
                        "path": snapshot_path,
                        "sha256": digest,
                    },
                }
            )
        os.fchmod(event_fd, 0o500)
        os.fsync(event_fd)
        os.fsync(evidence_fd)
        return records, handles, (event_name, names)
    except BaseException:
        for handle in handles:
            os.close(handle["descriptor"])
        if event_fd >= 0:
            try:
                os.fchmod(event_fd, 0o700)
                for name in names:
                    try:
                        os.unlink(name, dir_fd=event_fd)
                    except FileNotFoundError:
                        pass
            finally:
                os.close(event_fd)
            try:
                os.rmdir(event_name, dir_fd=evidence_fd)
            except FileNotFoundError:
                pass
            event_fd = -1
        raise
    finally:
        if event_fd >= 0:
            os.close(event_fd)
        os.close(evidence_fd)


def verify_stable_inputs(root_fd, handles):
    for handle in handles:
        if handle["access"] != "input":
            continue
        descriptor = handle["descriptor"]
        before = handle["info"]
        label = handle["label"]
        total, digest = read_digest(descriptor, MAX_BOUND_FILE_BYTES, label)
        after = os.fstat(descriptor)
        if (
            file_identity(before) != file_identity(after)
            or total != before.st_size
            or digest != handle["sha256"]
        ):
            raise AttestationError("%s changed while Office was running" % label)
        path_fd, path_info = open_regular_file(
            root_fd, handle["path"], MAX_BOUND_FILE_BYTES, label
        )
        try:
            if (path_info.st_dev, path_info.st_ino) != (before.st_dev, before.st_ino):
                raise AttestationError("%s path was replaced while Office ran" % label)
        finally:
            os.close(path_fd)


def verify_input_paths_before_exec(root_fd, handles):
    for handle in handles:
        label = handle["label"]
        before = handle["info"]
        path_fd, path_info = open_regular_file(
            root_fd, handle["path"], MAX_BOUND_FILE_BYTES, label
        )
        try:
            total, digest = read_digest(path_fd, MAX_BOUND_FILE_BYTES, label)
            after = os.fstat(path_fd)
            if (
                file_identity(before) != file_identity(path_info)
                or file_identity(path_info) != file_identity(after)
                or total != before.st_size
                or digest != handle["sha256"]
            ):
                raise AttestationError(
                    "%s changed before Office execution" % label
                )
        finally:
            os.close(path_fd)


def close_input_handles(handles):
    for handle in handles:
        os.close(handle["descriptor"])
    handles[:] = []


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
    try:
        references = ARGUMENT_POLICY.classify_office_paths(arguments)
    except ARGUMENT_POLICY.ArgumentPolicyError as exc:
        raise AttestationError(str(exc))

    root_fd = os.open(".", directory_flags())
    input_records = []
    input_handles = []
    snapshot_event = None
    snapshots_retained = False
    published = False
    temporary = None
    try:
        safe_relative_path(result_path, "result path")
        if result_path == INPUT_EVIDENCE_ROOT or result_path.startswith(
            INPUT_EVIDENCE_ROOT + "/"
        ):
            raise AttestationError(
                "result path uses the host-managed input-evidence namespace"
            )
        validate_parent(root_fd, result_path, "result path")
        if not result_path.endswith(".json"):
            raise AttestationError("result path must end in .json")
        if os.path.lexists(result_path):
            raise AttestationError("result path already exists")
        if not arguments or arguments[-1] != "--json":
            raise AttestationError("Office product arguments must end in --json")
        for reference in references:
            validate_parent(
                root_fd,
                reference["path"],
                "Office %s" % reference["role"],
            )
            if reference["access"] == "output":
                validate_output_path(
                    root_fd,
                    reference["path"],
                    "Office %s" % reference["role"],
                )

        input_records, input_handles, snapshot_event = snapshot_inputs(
            root_fd, references
        )
        result_parent = os.path.dirname(result_path) or "."
        descriptor, temporary = tempfile.mkstemp(
            prefix=".office-attest.", suffix=".json", dir=result_parent
        )
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "wb", closefd=True) as stream:
            verify_input_paths_before_exec(root_fd, input_handles)
            process = subprocess.Popen(
                [target] + arguments,
                stdin=subprocess.DEVNULL,
                stdout=stream,
                close_fds=True,
            )
            status_code = process.wait()
            stream.flush()
            os.fsync(stream.fileno())
        verify_stable_inputs(root_fd, input_handles)
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

        result = digest_regular_file(
            root_fd, result_path, MAX_RESULT_BYTES, "Office JSON result"
        )
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
                digest_regular_file(
                    root_fd, path, MAX_BOUND_FILE_BYTES, "bound Office file"
                )
            )
        value = {
            "files": files,
            "inputs": input_records,
            "result": result,
            "schema": ATTESTATION_SCHEMA,
        }
        payload = json.dumps(value, sort_keys=True, separators=(",", ":"))
        sys.stdout.write(ATTESTATION_PREFIX + payload + "\n")
        sys.stdout.flush()
        snapshots_retained = True
        return 0
    except Exception:
        if published:
            try:
                os.unlink(result_path)
            except FileNotFoundError:
                pass
        raise
    finally:
        close_input_handles(input_handles)
        if not snapshots_retained:
            remove_snapshot_event(root_fd, snapshot_event)
        if temporary is not None:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass
        os.close(root_fd)


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
