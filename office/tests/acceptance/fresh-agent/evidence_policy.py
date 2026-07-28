#!/usr/bin/env python3
"""Publish and verify a bounded, self-contained fresh-agent evidence closure."""

import argparse
import hashlib
import json
import os
import re
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time


DEFAULT_MAX_ENTRIES = 10000
DEFAULT_MAX_BYTES = 768 * 1024 * 1024
DEFAULT_MAX_FILE_BYTES = 512 * 1024 * 1024
CHUNK_BYTES = 1024 * 1024
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
HEAD_RE = re.compile(r"^[0-9a-f]{40}$")
SAFE_COMPONENT_RE = re.compile(r"^[A-Za-z0-9._-]+$")

BASELINE_FILES = {
    "CANDIDATE.json",
    "COMMANDS.json",
    "CONFIG.toml",
    "RAW-COMMANDS.json",
    "RUN-PREFLIGHT.json",
    "RUN.json",
    "SCENARIOS.json",
    "WORKFLOWS.json",
    "codex-exit-status.txt",
    "codex-stderr.log",
    "codex-transcript.jsonl",
    "final-message.json",
    "permission-canary.log",
    "probe-result.md",
    "probe-transcript.md",
}
CANARY_FILES = {
    "CANDIDATE.json",
    "CONFIG.toml",
    "RUN-PREFLIGHT.json",
    "RUN.json",
    "permission-canary.log",
}


class PolicyError(Exception):
    pass


class Budget:
    def __init__(self, max_entries, max_bytes, max_file_bytes, timeout_seconds):
        self.max_entries = max_entries
        self.max_bytes = max_bytes
        self.max_file_bytes = max_file_bytes
        self.entries = 0
        self.bytes = 0
        self.deadline = time.monotonic() + timeout_seconds

    def check_deadline(self):
        if time.monotonic() >= self.deadline:
            raise PolicyError("evidence processing exceeded its deadline")

    def add_entry(self):
        self.check_deadline()
        self.entries += 1
        if self.entries > self.max_entries:
            raise PolicyError("evidence closure exceeds its entry limit")

    def add_file(self, size):
        if size < 0 or size > self.max_file_bytes:
            raise PolicyError("evidence artifact exceeds its per-file byte limit")
        if self.bytes + size > self.max_bytes:
            raise PolicyError("evidence closure exceeds its cumulative byte limit")
        self.bytes += size
        self.check_deadline()


def mode_string(mode):
    return "%04o" % stat.S_IMODE(mode)


def validate_digest(value, label):
    if not SHA256_RE.fullmatch(value):
        raise PolicyError("%s must be a lowercase SHA-256 digest" % label)


def validate_head(value):
    if not HEAD_RE.fullmatch(value):
        raise PolicyError("candidate head must be a lowercase 40-character object id")


def validate_limits(args):
    if args.timeout_seconds < 1 or args.timeout_seconds > 600:
        raise PolicyError("timeout must be between 1 and 600 seconds")
    if args.max_entries < 1 or args.max_entries > DEFAULT_MAX_ENTRIES:
        raise PolicyError("entry limit is outside the approved range")
    if args.max_bytes < 1 or args.max_bytes > DEFAULT_MAX_BYTES:
        raise PolicyError("byte limit is outside the approved range")
    if args.max_file_bytes < 1 or args.max_file_bytes > DEFAULT_MAX_FILE_BYTES:
        raise PolicyError("per-file byte limit is outside the approved range")
    if args.max_file_bytes > args.max_bytes:
        raise PolicyError("per-file byte limit exceeds the cumulative limit")


def require_absolute(path, label):
    if not os.path.isabs(path):
        raise PolicyError("%s must be absolute" % label)
    return os.path.normpath(path)


def require_directory(path, label, private=True, owned=True):
    path = require_absolute(path, label)
    try:
        observed = os.lstat(path)
    except OSError as exc:
        raise PolicyError("could not inspect %s: %s" % (label, exc))
    if not stat.S_ISDIR(observed.st_mode):
        raise PolicyError("%s must be a physical directory" % label)
    if owned and observed.st_uid != os.getuid():
        raise PolicyError("%s is not owned by the current user" % label)
    if private and stat.S_IMODE(observed.st_mode) & 0o077:
        raise PolicyError("%s grants group or world access" % label)
    return path, observed


