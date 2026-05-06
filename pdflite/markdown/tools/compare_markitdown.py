#!/usr/bin/env python3
"""Compare pdflite Markdown extraction with MarkItDown for local fixtures."""

from __future__ import annotations

import argparse
import difflib
import json
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


DEFAULT_FIXTURES = (
    "markdown/fixtures/pandoc_latin.pdf",
    "markdown/fixtures/pandoc_cjk.pdf",
)


@dataclass(frozen=True)
class FixtureReport:
    pdf: Path
    pdflite_markdown: Path
    markitdown_markdown: Path
    diff: Path
    pdflite_chars: int
    markitdown_chars: int
    exact_match: bool


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def run_command(command: list[str], cwd: Path) -> None:
    subprocess.run(command, cwd=cwd, check=True)


def normalize_markdown(text: str) -> str:
    lines = [line.rstrip() for line in text.replace("\r\n", "\n").split("\n")]
    while lines and lines[-1] == "":
        lines.pop()
    return "\n".join(lines) + "\n"


def markitdown_command(user_command: str | None) -> list[str]:
    if user_command:
        return shlex.split(user_command)
    if shutil.which("markitdown"):
        return ["markitdown"]
    if shutil.which("uvx"):
        return ["uvx", "--from", "markitdown[pdf]", "markitdown"]
    raise SystemExit(
        "MarkItDown is not installed. Install it or pass --markitdown-cmd."
    )


def convert_with_pdflite(root: Path, pdf: Path, output: Path) -> None:
    run_command(
        [
            "moon",
            "run",
            "--target",
            "native",
            "markdown/cmd",
            str(pdf),
            str(output),
        ],
        cwd=root,
    )


def convert_with_markitdown(
    root: Path,
    command: list[str],
    pdf: Path,
    output: Path,
) -> None:
    run_command([*command, str(pdf), "-o", str(output)], cwd=root)


def write_diff(pdflite_text: str, markitdown_text: str, output: Path) -> None:
    diff = difflib.unified_diff(
        pdflite_text.splitlines(keepends=True),
        markitdown_text.splitlines(keepends=True),
        fromfile="pdflite",
        tofile="markitdown",
    )
    output.write_text("".join(diff), encoding="utf-8")


def relative_path(root: Path, path: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def compare_fixture(
    root: Path,
    markitdown: list[str],
    pdf: Path,
    output_dir: Path,
) -> FixtureReport:
    stem = pdf.stem
    pdflite_output = output_dir / f"{stem}.pdflite.md"
    markitdown_output = output_dir / f"{stem}.markitdown.md"
    diff_output = output_dir / f"{stem}.diff"
    convert_with_pdflite(root, pdf, pdflite_output)
    convert_with_markitdown(root, markitdown, pdf, markitdown_output)
    pdflite_text = normalize_markdown(pdflite_output.read_text(encoding="utf-8"))
    markitdown_text = normalize_markdown(
        markitdown_output.read_text(encoding="utf-8")
    )
    pdflite_output.write_text(pdflite_text, encoding="utf-8")
    markitdown_output.write_text(markitdown_text, encoding="utf-8")
    write_diff(pdflite_text, markitdown_text, diff_output)
    return FixtureReport(
        pdf=pdf,
        pdflite_markdown=pdflite_output,
        markitdown_markdown=markitdown_output,
        diff=diff_output,
        pdflite_chars=len(pdflite_text),
        markitdown_chars=len(markitdown_text),
        exact_match=pdflite_text == markitdown_text,
    )


def write_json_report(root: Path, output: Path, reports: list[FixtureReport]) -> None:
    payload = {
        "fixtures": [
            {
                "pdf": relative_path(root, report.pdf),
                "pdflite_markdown": relative_path(root, report.pdflite_markdown),
                "markitdown_markdown": relative_path(root, report.markitdown_markdown),
                "diff": relative_path(root, report.diff),
                "pdflite_chars": report.pdflite_chars,
                "markitdown_chars": report.markitdown_chars,
                "exact_match": report.exact_match,
            }
            for report in reports
        ]
    }
    output.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_markdown_report(
    root: Path,
    output: Path,
    reports: list[FixtureReport],
) -> None:
    lines = [
        "# MarkItDown Comparison",
        "",
        "| Fixture | pdflite chars | MarkItDown chars | Exact match | Diff |",
        "| --- | ---: | ---: | --- | --- |",
    ]
    for report in reports:
        lines.append(
            "| "
            + " | ".join(
                [
                    relative_path(root, report.pdf),
                    str(report.pdflite_chars),
                    str(report.markitdown_chars),
                    "yes" if report.exact_match else "no",
                    relative_path(root, report.diff),
                ]
            )
            + " |"
        )
    lines.append("")
    lines.append(
        "Differences are expected: pdflite currently emits explicit page "
        "headings, while MarkItDown applies its own layout heuristics."
    )
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "fixtures",
        nargs="*",
        default=list(DEFAULT_FIXTURES),
        help="PDF fixtures to compare.",
    )
    parser.add_argument(
        "--output-dir",
        default="markdown/reports/markitdown_local",
        help="Directory for generated Markdown, diffs, and summary JSON.",
    )
    parser.add_argument(
        "--markitdown-cmd",
        help="Command used to run MarkItDown, for example 'uvx markitdown'.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = repo_root()
    output_dir = (root / args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    markitdown = markitdown_command(args.markitdown_cmd)
    reports = [
        compare_fixture(root, markitdown, (root / fixture).resolve(), output_dir)
        for fixture in args.fixtures
    ]
    write_json_report(root, output_dir / "summary.json", reports)
    write_markdown_report(root, output_dir / "summary.md", reports)
    for report in reports:
        status = "match" if report.exact_match else "diff"
        print(f"{status}: {report.pdf.name} -> {relative_path(root, report.diff)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
