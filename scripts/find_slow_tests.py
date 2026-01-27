#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import statistics
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple


@dataclass(frozen=True)
class TestCase:
    package: str  # "." for root package, otherwise package dir (e.g. "xlsx")
    suite: str  # blackbox | whitebox | internal
    filename: str  # e.g. "calc_test.mbt"
    index: int
    name: str
    line_number: Optional[int]
    attrs: Tuple[str, ...]
    kinds: Tuple[str, ...]  # which sections it appeared in (tests/async_tests/...)


@dataclass
class TestResult:
    case: TestCase
    seconds: float
    status: str  # ok | failed | timeout
    exit_code: Optional[int] = None


SECTIONS = (
    "tests",
    "no_args_tests",
    "with_args_tests",
    "with_bench_args_tests",
    "async_tests",
    "async_tests_with_args",
)


def run(cmd: List[str], cwd: Path, timeout_s: Optional[float]) -> Tuple[int, float, bool]:
    start = time.perf_counter()
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=timeout_s,
        )
        end = time.perf_counter()
        return proc.returncode, end - start, False
    except subprocess.TimeoutExpired:
        end = time.perf_counter()
        return 124, end - start, True


def build_drivers(repo: Path) -> None:
    # Keep it minimal: build only so we get the generated test metadata and rspfiles.
    subprocess.run(
        ["moon", "test", "--build-only"],
        cwd=str(repo),
        check=True,
    )


def find_blackbox_infos(test_root: Path) -> List[Path]:
    out: List[Path] = []
    for name in ("__blackbox_test_info.json", "__whitebox_test_info.json", "__internal_test_info.json"):
        out.extend(test_root.rglob(name))
    out.sort()
    return out


def package_from_info_path(test_root: Path, info_path: Path) -> str:
    rel = info_path.relative_to(test_root)
    if len(rel.parts) == 1 and rel.parts[0].endswith("_test_info.json"):
        return "."
    # <pkg>/__blackbox_test_info.json
    return rel.parts[0]


def suite_from_info_path(info_path: Path) -> str:
    name = info_path.name
    if name == "__blackbox_test_info.json":
        return "blackbox"
    if name == "__whitebox_test_info.json":
        return "whitebox"
    if name == "__internal_test_info.json":
        return "internal"
    raise ValueError(f"unrecognized test info file: {name}")


def rspfile_for_package(test_root: Path, package: str, suite: str) -> Path:
    if package == ".":
        # Root package is named after module: mbtexcel.* in this repo
        candidates = list(test_root.glob(f"*.{suite}_test.rspfile"))
    else:
        candidates = list((test_root / package).glob(f"*.{suite}_test.rspfile"))
    if not candidates:
        raise FileNotFoundError(f"no .{suite}_test.rspfile found for package {package!r}")
    if len(candidates) > 1:
        # Prefer the one that matches dir name when possible.
        for c in candidates:
            if package != "." and c.name.startswith(package + "."):
                return c
    return candidates[0]