def require_regular(path, label, private=False, owned=False, single_link=False):
    path = require_absolute(path, label)
    try:
        observed = os.lstat(path)
    except OSError as exc:
        raise PolicyError("could not inspect %s: %s" % (label, exc))
    if not stat.S_ISREG(observed.st_mode):
        raise PolicyError("%s must be a physical regular file" % label)
    if owned and observed.st_uid != os.getuid():
        raise PolicyError("%s is not owned by the current user" % label)
    if private and stat.S_IMODE(observed.st_mode) & 0o077:
        raise PolicyError("%s grants group or world access" % label)
    if single_link and observed.st_nlink != 1:
        raise PolicyError("%s must have exactly one hard link" % label)
    return path, observed


def validate_relative(relative, label, lowercase=False):
    if not relative or relative.startswith("/"):
        raise PolicyError("%s is not a canonical relative path" % label)
    components = relative.split("/")
    if any(
        component in ("", ".", "..") or not SAFE_COMPONENT_RE.fullmatch(component)
        for component in components
    ):
        raise PolicyError("%s contains a non-portable path component" % label)
    if lowercase and relative != relative.lower():
        raise PolicyError("%s must use lowercase portable paths" % label)


def paths_overlap(first, second):
    first = os.path.normpath(first)
    second = os.path.normpath(second)
    return (
        first == second
        or first.startswith(second + os.sep)
        or second.startswith(first + os.sep)
    )


def same_stat(before, after):
    return (
        before.st_dev,
        before.st_ino,
        before.st_mode,
        before.st_nlink,
        before.st_size,
        before.st_mtime_ns,
    ) == (
        after.st_dev,
        after.st_ino,
        after.st_mode,
        after.st_nlink,
        after.st_size,
        after.st_mtime_ns,
    )


def write_all(fd, payload):
    offset = 0
    while offset < len(payload):
        written = os.write(fd, payload[offset:])
        if written <= 0:
            raise PolicyError("short write while publishing evidence")
        offset += written


def copy_regular(
    source,
    destination,
    budget,
    final_mode=None,
    expected_sha256=None,
    require_owner=True,
    require_single_link=True,
):
    source, before = require_regular(
        source,
        "evidence source file",
        private=require_owner,
        owned=require_owner,
        single_link=require_single_link,
    )
    budget.add_file(before.st_size)
    source_flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    destination_flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    source_fd = os.open(source, source_flags)
    destination_fd = -1
    digest = hashlib.sha256()
    copied = 0
    try:
        opened = os.fstat(source_fd)
        if not same_stat(before, opened):
            raise PolicyError("evidence source changed before it was opened")
        destination_fd = os.open(destination, destination_flags, 0o600)
        while True:
            budget.check_deadline()
            chunk = os.read(source_fd, CHUNK_BYTES)
            if not chunk:
                break
            digest.update(chunk)
            write_all(destination_fd, chunk)
            copied += len(chunk)
        if copied != before.st_size:
            raise PolicyError("evidence source changed size while it was copied")
        after = os.fstat(source_fd)
        if not same_stat(opened, after):
            raise PolicyError("evidence source changed while it was copied")
        actual_sha256 = digest.hexdigest()
        if expected_sha256 is not None and actual_sha256 != expected_sha256:
            raise PolicyError("evidence source does not match its approved digest")
        os.fchmod(
            destination_fd,
            final_mode if final_mode is not None else stat.S_IMODE(before.st_mode),
        )
        os.fsync(destination_fd)
    finally:
        os.close(source_fd)
        if destination_fd >= 0:
            os.close(destination_fd)
    return {"bytes": copied, "sha256": digest.hexdigest()}


