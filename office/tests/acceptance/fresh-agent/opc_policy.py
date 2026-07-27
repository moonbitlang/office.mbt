#!/usr/bin/env python3
"""Validate a bounded XLSX or DOCX OPC package without extracting it."""

import os
import posixpath
import resource
import signal
import stat
import sys
import urllib.parse
import zipfile
import xml.etree.ElementTree as ET


MAX_ARCHIVE_BYTES = 128 * 1024 * 1024
MAX_ENTRY_BYTES = 64 * 1024 * 1024
MAX_EXPANDED_BYTES = 128 * 1024 * 1024
MAX_ENTRIES = 2048
MAX_XML_BYTES = 8 * 1024 * 1024
MAX_XML_DEPTH = 256
MAX_ADDRESS_SPACE_BYTES = 256 * 1024 * 1024
CHUNK_BYTES = 1024 * 1024
SUPPORTED_COMPRESSION = frozenset({zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED})
FORBIDDEN_XML_TOKENS = tuple(
    token.encode(encoding)
    for token in ("<!DOCTYPE", "<!ENTITY")
    for encoding in ("ascii", "utf-16le", "utf-16be", "utf-32le", "utf-32be")
)
FORBIDDEN_XML_TAIL_BYTES = max(len(token) for token in FORBIDDEN_XML_TOKENS) - 1

CONTENT_TYPES_NS = "http://schemas.openxmlformats.org/package/2006/content-types"
RELATIONSHIPS_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
RELATIONSHIPS_CONTENT_TYPE = (
    "application/vnd.openxmlformats-package.relationships+xml"
)
OFFICE_DOCUMENT_REL = (
    "http://schemas.openxmlformats.org/officeDocument/2006/"
    "relationships/officeDocument"
)
URI_UNRESERVED = frozenset(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
)


class ValidationError(Exception):
    pass


def fail(message):
    raise ValidationError(message)


def reject_timeout(_signum, _frame):
    fail("archive validation exceeded its deadline")


def qname(namespace, local_name):
    return "{%s}%s" % (namespace, local_name)


def has_unsafe_text(value):
    return not value or any(ord(character) < 32 or ord(character) == 127 for character in value)


def decode_uri_path(value, label):
    if has_unsafe_text(value) or "\\" in value or ":" in value:
        fail("unsafe %s" % label)
    index = 0
    while index < len(value):
        if value[index] == "%":
            if index + 2 >= len(value) or any(
                character not in "0123456789abcdefABCDEF"
                for character in value[index + 1 : index + 3]
            ):
                fail("invalid percent escape in %s" % label)
            encoded = value[index + 1 : index + 3]
            if encoded != encoded.upper():
                fail("non-canonical percent escape in %s" % label)
            decoded_octet = chr(int(encoded, 16))
            if decoded_octet in URI_UNRESERVED or decoded_octet in "/\\":
                fail("non-canonical percent escape in %s" % label)
            index += 3
        else:
            index += 1
    try:
        decoded = urllib.parse.unquote_to_bytes(value).decode("utf-8")
    except UnicodeError as error:
        raise ValidationError("non-UTF-8 percent escape in %s" % label) from error
    if has_unsafe_text(decoded) or "\\" in decoded or ":" in decoded:
        fail("unsafe decoded %s" % label)
    return decoded


def validate_part_path(value, label, allow_trailing_slash=False):
    decoded = decode_uri_path(value, label)
    if (
        value.startswith("/")
        or "//" in value
        or decoded.startswith("/")
        or "//" in decoded
    ):
        fail("non-canonical %s" % label)
    if allow_trailing_slash and value.endswith("/"):
        value = value[:-1]
        decoded = decoded[:-1]
    elif value.endswith("/") or decoded.endswith("/"):
        fail("non-canonical %s" % label)
    components = value.split("/")
    decoded_components = decoded.split("/")
    if (
        not components
        or any(component in ("", ".", "..") for component in components)
        or any(component in ("", ".", "..") for component in decoded_components)
    ):
        fail("non-canonical %s" % label)
    return value


def require_whitespace(value, label):
    if value is not None and value.strip():
        fail("unexpected text in %s" % label)


def require_attributes(attributes, required, optional, label):
    keys = set(attributes)
    if not required.issubset(keys) or not keys.issubset(required | optional):
        fail("invalid attributes on %s" % label)
    for key in required:
        if has_unsafe_text(attributes[key]):
            fail("empty or unsafe %s attribute" % label)


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