def load_cases_for_info(info_path: Path, package: str) -> List[TestCase]:
    suite = suite_from_info_path(info_path)
    j = json.loads(info_path.read_text())
    by_key: Dict[Tuple[str, int], Dict[str, Any]] = {}
    kinds_by_key: Dict[Tuple[str, int], List[str]] = {}
    for section in SECTIONS:
        section_obj = j.get(section)
        if not isinstance(section_obj, dict):
            continue
        for filename, entries in section_obj.items():
            if not isinstance(entries, list):
                continue
            for entry in entries:
                if not isinstance(entry, dict):
                    continue
                if "index" not in entry or "name" not in entry:
                    continue
                idx = int(entry["index"])
                key = (filename, idx)
                if key not in by_key:
                    by_key[key] = entry
                kinds_by_key.setdefault(key, []).append(section)

    out: List[TestCase] = []
    for (filename, idx), entry in sorted(by_key.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        attrs = tuple(entry.get("attrs") or [])
        line_number = entry.get("line_number")
        out.append(
            TestCase(
                package=package,
                suite=suite,
                filename=filename,
                index=idx,
                name=str(entry.get("name", "")),
                line_number=int(line_number) if isinstance(line_number, int) else None,
                attrs=attrs,
                kinds=tuple(sorted(set(kinds_by_key.get((filename, idx), [])))),
            )
        )
    return out


def percentile(sorted_values: List[float], p: float) -> float:
    if not sorted_values:
        return 0.0
    if p <= 0:
        return sorted_values[0]
    if p >= 1:
        return sorted_values[-1]
    k = (len(sorted_values) - 1) * p
    f = int(k)
    c = min(f + 1, len(sorted_values) - 1)
    if f == c:
        return sorted_values[f]
    d0 = sorted_values[f] * (c - k)
    d1 = sorted_values[c] * (k - f)
    return d0 + d1


def write_markdown_report(
    out_path: Path,
    results: List[TestResult],
    timeout_s: float,
    build_dir: Path,
) -> None:
    ok = [r for r in results if r.status == "ok"]
    timeouts = [r for r in results if r.status == "timeout"]
    failed = [r for r in results if r.status == "failed"]

    ok_times = sorted(r.seconds for r in ok)
    p50 = statistics.median(ok_times) if ok_times else 0.0
    p95 = percentile(ok_times, 0.95) if ok_times else 0.0
    p99 = percentile(ok_times, 0.99) if ok_times else 0.0
    slow_threshold = max(p95, 3.0)
    very_slow_threshold = max(p99, 5.0)

    slow_p95 = [r for r in ok if r.seconds >= slow_threshold]
    slow_p95.sort(key=lambda r: r.seconds, reverse=True)
    slow_p99 = [r for r in ok if r.seconds >= very_slow_threshold]
    slow_p99.sort(key=lambda r: r.seconds, reverse=True)
    top_ok = sorted(ok, key=lambda r: r.seconds, reverse=True)[:30]

    lines: List[str] = []
    lines.append("# Slow tests report")
    lines.append("")
    lines.append(f"- Generated at: `{time.strftime('%Y-%m-%d %H:%M:%S %z')}`")
    lines.append(f"- Build metadata: `{build_dir}`")
    lines.append(f"- Per-test timeout: `{timeout_s:.1f}s`")
    lines.append(f"- p50/p95/p99 computed from OK tests (including `#skip` tests).")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- Total tests measured: `{len(results)}`")
    lines.append(f"- OK: `{len(ok)}`; failed: `{len(failed)}`; timed out: `{len(timeouts)}`")
    lines.append(f"- p50: `{p50:.3f}s`, p95: `{p95:.3f}s`, p99: `{p99:.3f}s` (OK tests only)")
    lines.append(f"- Suggested slow thresholds: `p95={p95:.3f}s` and `p99={p99:.3f}s`")
    lines.append("")
    lines.append("## Method")
    lines.append("")
    lines.append("1. Build only to generate native test drivers and metadata:")
    lines.append("   - `moon test --build-only`")
    lines.append("2. Enumerate tests from `__{blackbox,whitebox,internal}_test_info.json` under `_build/native/debug/test/**`.")
    lines.append("3. Run each test in isolation via the generated native driver (faster + avoids `moon test` orchestration):")
    lines.append("   - `tcc @<pkg>.<suite>_test.rspfile <file>.mbt:<index>-<index+1>`")
    lines.append("4. Measure wall-clock time per test; classify as timeout if exceeding the per-test timeout.")
    lines.append("")
    lines.append("## Results")
    lines.append("")
    lines.append("This report highlights timeouts, the slowest tests, and percentile-based outliers.")
    lines.append("")

    def fmt_case(r: TestResult) -> str:
        c = r.case
        loc = f"{c.filename}:{c.line_number}" if c.line_number else c.filename
        pkg = c.package
        attrs = f" attrs={list(c.attrs)}" if c.attrs else ""
        return f"- `{r.seconds:.3f}s` `{pkg}` `{c.suite}` `{loc}` `#{c.index}` {c.name}{attrs}"

    if timeouts:
        lines.append("### Timeouts (likely non-terminating / extremely slow)")
        lines.append("")
        for r in sorted(timeouts, key=lambda r: (r.case.package, r.case.suite, r.case.filename, r.case.index)):
            c = r.case
            loc = f"{c.filename}:{c.line_number}" if c.line_number else c.filename
            attrs = f" attrs={list(c.attrs)}" if c.attrs else ""
            lines.append(
                f"- `TIMEOUT>{timeout_s:.1f}s` `{c.package}` `{c.suite}` `{loc}` `#{c.index}` {c.name}{attrs}"
            )
        lines.append("")

    if slow_p99:
        lines.append(f"### Very slow (OK) tests (>= max(p99, 5s) = `{very_slow_threshold:.3f}s`)")
        lines.append("")
        for r in slow_p99:
            lines.append(fmt_case(r))
        lines.append("")
    else:
        lines.append(f"_No OK tests exceeded `max(p99, 5s)` (`{very_slow_threshold:.3f}s`)._")
        lines.append("")

    if slow_p95:
        lines.append(f"### Slow (OK) tests (>= max(p95, 3s) = `{slow_threshold:.3f}s`)")
        lines.append("")
        for r in slow_p95:
            lines.append(fmt_case(r))
        lines.append("")

    lines.append("### Top 30 slowest OK tests")
    lines.append("")
    for r in top_ok:
        lines.append(fmt_case(r))
    lines.append("")

    if failed:
        lines.append("## Failed tests (non-timeout)")
        lines.append("")
        for r in sorted(failed, key=lambda r: (r.case.package, r.case.suite, r.case.filename, r.case.index)):
            c = r.case
            loc = f"{c.filename}:{c.line_number}" if c.line_number else c.filename
            attrs = f" attrs={list(c.attrs)}" if c.attrs else ""
            lines.append(
                f"- `EXIT={r.exit_code}` `{c.package}` `{c.suite}` `{loc}` `#{c.index}` {c.name}{attrs}"
            )
        lines.append("")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines) + "\n")