def copy_tree(source, destination, budget, tree_kind):
    source, root_before = require_directory(
        source, "%s source" % tree_kind, private=True, owned=True
    )
    os.mkdir(destination, 0o700)

    def visit(source_dir, destination_dir, relative_dir):
        budget.check_deadline()
        with os.scandir(source_dir) as iterator:
            entries = sorted(iterator, key=lambda entry: os.fsencode(entry.name))
        for entry in entries:
            relative = entry.name if not relative_dir else relative_dir + "/" + entry.name
            validate_relative(
                relative,
                "%s entry" % tree_kind,
                lowercase=(tree_kind == "probe"),
            )
            budget.add_entry()
            source_path = os.path.join(source_dir, entry.name)
            destination_path = os.path.join(destination_dir, entry.name)
            observed = os.lstat(source_path)
            if observed.st_uid != os.getuid():
                raise PolicyError("%s entry is not owned by the current user" % tree_kind)
            if stat.S_ISDIR(observed.st_mode):
                if stat.S_IMODE(observed.st_mode) & 0o077:
                    raise PolicyError("%s directory grants group or world access" % tree_kind)
                os.mkdir(destination_path, 0o700)
                visit(source_path, destination_path, relative)
                after = os.lstat(source_path)
                if not same_stat(observed, after):
                    raise PolicyError("%s directory changed while it was copied" % tree_kind)
                os.chmod(destination_path, stat.S_IMODE(observed.st_mode))
            elif stat.S_ISREG(observed.st_mode):
                if stat.S_IMODE(observed.st_mode) & 0o077:
                    raise PolicyError("%s file grants group or world access" % tree_kind)
                copy_regular(source_path, destination_path, budget)
            elif stat.S_ISLNK(observed.st_mode):
                target = os.readlink(source_path)
                if tree_kind != "candidate" or relative != "bin/office" or target != "office-native":
                    raise PolicyError("%s contains an unapproved symlink" % tree_kind)
                os.symlink(target, destination_path)
                after = os.lstat(source_path)
                if not same_stat(observed, after) or os.readlink(source_path) != target:
                    raise PolicyError("candidate symlink changed while it was copied")
            else:
                raise PolicyError("%s contains an unsupported filesystem entry" % tree_kind)

    visit(source, destination, "")
    root_after = os.lstat(source)
    if not same_stat(root_before, root_after):
        raise PolicyError("%s root changed while it was copied" % tree_kind)
    os.chmod(destination, stat.S_IMODE(root_before.st_mode))


def write_json_file(path, document, mode, budget):
    payload = (
        json.dumps(document, ensure_ascii=True, indent=2, sort_keys=True) + "\n"
    ).encode("ascii")
    budget.add_entry()
    budget.add_file(len(payload))
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        write_all(fd, payload)
        os.fchmod(fd, mode)
        os.fsync(fd)
    finally:
        os.close(fd)


def make_writable(path):
    if not os.path.exists(path) and not os.path.islink(path):
        return
    for root, directories, files in os.walk(path, topdown=True, followlinks=False):
        try:
            os.chmod(root, 0o700)
        except OSError:
            pass
        for name in directories + files:
            candidate = os.path.join(root, name)
            if not os.path.islink(candidate):
                try:
                    os.chmod(candidate, 0o700)
                except OSError:
                    pass