def inspect_entries(archive):
    entries = archive.infolist()
    if not 1 <= len(entries) <= MAX_ENTRIES:
        fail("ZIP entry count is outside 1..%d" % MAX_ENTRIES)
    by_logical_name = {}
    folded_names = set()
    file_names = set()
    directory_names = set()
    declared_expanded = 0
    for info in entries:
        if info.orig_filename != info.filename or "\x00" in info.orig_filename:
            fail("ZIP entry name contains a raw NUL or was truncated")
        is_directory = info.is_dir()
        logical_name = validate_part_path(
            info.filename,
            "ZIP entry name",
            allow_trailing_slash=is_directory,
        )
        folded = logical_name.casefold()
        if folded in folded_names:
            fail("case-colliding or URI-colliding ZIP entry name")
        folded_names.add(folded)
        unix_mode = (info.external_attr >> 16) & 0xFFFF
        entry_kind = stat.S_IFMT(unix_mode)
        if entry_kind not in (0, stat.S_IFREG, stat.S_IFDIR):
            fail("ZIP contains a non-file entry")
        if info.flag_bits & (0x1 | 0x40):
            fail("encrypted ZIP entries are not accepted")
        if info.compress_type not in SUPPORTED_COMPRESSION:
            fail("ZIP entry uses an unsupported compression method")
        if info.file_size < 0 or info.compress_size < 0:
            fail("ZIP entry reports a negative size")
        if is_directory:
            if entry_kind not in (0, stat.S_IFDIR) or info.file_size != 0:
                fail("invalid ZIP directory entry")
            directory_names.add(logical_name)
        else:
            if entry_kind == stat.S_IFDIR:
                fail("ambiguous ZIP file entry")
            if info.file_size > MAX_ENTRY_BYTES:
                fail("ZIP entry expands beyond 64 MiB")
            declared_expanded += info.file_size
            if declared_expanded > MAX_EXPANDED_BYTES:
                fail("ZIP expands beyond 128 MiB")
            file_names.add(logical_name)
        by_logical_name[logical_name] = info
    for file_name in file_names:
        components = file_name.split("/")
        for index in range(1, len(components)):
            parent = "/".join(components[:index])
            if parent in file_names:
                fail("ZIP file entry is also used as a parent directory")
    if file_names & directory_names:
        fail("ZIP path is both a file and a directory")
    return by_logical_name, file_names


def read_entry(archive, info, part_name, expanded_state):
    actual_size = 0
    try:
        with archive.open(info, "r") as source:
            while True:
                chunk = source.read(CHUNK_BYTES)
                if not chunk:
                    break
                actual_size += len(chunk)
                expanded_state[0] += len(chunk)
                if actual_size > MAX_ENTRY_BYTES:
                    fail("ZIP entry expands beyond 64 MiB")
                if expanded_state[0] > MAX_EXPANDED_BYTES:
                    fail("ZIP expands beyond 128 MiB")
    except (RuntimeError, zipfile.BadZipFile) as error:
        raise ValidationError("unreadable or corrupt ZIP entry: %s" % part_name) from error
    if actual_size != info.file_size:
        fail("ZIP entry size disagrees with its payload")


def scan_xml_chunk(chunk, tail, part_name):
    window = tail + chunk.upper()
    if any(token in window for token in FORBIDDEN_XML_TOKENS):
        fail("DTD or entity declaration in OPC XML: %s" % part_name)
    return window[-FORBIDDEN_XML_TAIL_BYTES:]


def stream_xml_entry(archive, info, part_name, target, expanded_state):
    if info.file_size > MAX_XML_BYTES:
        fail("OPC XML part exceeds 8 MiB: %s" % part_name)
    actual_size = 0
    forbidden_tail = b""
    parser = ET.XMLParser(target=target)
    try:
        with archive.open(info, "r") as source:
            while True:
                chunk = source.read(CHUNK_BYTES)
                if not chunk:
                    break
                actual_size += len(chunk)
                expanded_state[0] += len(chunk)
                if actual_size > MAX_XML_BYTES:
                    fail("OPC XML part exceeds 8 MiB: %s" % part_name)
                if expanded_state[0] > MAX_EXPANDED_BYTES:
                    fail("ZIP expands beyond 128 MiB")
                forbidden_tail = scan_xml_chunk(chunk, forbidden_tail, part_name)
                parser.feed(chunk)
        if actual_size != info.file_size:
            fail("ZIP entry size disagrees with its payload")
        if actual_size == 0:
            fail("empty OPC XML part: %s" % part_name)
        return parser.close()
    except (ET.ParseError, ValueError) as error:
        raise ValidationError("malformed OPC XML: %s" % part_name) from error
    except (RuntimeError, zipfile.BadZipFile) as error:
        raise ValidationError("unreadable or corrupt ZIP entry: %s" % part_name) from error