def main() -> int:
    ap = argparse.ArgumentParser(description="Find slow MoonBit tests in this repo (native driver timing).")
    ap.add_argument(
        "--repo",
        default=".",
        help="Repo root (default: .)",
    )
    ap.add_argument(
        "--timeout",
        type=float,
        default=10.0,
        help="Per-test timeout in seconds (default: 10)",
    )
    ap.add_argument(
        "--report",
        default="docs/slow-tests.md",
        help="Markdown report path (default: docs/slow-tests.md)",
    )
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    build_drivers(repo)

    test_root = repo / "_build" / "native" / "debug" / "test"
    infos = find_blackbox_infos(test_root)
    if not infos:
        print(f"no __blackbox_test_info.json found under {test_root}", file=sys.stderr)
        return 2

    cases: List[TestCase] = []
    for info in infos:
        package = package_from_info_path(test_root, info)
        cases.extend(load_cases_for_info(info, package))

    # De-dupe across sections (some entries appear in multiple sections)
    uniq: Dict[Tuple[str, str, str, int], TestCase] = {}
    for c in cases:
        key = (c.package, c.suite, c.filename, c.index)
        prev = uniq.get(key)
        if prev is None:
            uniq[key] = c
        else:
            # Keep the richer case (union of kinds + attrs).
            merged = TestCase(
                package=c.package,
                suite=c.suite,
                filename=c.filename,
                index=c.index,
                name=prev.name or c.name,
                line_number=prev.line_number if prev.line_number is not None else c.line_number,
                attrs=tuple(sorted(set(prev.attrs).union(c.attrs))),
                kinds=tuple(sorted(set(prev.kinds).union(c.kinds))),
            )
            uniq[key] = merged
    cases = list(uniq.values())
    cases.sort(key=lambda c: (c.package, c.suite, c.filename, c.index))

    results: List[TestResult] = []

    for c in cases:
        rsp = rspfile_for_package(test_root, c.package, c.suite)
        # Use the half-open range convention used by moon test itself: idx-(idx+1)
        spec = f"{c.filename}:{c.index}-{c.index + 1}"
        cmd = ["tcc", f"@{rsp}", spec]
        rc, secs, timed_out = run(cmd, cwd=repo, timeout_s=args.timeout)
        if timed_out:
            results.append(TestResult(case=c, seconds=secs, status="timeout", exit_code=None))
        elif rc == 0:
            results.append(TestResult(case=c, seconds=secs, status="ok", exit_code=0))
        else:
            results.append(TestResult(case=c, seconds=secs, status="failed", exit_code=rc))

    write_markdown_report(
        out_path=(repo / args.report),
        results=results,
        timeout_s=float(args.timeout),
        build_dir=test_root,
    )

    # Print a compact summary for CI / humans.
    ok_times = sorted(r.seconds for r in results if r.status == "ok")
    p50 = statistics.median(ok_times) if ok_times else 0.0
    p95 = percentile(ok_times, 0.95) if ok_times else 0.0
    slow_ok = [r for r in results if r.status == "ok" and r.seconds >= p95]
    timeouts = [r for r in results if r.status == "timeout"]
    print(
        f"measured={len(results)} ok={len(ok_times)} timeouts={len(timeouts)} "
        f"slow_ok(p95)={len(slow_ok)} p50={p50:.3f}s p95={p95:.3f}s "
        f"timeout={args.timeout:.1f}s report={args.report}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
