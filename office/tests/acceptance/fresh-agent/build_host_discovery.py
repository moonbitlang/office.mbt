#!/usr/bin/env python3
"""Discover and bind the native compiler host closure in a clean environment."""

import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import tempfile


MAX_OUTPUT_BYTES = 8 * 1024 * 1024
MAX_LOADER_FILES = 256
COMMAND_TIMEOUT_SECONDS = 30
SAFE_PATH_ENV = "/usr/bin:/bin:/usr/sbin:/sbin"
DYLD_IMAGE = re.compile(r"<([0-9A-Fa-f-]{36})> (/.+)$")


class DiscoveryError(Exception):
    pass


def fail(message):
    raise DiscoveryError(message)


def safe_text(value, label, multiline=False):
    if not value:
        fail("%s is empty" % label)
    if "\x00" in value or "\r" in value or (not multiline and "\n" in value):
        fail("%s contains unsafe control syntax" % label)
    return value


def clean_environment(sdkroot):
    environment = {"PATH": SAFE_PATH_ENV, "LANG": "C", "LC_ALL": "C"}
    if sdkroot:
        environment["SDKROOT"] = sdkroot
    return environment


def run_command(argv, environment, accepted=(0,)):
    try:
        result = subprocess.run(
            argv,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=environment,
            timeout=COMMAND_TIMEOUT_SECONDS,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise DiscoveryError("could not execute build-host query: %s" % argv[0]) from error
    if len(result.stdout) > MAX_OUTPUT_BYTES or len(result.stderr) > MAX_OUTPUT_BYTES:
        fail("build-host query output exceeds 8 MiB: %s" % argv[0])
    if accepted is not None and result.returncode not in accepted:
        diagnostic = result.stderr.decode("utf-8", "replace").strip().splitlines()
        suffix = ": %s" % diagnostic[0] if diagnostic else ""
        fail("build-host query failed (%d): %s%s" % (result.returncode, argv[0], suffix))
    return result


def decode_output(payload, label, multiline=False):
    try:
        value = payload.decode("utf-8")
    except UnicodeError as error:
        raise DiscoveryError("%s is not UTF-8" % label) from error
    value = value.strip()
    return safe_text(value, label, multiline=multiline)


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb", buffering=0) as stream:
        while True:
            chunk = stream.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def validate_logical_path(path, label):
    safe_text(path, label)
    if not os.path.isabs(path) or os.path.normpath(path) != path or path == "/":
        fail("%s is not a canonical absolute descendant path: %s" % (label, path))
    return path


def prefix_symlinks(path):
    current = "/"
    links = []
    for component in path.strip("/").split("/")[:-1]:
        current = os.path.join(current, component)
        try:
            info = os.lstat(current)
        except OSError as error:
            raise DiscoveryError("could not inspect path prefix: %s" % current) from error
        if stat.S_ISLNK(info.st_mode):
            links.append(current)
    return links


def path_record(path, label, executable=False):
    selected = validate_logical_path(path, label)
    try:
        selected_info = os.lstat(selected)
        resolved = os.path.realpath(selected)
        resolved_info = os.stat(resolved)
    except OSError as error:
        raise DiscoveryError("could not resolve %s: %s" % (label, selected)) from error
    if not os.path.isabs(resolved) or os.path.normpath(resolved) != resolved:
        fail("%s resolved to a non-canonical path" % label)
    if stat.S_ISREG(resolved_info.st_mode):
        kind = "file"
    elif stat.S_ISDIR(resolved_info.st_mode):
        kind = "directory"
    else:
        fail("%s does not resolve to a regular file or directory" % label)
    if executable and (kind != "file" or not os.access(resolved, os.X_OK)):
        fail("%s is not an executable regular file" % label)
    if resolved_info.st_uid != 0:
        fail("%s does not resolve to a root-owned path" % label)
    if resolved_info.st_mode & 0o022:
        fail("%s resolves to a group- or other-writable path" % label)
    record = {
        "kind": kind,
        "mode": "%04o" % stat.S_IMODE(resolved_info.st_mode),
        "resolved_path": resolved,
        "selected_kind": (
            "symlink" if stat.S_ISLNK(selected_info.st_mode) else kind
        ),
        "selected_path": selected,
    }
    if kind == "file":
        record["bytes"] = resolved_info.st_size
        record["sha256"] = sha256_file(resolved)
    return record


def add_record_paths(record, inventory_paths):
    selected = record["selected_path"]
    inventory_paths.add(selected)
    inventory_paths.update(prefix_symlinks(selected))


def compiler_query(compiler, arguments, environment, label, multiline=False, accepted=(0,)):
    result = run_command([compiler] + list(arguments), environment, accepted=accepted)
    return decode_output(result.stdout, label, multiline=multiline)


def first_version(tool, environment):
    attempts = (["--version"], ["-v"], ["-V"])
    fallback = None
    for arguments in attempts:
        result = run_command([tool] + arguments, environment, accepted=None)
        payload = result.stdout + result.stderr
        if result.returncode == 0 and payload.strip():
            return decode_output(payload, "tool version", multiline=True).splitlines()[:20]
        if fallback is None and payload.strip():
            fallback = [
                "query=%s exit=%d" % (arguments[0], result.returncode)
            ] + decode_output(payload, "tool identity", multiline=True).splitlines()[:19]
    if fallback is not None:
        return fallback
    fail("could not identify build-host tool: %s" % tool)


def script_interpreter(record):
    if record["kind"] != "file":
        return None
    try:
        with open(record["resolved_path"], "rb", buffering=0) as stream:
            first_line = stream.readline(4096)
    except OSError as error:
        raise DiscoveryError("could not inspect build-host tool shebang") from error
    if not first_line.startswith(b"#!"):
        return None
    try:
        words = first_line[2:].decode("utf-8").strip().split()
    except UnicodeError as error:
        raise DiscoveryError("build-host tool shebang is not UTF-8") from error
    if not words or not os.path.isabs(words[0]):
        fail("build-host tool uses a non-absolute shebang interpreter")
    return path_record(
        os.path.normpath(words[0]),
        "build-host tool shebang interpreter",
        executable=True,
    )


def resolve_program(compiler, program_name, environment):
    selected = compiler_query(
        compiler,
        ["-print-prog-name=%s" % program_name],
        environment,
        "compiler program selection",
    )
    if os.path.isabs(selected):
        candidate = os.path.normpath(selected)
    elif "/" in selected:
        candidate = os.path.normpath(os.path.join(os.path.dirname(compiler), selected))
    else:
        candidate = None
        for directory in SAFE_PATH_ENV.split(":"):
            possible = os.path.join(directory, selected)
            if os.path.exists(possible) or os.path.islink(possible):
                candidate = possible
                break
        if candidate is None:
            fail("compiler did not resolve required program: %s" % program_name)
    return path_record(candidate, "compiler-selected %s" % program_name, executable=True)


def runtime_names(platform_name):
    if platform_name == "darwin-arm64":
        return ["libLTO.dylib", "libclang_rt.osx.a"]
    return [
        "crt1.o",
        "Scrt1.o",
        "crti.o",
        "crtn.o",
        "libc.so",
        "libc.so.6",
        "libc_nonshared.a",
        "libm.so",
        "libm.so.6",
        "libpthread.so.0",
        "librt.so.1",
        "libdl.so.2",
        "ld-linux-x86-64.so.2",
        "libgcc.a",
        "libgcc_s.so.1",
        "libstdc++.so",
        "liblto_plugin.so",
    ]


def discover_runtime(compiler, platform_name, environment, inventory_paths):
    selections = []
    for name in runtime_names(platform_name):
        selected = compiler_query(
            compiler,
            ["-print-file-name=%s" % name],
            environment,
            "compiler runtime selection: %s" % name,
        )
        item = {"name": name, "reported": selected}
        if os.path.isabs(selected) and (os.path.exists(selected) or os.path.islink(selected)):
            record = path_record(os.path.normpath(selected), "compiler runtime: %s" % name)
            item["path"] = record
            add_record_paths(record, inventory_paths)
            if name == "libgcc.a":
                parent = path_record(
                    os.path.dirname(record["selected_path"]),
                    "compiler runtime directory",
                )
                item["inventory_directory"] = parent
                add_record_paths(parent, inventory_paths)
        else:
            item["path"] = None
        selections.append(item)
    return selections


def linux_loader_dependencies(tools, environment, inventory_paths):
    dependencies = []
    for label, tool in sorted(tools.items()):
        result = run_command(["/usr/bin/ldd", tool["selected_path"]], environment, accepted=None)
        output = decode_output(
            result.stdout + result.stderr,
            "ldd output for %s" % label,
            multiline=True,
        )
        lowered = output.lower()
        if result.returncode != 0 and not (
            "not a dynamic executable" in lowered or "statically linked" in lowered
        ):
            fail("ldd failed for build-host tool: %s" % label)
        if "not found" in lowered:
            fail("build-host tool has an unresolved dynamic dependency: %s" % label)
        for line in output.splitlines():
            value = line.strip()
            if not value:
                continue
            name = value.split()[0]
            selected = None
            if "=>" in value:
                right = value.split("=>", 1)[1].strip()
                selected = right.split()[0]
            elif value.startswith("/"):
                selected = value.split()[0]
            item = {"library": name, "tool": label}
            if selected and os.path.isabs(selected) and os.path.exists(selected):
                record = path_record(
                    os.path.normpath(selected),
                    "dynamic dependency of %s" % label,
                )
                item["path"] = record
                add_record_paths(record, inventory_paths)
            else:
                item["path"] = None
            dependencies.append(item)
    return sorted(
        dependencies,
        key=lambda item: (
            item["tool"],
            item["library"],
            "" if item["path"] is None else item["path"]["resolved_path"],
        ),
    )


def macos_rpaths(path, environment):
    result = run_command(["/usr/bin/otool", "-l", path], environment)
    output = decode_output(result.stdout, "otool load commands", multiline=True)
    rpaths = []
    awaiting_path = False
    for line in output.splitlines():
        fields = line.strip().split()
        if fields == ["cmd", "LC_RPATH"]:
            awaiting_path = True
        elif awaiting_path and len(fields) >= 2 and fields[0] == "path":
            rpaths.append(fields[1])
            awaiting_path = False
    return sorted(set(rpaths))


def expand_macos_token(value, executable, loader):
    return (
        value.replace("@executable_path", os.path.dirname(executable))
        .replace("@loader_path", os.path.dirname(loader))
    )


def resolve_macos_dependency(load_path, executable, loader, rpaths):
    candidates = []
    if load_path.startswith("/"):
        candidates.append(load_path)
    elif load_path.startswith("@rpath/"):
        suffix = load_path[len("@rpath/") :]
        for rpath in rpaths:
            expanded = expand_macos_token(rpath, executable, loader)
            candidates.append(os.path.join(expanded, suffix))
    elif load_path.startswith(("@loader_path/", "@executable_path/")):
        candidates.append(expand_macos_token(load_path, executable, loader))
    for candidate in candidates:
        normalized = os.path.normpath(candidate)
        if os.path.isabs(normalized) and (
            os.path.exists(normalized) or os.path.islink(normalized)
        ):
            return normalized
    return None


def macos_declared_dependencies(tools, environment, inventory_paths):
    dependencies = []
    pending = [
        (label, record["resolved_path"], record["resolved_path"])
        for label, record in sorted(tools.items())
    ]
    seen = set()
    while pending:
        root_label, executable, loader = pending.pop(0)
        identity = os.path.realpath(loader)
        if identity in seen:
            continue
        seen.add(identity)
        if len(seen) > MAX_LOADER_FILES:
            fail("Mach-O loader closure exceeds %d files" % MAX_LOADER_FILES)
        result = run_command(["/usr/bin/otool", "-L", loader], environment)
        output = decode_output(result.stdout, "otool dependencies", multiline=True)
        rpaths = macos_rpaths(loader, environment)
        for line in output.splitlines():
            if not line[:1].isspace():
                continue
            load_path = line.strip().split(" (", 1)[0]
            if not load_path:
                continue
            selected = resolve_macos_dependency(
                load_path,
                executable,
                loader,
                rpaths,
            )
            item = {
                "declared": load_path,
                "loader": loader,
                "root_tool": root_label,
            }
            if selected is not None:
                record = path_record(
                    selected,
                    "Mach-O dependency of %s" % root_label,
                )
                item["path"] = record
                add_record_paths(record, inventory_paths)
                pending.append((root_label, executable, record["resolved_path"]))
            else:
                item["path"] = None
            dependencies.append(item)
    return sorted(
        dependencies,
        key=lambda item: (item["root_tool"], item["loader"], item["declared"]),
    )


def macos_loaded_images(tools, environment, inventory_paths):
    invocations = {
        "archiver": ["-V"],
        "assembler": ["--version"],
        "compiler": ["--version"],
        "linker": ["-v"],
    }
    images = []
    trace_environment = dict(environment)
    trace_environment["DYLD_PRINT_LIBRARIES"] = "1"
    for label, record in sorted(tools.items()):
        result = run_command(
            [record["selected_path"]] + invocations[label],
            trace_environment,
            accepted=None,
        )
        payload = decode_output(
            result.stdout + result.stderr,
            "dyld image trace for %s" % label,
            multiline=True,
        )
        observed = 0
        for line in payload.splitlines():
            match = DYLD_IMAGE.search(line)
            if match is None:
                continue
            observed += 1
            uuid = match.group(1).upper()
            load_path = match.group(2)
            item = {"path": load_path, "tool": label, "uuid": uuid}
            if os.path.exists(load_path) or os.path.islink(load_path):
                record_path = path_record(load_path, "loaded image of %s" % label)
                item["file"] = record_path
                add_record_paths(record_path, inventory_paths)
            else:
                item["file"] = None
            images.append(item)
        if observed == 0:
            interpreter = script_interpreter(record)
            if interpreter is None:
                fail("DYLD_PRINT_LIBRARIES produced no image identities for %s" % label)
            add_record_paths(interpreter, inventory_paths)
            images.append(
                {
                    "file": interpreter,
                    "path": interpreter["selected_path"],
                    "tool": label,
                    "uuid": None,
                }
            )
    return sorted(
        images,
        key=lambda item: (item["tool"], item["path"], item["uuid"] or ""),
    )


def discover(platform_name, compiler_path, archiver_path, sdkroot_path):
    if platform_name not in ("darwin-arm64", "linux-x86_64"):
        fail("unsupported build platform")
    if platform_name == "darwin-arm64" and not sdkroot_path:
        fail("macOS discovery requires an explicit SDK root")
    if platform_name == "linux-x86_64" and sdkroot_path:
        fail("Linux discovery does not accept an ambient SDK root")

    environment = clean_environment(sdkroot_path)
    inventory_paths = set()
    compiler = path_record(compiler_path, "native C compiler", executable=True)
    archiver = path_record(archiver_path, "native archive tool", executable=True)
    add_record_paths(compiler, inventory_paths)
    add_record_paths(archiver, inventory_paths)
    linker = resolve_program(compiler_path, "ld", environment)
    assembler = resolve_program(compiler_path, "as", environment)
    add_record_paths(linker, inventory_paths)
    add_record_paths(assembler, inventory_paths)
    tools = {
        "compiler": compiler,
        "archiver": archiver,
        "linker": linker,
        "assembler": assembler,
    }
    loader_files = dict(tools)
    for label, record in sorted(tools.items()):
        interpreter = script_interpreter(record)
        if interpreter is not None:
            loader_files[label + "-interpreter"] = interpreter
            add_record_paths(interpreter, inventory_paths)

    target = compiler_query(
        compiler_path,
        ["-dumpmachine"],
        environment,
        "compiler target",
    )
    resource_result = run_command(
        [compiler_path, "-print-resource-dir"],
        environment,
        accepted=None,
    )
    if resource_result.returncode == 0 and resource_result.stdout.strip():
        resource_path = decode_output(resource_result.stdout, "compiler resource directory")
    else:
        resource_path = compiler_query(
            compiler_path,
            ["-print-file-name=include"],
            environment,
            "compiler include directory",
        )
    resource = path_record(
        os.path.normpath(resource_path),
        "compiler resource directory",
    )
    if resource["kind"] != "directory":
        fail("compiler resource selection is not a directory")
    add_record_paths(resource, inventory_paths)
    search_directories = compiler_query(
        compiler_path,
        ["-print-search-dirs"],
        environment,
        "compiler search directories",
        multiline=True,
    ).splitlines()
    runtime = discover_runtime(
        compiler_path,
        platform_name,
        environment,
        inventory_paths,
    )

    if sdkroot_path:
        sdk = path_record(sdkroot_path, "selected SDK root")
        if sdk["kind"] != "directory":
            fail("selected SDK root is not a directory")
        add_record_paths(sdk, inventory_paths)
        reported_sysroot = sdkroot_path
    else:
        sysroot_result = run_command(
            [compiler_path, "-print-sysroot"],
            environment,
            accepted=None,
        )
        if sysroot_result.returncode == 0 and sysroot_result.stdout.strip():
            reported_sysroot = decode_output(sysroot_result.stdout, "compiler sysroot")
        else:
            reported_sysroot = "/"
        sdk = {
            "kind": "directory",
            "mode": "0755",
            "resolved_path": "/",
            "selected_kind": "directory",
            "selected_path": "/",
        }

    if platform_name == "darwin-arm64":
        loader = {
            "declared_dependencies": macos_declared_dependencies(
                loader_files, environment, inventory_paths
            ),
            "loaded_images": macos_loaded_images(tools, environment, inventory_paths),
            "strategy": "mach-o-and-dyld-images",
        }
    else:
        loader = {
            "dependencies": linux_loader_dependencies(
                tools, environment, inventory_paths
            ),
            "strategy": "ldd",
        }

    return {
        "compiler_queries": {
            "reported_sysroot": reported_sysroot,
            "resource_directory": resource,
            "runtime_files": runtime,
            "search_directories": search_directories,
            "target": target,
        },
        "environment": {
            "lang": "C",
            "lc_all": "C",
            "path": SAFE_PATH_ENV,
            "sdkroot": sdkroot_path or None,
        },
        "inventory_paths": sorted(inventory_paths),
        "loader": loader,
        "platform": platform_name,
        "schema": "office.fresh-agent.build-host-discovery/1",
        "sdk": sdk,
        "tools": {
            label: dict(record, version=first_version(record["selected_path"], environment))
            for label, record in sorted(tools.items())
        },
    }


def atomic_write(path, payload):
    parent = os.path.dirname(os.path.abspath(path))
    if os.path.exists(path) or os.path.islink(path):
        fail("discovery output already exists: %s" % path)
    descriptor, temporary = tempfile.mkstemp(prefix=".build-host-discovery.", dir=parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "wb", buffering=0) as stream:
            stream.write(payload)
        os.link(temporary, path, follow_symlinks=False)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def main(argv):
    if len(argv) != 7:
        print(
            "usage: build_host_discovery.py PLATFORM CC AR SDKROOT_OR_DASH OUTPUT_JSON OUTPUT_PATHS",
            file=sys.stderr,
        )
        return 2
    sdkroot = "" if argv[4] == "-" else argv[4]
    try:
        result = discover(argv[1], argv[2], argv[3], sdkroot)
        json_payload = (json.dumps(result, indent=2, sort_keys=True) + "\n").encode()
        paths_payload = ("\n".join(result["inventory_paths"]) + "\n").encode()
        atomic_write(argv[5], json_payload)
        atomic_write(argv[6], paths_payload)
    except (DiscoveryError, OSError, ValueError) as error:
        print("build-host discovery failed: %s" % error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