def finalize_content_types(defaults, overrides, file_names):
    if defaults.get("rels") != RELATIONSHIPS_CONTENT_TYPE:
        fail("OPC content types omit the relationships declaration")
    content_types = {}
    for part_name in file_names:
        if part_name == "[Content_Types].xml":
            continue
        override = overrides.get(part_name.casefold())
        if override is not None:
            if override[0] != part_name:
                fail("OPC override casing disagrees with its ZIP part")
            content_type = override[1]
        else:
            leaf = part_name.rsplit("/", 1)[-1]
            extension = leaf.rsplit(".", 1)[1].casefold() if "." in leaf else ""
            content_type = defaults.get(extension)
        if has_unsafe_text(content_type):
            fail("OPC part has no complete content-type declaration: %s" % part_name)
        if (
            part_name.casefold().endswith(".rels")
            and content_type != RELATIONSHIPS_CONTENT_TYPE
        ):
            fail(
                "OPC relationships part has the wrong effective content type: %s"
                % part_name
            )
        content_types[part_name] = content_type
    return content_types


class ContentTypesTarget:
    def __init__(self, file_names):
        self.file_names = file_names
        self.depth = 0
        self.root_seen = False
        self.defaults = {}
        self.overrides = {}

    def start(self, tag, attributes):
        self.depth += 1
        if self.depth == 1:
            if (
                self.root_seen
                or tag != qname(CONTENT_TYPES_NS, "Types")
                or attributes
            ):
                fail("unexpected OPC content-types root")
            self.root_seen = True
            return
        if self.depth != 2:
            fail("invalid OPC content-types child structure")
        if tag == qname(CONTENT_TYPES_NS, "Default"):
            require_attributes(
                attributes,
                {"Extension", "ContentType"},
                set(),
                "Default",
            )
            extension = attributes["Extension"]
            if extension.startswith(".") or "/" in extension or "\\" in extension:
                fail("invalid OPC default extension")
            folded = extension.casefold()
            if folded in self.defaults:
                fail("duplicate OPC default extension")
            self.defaults[folded] = attributes["ContentType"]
        elif tag == qname(CONTENT_TYPES_NS, "Override"):
            require_attributes(
                attributes,
                {"PartName", "ContentType"},
                set(),
                "Override",
            )
            part_name = attributes["PartName"]
            if not part_name.startswith("/") or part_name.startswith("//"):
                fail("invalid OPC override PartName")
            logical_name = validate_part_path(part_name[1:], "OPC override PartName")
            folded = logical_name.casefold()
            if folded in self.overrides:
                fail("duplicate OPC content-type override")
            if (
                logical_name not in self.file_names
                or logical_name == "[Content_Types].xml"
            ):
                fail("OPC override names a missing or reserved part")
            self.overrides[folded] = (logical_name, attributes["ContentType"])
        else:
            fail("invalid OPC content-types child structure")

    def end(self, _tag):
        self.depth -= 1

    def data(self, value):
        require_whitespace(value, "OPC content-types structure")

    def close(self):
        if not self.root_seen or self.depth != 0:
            fail("invalid OPC content-types structure")
        return finalize_content_types(self.defaults, self.overrides, self.file_names)


def relationship_source(part_name):
    if part_name == "_rels/.rels":
        return None
    directory, leaf = posixpath.split(part_name)
    if not leaf.endswith(".rels") or posixpath.basename(directory) != "_rels":
        fail("relationships part is not in a canonical _rels location")
    source_directory = posixpath.dirname(directory)
    source_leaf = leaf[: -len(".rels")]
    if not source_leaf:
        fail("relationships part has no source part")
    return posixpath.join(source_directory, source_leaf) if source_directory else source_leaf