def publish(args):
    validate_head(args.candidate_head)
    validate_digest(args.candidate_sha256, "candidate manifest digest")
    validate_digest(args.codex_sha256, "Codex digest")
    evidence_root, _ = require_directory(
        args.evidence_root, "evidence root", private=True, owned=True
    )
    candidate_root, _ = require_directory(
        args.candidate_root, "candidate root", private=True, owned=True
    )
    probe_root, _ = require_directory(
        args.probe_root, "probe root", private=True, owned=True
    )
    codex_bin, codex_stat = require_regular(
        args.codex_bin,
        "Codex executable",
        private=True,
        owned=True,
        single_link=True,
    )
    if stat.S_IMODE(codex_stat.st_mode) != 0o500:
        raise PolicyError("staged Codex executable has an unexpected mode")
    protected_roots = (evidence_root, candidate_root, probe_root)
    for index, first in enumerate(protected_roots):
        for second in protected_roots[index + 1 :]:
            if paths_overlap(first, second):
                raise PolicyError("evidence publication roots must not overlap")
    for protected_root in protected_roots:
        if paths_overlap(protected_root, codex_bin):
            raise PolicyError("Codex executable must not overlap a publication root")
    if os.path.exists(os.path.join(evidence_root, "closure")) or os.path.islink(
        os.path.join(evidence_root, "closure")
    ):
        raise PolicyError("evidence closure already exists")
    if args.bwrap_selection == "none":
        if args.bwrap_bin is not None or args.bwrap_sha256 is not None:
            raise PolicyError("bubblewrap inputs are incompatible with selection none")
    else:
        if args.bwrap_bin is None or args.bwrap_sha256 is None:
            raise PolicyError("selected bubblewrap requires an executable and digest")
        validate_digest(args.bwrap_sha256, "bubblewrap digest")
        require_regular(args.bwrap_bin, "bubblewrap executable")

    budget = Budget(
        args.max_entries,
        args.max_bytes,
        args.max_file_bytes,
        args.timeout_seconds,
    )
    temporary = tempfile.mkdtemp(prefix=".closure.tmp-", dir=evidence_root)
    closure = os.path.join(evidence_root, "closure")
    try:
        budget.add_entry()
        budget.add_entry()
        copy_tree(candidate_root, os.path.join(temporary, "candidate"), budget, "candidate")
        budget.add_entry()
        copy_tree(probe_root, os.path.join(temporary, "probe"), budget, "probe")
        runtime = os.path.join(temporary, "runtime")
        os.mkdir(runtime, 0o700)
        budget.add_entry()
        budget.add_entry()
        codex_record = copy_regular(
            codex_bin,
            os.path.join(runtime, "codex"),
            budget,
            final_mode=0o500,
            expected_sha256=args.codex_sha256,
        )
        bubblewrap_record = None
        if args.bwrap_selection != "none":
            budget.add_entry()
            copied_bwrap = copy_regular(
                args.bwrap_bin,
                os.path.join(runtime, "bwrap"),
                budget,
                final_mode=0o500,
                expected_sha256=args.bwrap_sha256,
                require_owner=False,
                require_single_link=False,
            )
            bubblewrap_record = {
                "bytes": copied_bwrap["bytes"],
                "path": "bwrap",
                "selection": args.bwrap_selection,
                "sha256": copied_bwrap["sha256"],
            }
        runtime_document = {
            "bubblewrap": bubblewrap_record,
            "candidate_head": args.candidate_head,
            "candidate_manifest_sha256": args.candidate_sha256,
            "codex": {
                "bytes": codex_record["bytes"],
                "path": "codex",
                "sha256": codex_record["sha256"],
                "version": args.codex_version,
            },
            "schema": "office.fresh-agent.runtime/1",
        }
        write_json_file(
            os.path.join(runtime, "RUNTIME.json"), runtime_document, 0o400, budget
        )
        os.chmod(runtime, 0o500)
        os.chmod(temporary, 0o500)
        budget.check_deadline()
        os.rename(temporary, closure)
        temporary = ""
        parent_fd = os.open(evidence_root, os.O_RDONLY)
        try:
            os.fsync(parent_fd)
        finally:
            os.close(parent_fd)
    finally:
        if temporary:
            make_writable(temporary)
            shutil.rmtree(temporary, ignore_errors=True)


def expected_top_level(mode):
    return (BASELINE_FILES if mode == "baseline" else CANARY_FILES) | {"closure"}


def sha256_regular(path, observed, budget):
    budget.add_file(observed.st_size)
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags)
    digest = hashlib.sha256()
    consumed = 0
    try:
        opened = os.fstat(fd)
        if not same_stat(observed, opened):
            raise PolicyError("evidence artifact changed before hashing")
        while True:
            budget.check_deadline()
            chunk = os.read(fd, CHUNK_BYTES)
            if not chunk:
                break
            digest.update(chunk)
            consumed += len(chunk)
        after = os.fstat(fd)
        if not same_stat(opened, after) or consumed != observed.st_size:
            raise PolicyError("evidence artifact changed while hashing")
    finally:
        os.close(fd)
    return digest.hexdigest()


def collect_artifacts(evidence_root, mode, budget):
    evidence_root, _ = require_directory(
        evidence_root, "evidence root", private=True, owned=True
    )
    top_level = set(os.listdir(evidence_root))
    top_level.discard("EVIDENCE.json")
    if top_level != expected_top_level(mode):
        raise PolicyError("evidence root has an unexpected or missing artifact")
    artifacts = []

    def visit(directory, relative_dir):
        with os.scandir(directory) as iterator:
            entries = sorted(iterator, key=lambda entry: os.fsencode(entry.name))
        for entry in entries:
            relative = entry.name if not relative_dir else relative_dir + "/" + entry.name
            if relative == "EVIDENCE.json":
                continue
            validate_relative(relative, "evidence artifact")
            budget.add_entry()
            path = os.path.join(directory, entry.name)
            observed = os.lstat(path)
            if observed.st_uid != os.getuid():
                raise PolicyError("evidence artifact is not owned by the current user")
            if stat.S_ISDIR(observed.st_mode):
                if stat.S_IMODE(observed.st_mode) & 0o077:
                    raise PolicyError("evidence directory grants group or world access")
                artifacts.append(
                    {
                        "kind": "directory",
                        "mode": mode_string(observed.st_mode),
                        "path": relative,
                    }
                )
                visit(path, relative)
            elif stat.S_ISREG(observed.st_mode):
                if stat.S_IMODE(observed.st_mode) & 0o077 or observed.st_nlink != 1:
                    raise PolicyError("evidence file is not private and single-linked")
                artifacts.append(
                    {
                        "bytes": observed.st_size,
                        "kind": "file",
                        "mode": mode_string(observed.st_mode),
                        "path": relative,
                        "sha256": sha256_regular(path, observed, budget),
                    }
                )
            elif stat.S_ISLNK(observed.st_mode):
                target = os.readlink(path)
                if relative != "closure/candidate/bin/office" or target != "office-native":
                    raise PolicyError("evidence contains an unapproved symlink")
                artifacts.append(
                    {"kind": "symlink", "path": relative, "target": target}
                )
            else:
                raise PolicyError("evidence contains an unsupported filesystem entry")

    visit(evidence_root, "")
    artifacts.sort(key=lambda artifact: artifact["path"].encode("utf-8"))
    return artifacts