def resolve_internal_target(source_part, target):
    parsed = urllib.parse.urlsplit(target)
    if parsed.scheme or parsed.netloc or parsed.query or parsed.fragment:
        fail("internal OPC relationship target is not a plain part path")
    decode_uri_path(parsed.path, "OPC relationship target")
    if parsed.path.startswith("/"):
        candidate = parsed.path[1:]
    else:
        base = posixpath.dirname(source_part) if source_part is not None else ""
        candidate = posixpath.join(base, parsed.path)
    normalized = posixpath.normpath(candidate)
    if normalized in ("", ".", "..") or normalized.startswith("../"):
        fail("OPC relationship target escapes the package")
    return validate_part_path(normalized, "resolved OPC relationship target")


class RelationshipsTarget:
    def __init__(self, part_name, source_part, file_names):
        self.part_name = part_name
        self.source_part = source_part
        self.file_names = file_names
        self.depth = 0
        self.root_seen = False
        self.identifiers = set()
        self.office_targets = []

    def start(self, tag, attributes):
        self.depth += 1
        if self.depth == 1:
            if (
                self.root_seen
                or tag != qname(RELATIONSHIPS_NS, "Relationships")
                or attributes
            ):
                fail("unexpected OPC relationships root: %s" % self.part_name)
            self.root_seen = True
            return
        if self.depth != 2 or tag != qname(RELATIONSHIPS_NS, "Relationship"):
            fail("invalid OPC relationship child structure")
        require_attributes(
            attributes,
            {"Id", "Type", "Target"},
            {"TargetMode"},
            "Relationship",
        )
        identifier = attributes["Id"]
        if identifier in self.identifiers:
            fail("duplicate OPC relationship Id")
        self.identifiers.add(identifier)
        target_mode = attributes.get("TargetMode", "Internal")
        if target_mode not in ("Internal", "External"):
            fail("invalid OPC relationship TargetMode")
        relationship_type = attributes["Type"]
        target = attributes["Target"]
        if target_mode == "Internal":
            resolved = resolve_internal_target(self.source_part, target)
            if resolved not in self.file_names:
                fail("OPC relationship targets a missing part: %s" % resolved)
        else:
            if has_unsafe_text(target):
                fail("empty or unsafe external OPC relationship target")
            resolved = None
        if relationship_type == OFFICE_DOCUMENT_REL:
            if self.source_part is not None or target_mode != "Internal":
                fail("officeDocument relationship must be internal and package-rooted")
            self.office_targets.append(resolved)

    def end(self, _tag):
        self.depth -= 1

    def data(self, value):
        require_whitespace(value, "OPC relationships structure")

    def close(self):
        if not self.root_seen or self.depth != 0:
            fail("invalid OPC relationships structure: %s" % self.part_name)
        return self.office_targets


class RootNameTarget:
    def __init__(self, part_name):
        self.part_name = part_name
        self.depth = 0
        self.root_name = None

    def start(self, tag, _attributes):
        self.depth += 1
        if self.depth > MAX_XML_DEPTH:
            fail(
                "OPC XML nesting exceeds %d levels: %s"
                % (MAX_XML_DEPTH, self.part_name)
            )
        if self.depth == 1:
            if self.root_name is not None:
                fail("multiple OPC XML roots: %s" % self.part_name)
            self.root_name = tag

    def end(self, _tag):
        self.depth -= 1

    def data(self, _value):
        pass

    def close(self):
        if self.root_name is None or self.depth != 0:
            fail("invalid OPC XML structure: %s" % self.part_name)
        return self.root_name


def is_xml_part(part_name, content_type):
    lowered_name = part_name.casefold()
    lowered_type = content_type.casefold()
    return (
        lowered_name.endswith(".xml")
        or lowered_name.endswith(".rels")
        or lowered_type.endswith("+xml")
        or lowered_type in {"application/xml", "text/xml"}
    )


def package_contract(package_format):
    if package_format == "xlsx":
        return (
            "xl/workbook.xml",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml",
            qname("http://schemas.openxmlformats.org/spreadsheetml/2006/main", "workbook"),
        )
    if package_format == "docx":
        return (
            "word/document.xml",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
            qname("http://schemas.openxmlformats.org/wordprocessingml/2006/main", "document"),
        )
    fail("unsupported OPC format")