def evidence_schema(mode):
    if mode == "baseline":
        return "office.fresh-agent.evidence/2"
    return "office.fresh-agent.canary-evidence/2"


def reject_duplicate_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise PolicyError("JSON artifact contains a duplicate object key")
        result[key] = value
    return result


def reject_json_constant(value):
    raise PolicyError("JSON artifact contains a non-finite number: %s" % value)


def read_bounded_json(path, label, maximum=16 * 1024 * 1024):
    path, observed = require_regular(
        path, label, private=True, owned=True, single_link=True
    )
    if observed.st_size > maximum:
        raise PolicyError("%s exceeds its byte limit" % label)
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags)
    payload = bytearray()
    try:
        opened = os.fstat(fd)
        if not same_stat(observed, opened):
            raise PolicyError("%s changed before it was opened" % label)
        while True:
            chunk = os.read(fd, CHUNK_BYTES)
            if not chunk:
                break
            payload.extend(chunk)
        after = os.fstat(fd)
        if not same_stat(opened, after) or len(payload) != observed.st_size:
            raise PolicyError("%s changed while it was read" % label)
    finally:
        os.close(fd)
    try:
        document = json.loads(
            payload,
            object_pairs_hook=reject_duplicate_pairs,
            parse_constant=reject_json_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise PolicyError("%s is not strict JSON: %s" % (label, exc))
    return document


def artifact_map(artifacts):
    result = {}
    for artifact in artifacts:
        path = artifact["path"]
        if path in result:
            raise PolicyError("evidence manifest contains a duplicate artifact path")
        result[path] = artifact
    return result


def validate_candidate_closure(evidence_root, candidate_head, candidate_sha256, artifacts):
    records = artifact_map(artifacts)
    top_candidate = records.get("CANDIDATE.json")
    closure_candidate = records.get("closure/candidate/CANDIDATE.json")
    for record in (top_candidate, closure_candidate):
        if (
            not isinstance(record, dict)
            or record.get("kind") != "file"
            or record.get("sha256") != candidate_sha256
        ):
            raise PolicyError("evidence does not bind both candidate manifests")
    candidate_path = os.path.join(evidence_root, "closure", "candidate", "CANDIDATE.json")
    candidate = read_bounded_json(candidate_path, "candidate closure manifest")
    if not isinstance(candidate, dict) or set(candidate) != {
        "build",
        "candidate_head",
        "files",
        "schema",
        "symlinks",
    }:
        raise PolicyError("candidate closure manifest has unexpected fields")
    if (
        candidate.get("schema") != "office.fresh-agent.candidate/5"
        or candidate.get("candidate_head") != candidate_head
        or not isinstance(candidate.get("files"), list)
        or not isinstance(candidate.get("symlinks"), list)
    ):
        raise PolicyError("candidate closure manifest has invalid identity")
    expected_paths = {"closure/candidate/CANDIDATE.json"}
    declared_paths = set()
    for entry in candidate["files"]:
        if not isinstance(entry, dict) or set(entry) != {"kind", "mode", "path", "sha256"}:
            raise PolicyError("candidate closure has an invalid file record")
        relative = entry["path"]
        if not isinstance(relative, str):
            raise PolicyError("candidate closure file path is not a string")
        validate_relative(relative, "candidate closure file")
        validate_digest(entry["sha256"], "candidate closure file digest")
        if entry["kind"] != "file" or entry["mode"] not in ("0400", "0500"):
            raise PolicyError("candidate closure has an invalid file kind or mode")
        path = "closure/candidate/" + relative
        if path in declared_paths:
            raise PolicyError("candidate closure declares a duplicate file path")
        declared_paths.add(path)
        expected_paths.add(path)
        observed = records.get(path)
        if (
            not isinstance(observed, dict)
            or set(observed) != {"bytes", "kind", "mode", "path", "sha256"}
            or observed.get("kind") != "file"
            or observed.get("mode") != entry["mode"]
            or observed.get("path") != path
            or observed.get("sha256") != entry["sha256"]
        ):
            raise PolicyError("candidate closure file does not match its manifest")
    if len(candidate["symlinks"]) != 1:
        raise PolicyError("candidate closure must declare exactly one alias")
    for entry in candidate["symlinks"]:
        if not isinstance(entry, dict) or set(entry) != {"path", "target"}:
            raise PolicyError("candidate closure has an invalid symlink record")
        relative = entry["path"]
        target = entry["target"]
        if relative != "bin/office" or target != "office-native":
            raise PolicyError("candidate closure has an unapproved symlink record")
        path = "closure/candidate/" + relative
        if path in declared_paths:
            raise PolicyError("candidate closure declares a duplicate path")
        declared_paths.add(path)
        expected_paths.add(path)
        if records.get(path) != {"kind": "symlink", "path": path, "target": target}:
            raise PolicyError("candidate closure symlink does not match its manifest")
    actual_paths = {
        path
        for path, record in records.items()
        if path.startswith("closure/candidate/") and record["kind"] != "directory"
    }
    if actual_paths != expected_paths:
        raise PolicyError("candidate closure contains an unexpected or missing file")


def validate_runtime_closure(evidence_root, candidate_head, candidate_sha256, artifacts):
    records = artifact_map(artifacts)
    runtime_path = os.path.join(evidence_root, "closure", "runtime", "RUNTIME.json")
    runtime = read_bounded_json(runtime_path, "runtime closure manifest", maximum=1024 * 1024)
    if not isinstance(runtime, dict) or set(runtime) != {
        "bubblewrap",
        "candidate_head",
        "candidate_manifest_sha256",
        "codex",
        "schema",
    }:
        raise PolicyError("runtime closure manifest has unexpected fields")
    if (
        runtime.get("schema") != "office.fresh-agent.runtime/1"
        or runtime.get("candidate_head") != candidate_head
        or runtime.get("candidate_manifest_sha256") != candidate_sha256
    ):
        raise PolicyError("runtime closure manifest has invalid candidate identity")
    codex = runtime.get("codex")
    if not isinstance(codex, dict) or set(codex) != {
        "bytes",
        "path",
        "sha256",
        "version",
    }:
        raise PolicyError("runtime closure has an invalid Codex record")
    validate_digest(codex.get("sha256", ""), "runtime Codex digest")
    if (
        codex.get("path") != "codex"
        or not isinstance(codex.get("bytes"), int)
        or codex.get("bytes") <= 0
        or not isinstance(codex.get("version"), str)
        or not codex.get("version")
    ):
        raise PolicyError("runtime closure has an invalid Codex identity")
    codex_record = records.get("closure/runtime/codex")
    if (
        not isinstance(codex_record, dict)
        or codex_record.get("kind") != "file"
        or codex_record.get("mode") != "0500"
        or codex_record.get("bytes") != codex.get("bytes")
        or codex_record.get("sha256") != codex.get("sha256")
    ):
        raise PolicyError("runtime Codex file does not match its manifest")
    bubblewrap = runtime.get("bubblewrap")
    bubblewrap_record = records.get("closure/runtime/bwrap")
    if bubblewrap is None:
        if bubblewrap_record is not None:
            raise PolicyError("runtime closure has an unbound bubblewrap file")
    else:
        if not isinstance(bubblewrap, dict) or set(bubblewrap) != {
            "bytes",
            "path",
            "selection",
            "sha256",
        }:
            raise PolicyError("runtime closure has an invalid bubblewrap record")
        validate_digest(bubblewrap.get("sha256", ""), "runtime bubblewrap digest")
        if (
            bubblewrap.get("path") != "bwrap"
            or bubblewrap.get("selection") not in ("system", "private")
            or not isinstance(bubblewrap.get("bytes"), int)
            or bubblewrap.get("bytes") <= 0
            or not isinstance(bubblewrap_record, dict)
            or bubblewrap_record.get("kind") != "file"
            or bubblewrap_record.get("mode") != "0500"
            or bubblewrap_record.get("bytes") != bubblewrap.get("bytes")
            or bubblewrap_record.get("sha256") != bubblewrap.get("sha256")
        ):
            raise PolicyError("runtime bubblewrap file does not match its manifest")


def validate_run_anchors(evidence_root, candidate_head, candidate_sha256):
    for name in ("RUN-PREFLIGHT.json", "RUN.json"):
        document = read_bounded_json(
            os.path.join(evidence_root, name), name, maximum=1024 * 1024
        )
        if (
            not isinstance(document, dict)
            or document.get("candidate_head") != candidate_head
            or document.get("candidate_manifest_sha256") != candidate_sha256
        ):
            raise PolicyError("%s does not bind the evidence candidate" % name)


def validate_scenario_evidence(evidence_root, budget):
    policy_path = os.path.join(
        evidence_root,
        "closure",
        "candidate",
        "control",
        "scenario-policy.py",
    )
    require_regular(
        policy_path,
        "retained scenario policy",
        private=True,
        owned=True,
        single_link=True,
    )
    budget.check_deadline()
    remaining = budget.deadline - time.monotonic()
    if remaining <= 0:
        raise PolicyError("evidence processing exceeded its deadline")
    command = [
        sys.executable,
        "-I",
        policy_path,
        "verify",
        os.path.join(evidence_root, "closure", "probe"),
        os.path.join(evidence_root, "COMMANDS.json"),
        os.path.join(evidence_root, "RAW-COMMANDS.json"),
        os.path.join(evidence_root, "WORKFLOWS.json"),
        os.path.join(evidence_root, "SCENARIOS.json"),
    ]
    try:
        result = subprocess.run(
            command,
            cwd=evidence_root,
            env={"PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"},
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
            close_fds=True,
            timeout=remaining,
        )
    except subprocess.TimeoutExpired as error:
        raise PolicyError("retained scenario verification exceeded its deadline") from error
    if result.returncode != 0:
        raise PolicyError(
            "scenario evidence does not reproduce from the retained probe closure"
        )
    budget.check_deadline()


def manifest_document(args, budget):
    validate_head(args.candidate_head)
    validate_digest(args.candidate_sha256, "candidate manifest digest")
    artifacts = collect_artifacts(args.evidence_root, args.mode, budget)
    validate_candidate_closure(
        args.evidence_root, args.candidate_head, args.candidate_sha256, artifacts
    )
    validate_runtime_closure(
        args.evidence_root, args.candidate_head, args.candidate_sha256, artifacts
    )
    validate_run_anchors(
        args.evidence_root, args.candidate_head, args.candidate_sha256
    )
    if args.mode == "baseline":
        validate_scenario_evidence(args.evidence_root, budget)
    file_count = sum(artifact["kind"] == "file" for artifact in artifacts)
    return {
        "artifact_count": len(artifacts),
        "artifacts": artifacts,
        "candidate_head": args.candidate_head,
        "candidate_manifest_sha256": args.candidate_sha256,
        "file_count": file_count,
        "schema": evidence_schema(args.mode),
        "total_bytes": budget.bytes,
    }


def write_manifest(args):
    output = require_absolute(args.output, "manifest output")
    evidence_root, _ = require_directory(
        args.evidence_root, "evidence root", private=True, owned=True
    )
    output_parent, _ = require_directory(
        os.path.dirname(output), "manifest output parent", private=True, owned=True
    )
    if paths_overlap(evidence_root, output):
        raise PolicyError("manifest staging output must be outside the evidence root")
    evidence_manifest = os.path.join(evidence_root, "EVIDENCE.json")
    if os.path.exists(evidence_manifest) or os.path.islink(evidence_manifest):
        raise PolicyError("evidence manifest must be absent during generation")
    if os.path.exists(output) or os.path.islink(output):
        raise PolicyError("manifest output must be absent")
    budget = Budget(
        args.max_entries,
        args.max_bytes,
        args.max_file_bytes,
        args.timeout_seconds,
    )
    document = manifest_document(args, budget)
    payload = (
        json.dumps(document, ensure_ascii=True, indent=2, sort_keys=True) + "\n"
    ).encode("ascii")
    temporary_fd, temporary = tempfile.mkstemp(
        prefix=os.path.basename(output) + ".tmp-", dir=os.path.dirname(output)
    )
    try:
        write_all(temporary_fd, payload)
        os.fchmod(temporary_fd, 0o600)
        os.fsync(temporary_fd)
        os.close(temporary_fd)
        temporary_fd = -1
        os.rename(temporary, output)
        temporary = ""
    finally:
        if temporary_fd >= 0:
            os.close(temporary_fd)
        if temporary:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass


def read_manifest(path):
    document = read_bounded_json(path, "evidence manifest")
    if not isinstance(document, dict):
        raise PolicyError("evidence manifest must be an object")
    return document


def verify(args):
    evidence_root, _ = require_directory(
        args.evidence_root, "evidence root", private=True, owned=True
    )
    expected_manifest = os.path.join(evidence_root, "EVIDENCE.json")
    if os.path.normpath(args.manifest) != expected_manifest:
        raise PolicyError("evidence manifest must be EVIDENCE.json in the evidence root")
    document = read_manifest(args.manifest)
    required_keys = {
        "artifact_count",
        "artifacts",
        "candidate_head",
        "candidate_manifest_sha256",
        "file_count",
        "schema",
        "total_bytes",
    }
    if set(document) != required_keys:
        raise PolicyError("evidence manifest has unexpected fields")
    schema = document.get("schema")
    if schema == evidence_schema("baseline"):
        mode = "baseline"
    elif schema == evidence_schema("canary"):
        mode = "canary"
    else:
        raise PolicyError("evidence manifest has an unsupported schema")
    candidate_head = document.get("candidate_head")
    candidate_sha256 = document.get("candidate_manifest_sha256")
    validate_head(candidate_head)
    validate_digest(candidate_sha256, "candidate manifest digest")
    budget = Budget(
        args.max_entries,
        args.max_bytes,
        args.max_file_bytes,
        args.timeout_seconds,
    )
    synthetic = argparse.Namespace(
        candidate_head=candidate_head,
        candidate_sha256=candidate_sha256,
        evidence_root=evidence_root,
        mode=mode,
    )
    expected = manifest_document(synthetic, budget)
    if document != expected:
        raise PolicyError("evidence closure does not match EVIDENCE.json")


def add_limits(parser):
    parser.add_argument("--timeout-seconds", type=int, required=True)
    parser.add_argument("--max-entries", type=int, default=DEFAULT_MAX_ENTRIES)
    parser.add_argument("--max-bytes", type=int, default=DEFAULT_MAX_BYTES)
    parser.add_argument(
        "--max-file-bytes", type=int, default=DEFAULT_MAX_FILE_BYTES
    )


def parse_args(argv):
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="operation", required=True)

    publish_parser = subparsers.add_parser("publish")
    publish_parser.add_argument("--evidence-root", required=True)
    publish_parser.add_argument("--candidate-root", required=True)
    publish_parser.add_argument("--probe-root", required=True)
    publish_parser.add_argument("--candidate-head", required=True)
    publish_parser.add_argument("--candidate-sha256", required=True)
    publish_parser.add_argument("--codex-bin", required=True)
    publish_parser.add_argument("--codex-version", required=True)
    publish_parser.add_argument("--codex-sha256", required=True)
    publish_parser.add_argument(
        "--bwrap-selection", choices=("none", "system", "private"), required=True
    )
    publish_parser.add_argument("--bwrap-bin")
    publish_parser.add_argument("--bwrap-sha256")
    add_limits(publish_parser)

    manifest_parser = subparsers.add_parser("manifest")
    manifest_parser.add_argument("--evidence-root", required=True)
    manifest_parser.add_argument("--mode", choices=("baseline", "canary"), required=True)
    manifest_parser.add_argument("--candidate-head", required=True)
    manifest_parser.add_argument("--candidate-sha256", required=True)
    manifest_parser.add_argument("--output", required=True)
    add_limits(manifest_parser)

    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("--evidence-root", required=True)
    verify_parser.add_argument("--manifest", required=True)
    add_limits(verify_parser)
    return parser.parse_args(argv)


def main(argv):
    try:
        args = parse_args(argv[1:])
        validate_limits(args)
        def timeout_handler(_signum, _frame):
            raise PolicyError("evidence processing exceeded its deadline")

        signal.signal(signal.SIGALRM, timeout_handler)
        signal.setitimer(signal.ITIMER_REAL, args.timeout_seconds)
        if args.operation == "publish":
            publish(args)
        elif args.operation == "manifest":
            write_manifest(args)
        else:
            verify(args)
        signal.setitimer(signal.ITIMER_REAL, 0)
        return 0
    except (OSError, PolicyError, ValueError) as exc:
        print("error: %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