def validate_opc(package_path, package_format):
    main_part, main_content_type, main_qname = package_contract(package_format)
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(package_path, flags)
    with os.fdopen(descriptor, "rb", buffering=0) as package_stream:
        before = os.fstat(package_stream.fileno())
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_uid != os.geteuid()
            or before.st_nlink != 1
            or before.st_size <= 0
            or before.st_size > MAX_ARCHIVE_BYTES
        ):
            fail("package is not a bounded, owned, single-link regular file")
        try:
            with zipfile.ZipFile(package_stream, "r") as archive:
                entries, file_names = inspect_entries(archive)
                required = {"[Content_Types].xml", "_rels/.rels", main_part}
                missing = sorted(required - file_names)
                if missing:
                    fail("missing required OPC part: %s" % missing[0])

                expanded = [0]
                content_types = stream_xml_entry(
                    archive,
                    entries["[Content_Types].xml"],
                    "[Content_Types].xml",
                    ContentTypesTarget(file_names),
                    expanded,
                )
                if content_types.get(main_part) != main_content_type:
                    fail("main OPC part has the wrong content type")

                office_targets = []
                main_root = None
                for part_name, info in entries.items():
                    if info.is_dir() or part_name == "[Content_Types].xml":
                        continue
                    content_type = content_types[part_name]
                    if part_name.casefold().endswith(".rels"):
                        source_part = relationship_source(part_name)
                        if source_part is not None and source_part not in file_names:
                            fail("relationships part refers to a missing source part")
                        office_targets.extend(
                            stream_xml_entry(
                                archive,
                                info,
                                part_name,
                                RelationshipsTarget(
                                    part_name,
                                    source_part,
                                    file_names,
                                ),
                                expanded,
                            )
                        )
                    elif is_xml_part(part_name, content_type):
                        root_name = stream_xml_entry(
                            archive,
                            info,
                            part_name,
                            RootNameTarget(part_name),
                            expanded,
                        )
                        if part_name == main_part:
                            main_root = root_name
                    else:
                        read_entry(archive, info, part_name, expanded)
                if expanded[0] < 1:
                    fail("ZIP package expands to no file content")
                if office_targets != [main_part]:
                    fail("expected exactly one root officeDocument relationship to the main part")
                if main_root != main_qname:
                    fail("unexpected OPC main-part root")
        except (OSError, RuntimeError, zipfile.BadZipFile, zipfile.LargeZipFile) as error:
            raise ValidationError("unreadable or corrupt ZIP package") from error
        after = os.fstat(package_stream.fileno())
        if file_identity(before) != file_identity(after):
            fail("package changed while it was validated")


def apply_resource_limits(timeout_seconds):
    signal.signal(signal.SIGALRM, reject_timeout)
    signal.signal(signal.SIGXCPU, reject_timeout)
    signal.alarm(timeout_seconds)
    cpu_soft, cpu_hard = resource.getrlimit(resource.RLIMIT_CPU)
    desired_cpu = (
        timeout_seconds
        if cpu_soft == resource.RLIM_INFINITY
        else min(cpu_soft, timeout_seconds)
    )
    resource.setrlimit(resource.RLIMIT_CPU, (desired_cpu, cpu_hard))
    if sys.platform.startswith("linux"):
        address_soft, address_hard = resource.getrlimit(resource.RLIMIT_AS)
        desired_address = (
            MAX_ADDRESS_SPACE_BYTES
            if address_soft == resource.RLIM_INFINITY
            else min(address_soft, MAX_ADDRESS_SPACE_BYTES)
        )
        resource.setrlimit(resource.RLIMIT_AS, (desired_address, address_hard))


def main(argv):
    if len(argv) != 4:
        print("usage: opc_policy.py PACKAGE FORMAT TIMEOUT_SECONDS", file=sys.stderr)
        return 2
    try:
        timeout_seconds = int(argv[3], 10)
    except ValueError:
        timeout_seconds = 0
    if not 1 <= timeout_seconds <= 30:
        print("OPC validation failed: timeout must be in 1..30 seconds", file=sys.stderr)
        return 2
    try:
        apply_resource_limits(timeout_seconds)
        validate_opc(argv[1], argv[2])
    except (ValidationError, OSError, MemoryError, ValueError) as error:
        print("OPC validation failed: %s" % error, file=sys.stderr)
        return 1
    finally:
        signal.alarm(0)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
