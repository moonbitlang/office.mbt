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
    "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    "fixtures/camlpdf/logo.pdf",
)


@dataclass(frozen=True)
class FixtureReport:
    pdf: Path
    pdflite_markdown: Path
    markitdown_markdown: Path
    pdftotext_text: Path
    diff: Path
    pdflite_chars: int | None
    markitdown_chars: int | None
    pdftotext_chars: int | None
    pdflite_lines: int | None
    markitdown_lines: int | None
    pdftotext_lines: int | None
    pdflite_average_line_length: float | None
    markitdown_average_line_length: float | None
    pdftotext_average_line_length: float | None
    pdflite_replacement_chars: int | None
    markitdown_replacement_chars: int | None
    pdftotext_replacement_chars: int | None
    pdflite_raw_controls: int | None
    markitdown_raw_controls: int | None
    pdftotext_raw_controls: int | None
    pdflite_cjk_unified_ideographs: int | None
    markitdown_cjk_unified_ideographs: int | None
    pdftotext_cjk_unified_ideographs: int | None
    exact_match: bool
    pdflite_error: str | None = None
    markitdown_error: str | None = None
    pdftotext_error: str | None = None


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def run_command(
    command: list[str],
    cwd: Path,
    error_on_output: bool = False,
) -> str | None:
    result = subprocess.run(
        command,
        cwd=cwd,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode == 0:
        if error_on_output:
            detail = (result.stdout + result.stderr).strip()
            if detail:
                return detail
        return None
    detail = (result.stdout + result.stderr).strip()
    if detail:
        return detail
    return f"command exited with status {result.returncode}: {' '.join(command)}"


def normalize_markdown(text: str) -> str:
    lines = [line.rstrip() for line in text.replace("\r\n", "\n").split("\n")]
    while lines and lines[-1] == "":
        lines.pop()
    return "\n".join(lines) + "\n"


def raw_control_count(text: str) -> int:
    return sum(
        1
        for char in text
        if (
            ord(char) < 0x20
            and char not in "\n\t\f"
        ) or 0x7F <= ord(char) <= 0x9F
    )


def replacement_char_count(text: str) -> int:
    return text.count("\uFFFD")


def line_metrics(text: str) -> tuple[int, float]:
    lines = text.splitlines()
    if not lines:
        return 0, 0.0
    return len(lines), sum(len(line) for line in lines) / len(lines)


def cjk_unified_ideograph_count(text: str) -> int:
    return len({char for char in text if "\u4E00" <= char <= "\u9FFF"})


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


def pdftotext_command(user_command: str | None) -> list[str] | None:
    if user_command:
        return shlex.split(user_command)
    if shutil.which("pdftotext"):
        return ["pdftotext", "-layout"]
    return None


def convert_with_pdflite(root: Path, pdf: Path, output: Path) -> str | None:
    return run_command(
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
        error_on_output=True,
    )


def convert_with_markitdown(
    root: Path,
    command: list[str],
    pdf: Path,
    output: Path,
) -> str | None:
    return run_command([*command, str(pdf), "-o", str(output)], cwd=root)


def convert_with_pdftotext(
    root: Path,
    command: list[str] | None,
    pdf: Path,
    output: Path,
) -> str | None:
    if command is None:
        return "pdftotext is not installed; skipping optional layout baseline"
    return run_command([*command, str(pdf), str(output)], cwd=root)


def write_diff(pdflite_text: str, markitdown_text: str, output: Path) -> None:
    diff = difflib.unified_diff(
        pdflite_text.splitlines(keepends=True),
        markitdown_text.splitlines(keepends=True),
        fromfile="pdflite",
        tofile="markitdown",
    )
    output.write_text("".join(diff), encoding="utf-8")


def read_normalized_output(path: Path) -> tuple[str | None, str | None]:
    if not path.exists():
        return None, f"expected output was not written: {path}"
    try:
        return normalize_markdown(path.read_text(encoding="utf-8")), None
    except UnicodeError as error:
        return None, f"could not decode UTF-8 output {path}: {error}"


def write_error(path: Path, error: str | None) -> None:
    if error:
        path.write_text(error.rstrip() + "\n", encoding="utf-8")
    elif path.exists():
        path.unlink()


def relative_path(root: Path, path: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def compare_fixture(
    root: Path,
    markitdown: list[str],
    pdftotext: list[str] | None,
    pdf: Path,
    output_dir: Path,
) -> FixtureReport:
    stem = pdf.stem
    pdflite_output = output_dir / f"{stem}.pdflite.md"
    markitdown_output = output_dir / f"{stem}.markitdown.md"
    pdftotext_output = output_dir / f"{stem}.pdftotext.txt"
    diff_output = output_dir / f"{stem}.diff"
    pdflite_error = convert_with_pdflite(root, pdf, pdflite_output)
    markitdown_error = convert_with_markitdown(root, markitdown, pdf, markitdown_output)
    pdftotext_error = convert_with_pdftotext(root, pdftotext, pdf, pdftotext_output)
    pdflite_text, pdflite_read_error = read_normalized_output(pdflite_output)
    markitdown_text, markitdown_read_error = read_normalized_output(
        markitdown_output
    )
    pdftotext_text, pdftotext_read_error = read_normalized_output(pdftotext_output)
    pdflite_error = pdflite_error or pdflite_read_error
    markitdown_error = markitdown_error or markitdown_read_error
    pdftotext_error = pdftotext_error or pdftotext_read_error
    write_error(output_dir / f"{stem}.pdflite.err", pdflite_error)
    write_error(output_dir / f"{stem}.markitdown.err", markitdown_error)
    write_error(output_dir / f"{stem}.pdftotext.err", pdftotext_error)
    if pdflite_text is not None:
        pdflite_output.write_text(pdflite_text, encoding="utf-8")
    if markitdown_text is not None:
        markitdown_output.write_text(markitdown_text, encoding="utf-8")
    if pdftotext_text is not None:
        pdftotext_output.write_text(pdftotext_text, encoding="utf-8")
    if pdflite_text is not None and markitdown_text is not None:
        write_diff(pdflite_text, markitdown_text, diff_output)
    else:
        diff_output.write_text(
            "comparison incomplete\n"
            + f"pdflite_error: {pdflite_error or 'none'}\n"
            + f"markitdown_error: {markitdown_error or 'none'}\n",
            encoding="utf-8",
        )
    pdflite_lines, pdflite_average_line_length = (
        line_metrics(pdflite_text) if pdflite_text is not None else (None, None)
    )
    markitdown_lines, markitdown_average_line_length = (
        line_metrics(markitdown_text)
        if markitdown_text is not None
        else (None, None)
    )
    pdftotext_lines, pdftotext_average_line_length = (
        line_metrics(pdftotext_text) if pdftotext_text is not None else (None, None)
    )
    return FixtureReport(
        pdf=pdf,
        pdflite_markdown=pdflite_output,
        markitdown_markdown=markitdown_output,
        pdftotext_text=pdftotext_output,
        diff=diff_output,
        pdflite_chars=len(pdflite_text) if pdflite_text is not None else None,
        markitdown_chars=len(markitdown_text)
        if markitdown_text is not None
        else None,
        pdftotext_chars=len(pdftotext_text) if pdftotext_text is not None else None,
        pdflite_lines=pdflite_lines,
        markitdown_lines=markitdown_lines,
        pdftotext_lines=pdftotext_lines,
        pdflite_average_line_length=pdflite_average_line_length,
        markitdown_average_line_length=markitdown_average_line_length,
        pdftotext_average_line_length=pdftotext_average_line_length,
        pdflite_replacement_chars=replacement_char_count(pdflite_text)
        if pdflite_text is not None
        else None,
        markitdown_replacement_chars=replacement_char_count(markitdown_text)
        if markitdown_text is not None
        else None,
        pdftotext_replacement_chars=replacement_char_count(pdftotext_text)
        if pdftotext_text is not None
        else None,
        pdflite_raw_controls=raw_control_count(pdflite_text)
        if pdflite_text is not None
        else None,
        markitdown_raw_controls=raw_control_count(markitdown_text)
        if markitdown_text is not None
        else None,
        pdftotext_raw_controls=raw_control_count(pdftotext_text)
        if pdftotext_text is not None
        else None,
        pdflite_cjk_unified_ideographs=cjk_unified_ideograph_count(pdflite_text)
        if pdflite_text is not None
        else None,
        markitdown_cjk_unified_ideographs=cjk_unified_ideograph_count(
            markitdown_text
        )
        if markitdown_text is not None
        else None,
        pdftotext_cjk_unified_ideographs=cjk_unified_ideograph_count(pdftotext_text)
        if pdftotext_text is not None
        else None,
        exact_match=pdflite_text is not None
        and markitdown_text is not None
        and pdflite_text == markitdown_text,
        pdflite_error=pdflite_error,
        markitdown_error=markitdown_error,
        pdftotext_error=pdftotext_error,
    )


def write_json_report(root: Path, output: Path, reports: list[FixtureReport]) -> None:
    payload = {
        "fixtures": [
            {
                "pdf": relative_path(root, report.pdf),
                "pdflite_markdown": relative_path(root, report.pdflite_markdown),
                "markitdown_markdown": relative_path(root, report.markitdown_markdown),
                "pdftotext_text": relative_path(root, report.pdftotext_text),
                "diff": relative_path(root, report.diff),
                "pdflite_chars": report.pdflite_chars,
                "markitdown_chars": report.markitdown_chars,
                "pdftotext_chars": report.pdftotext_chars,
                "pdflite_lines": report.pdflite_lines,
                "markitdown_lines": report.markitdown_lines,
                "pdftotext_lines": report.pdftotext_lines,
                "pdflite_average_line_length": (
                    report.pdflite_average_line_length
                ),
                "markitdown_average_line_length": (
                    report.markitdown_average_line_length
                ),
                "pdftotext_average_line_length": (
                    report.pdftotext_average_line_length
                ),
                "pdflite_replacement_chars": report.pdflite_replacement_chars,
                "markitdown_replacement_chars": report.markitdown_replacement_chars,
                "pdftotext_replacement_chars": report.pdftotext_replacement_chars,
                "pdflite_raw_controls": report.pdflite_raw_controls,
                "markitdown_raw_controls": report.markitdown_raw_controls,
                "pdftotext_raw_controls": report.pdftotext_raw_controls,
                "pdflite_cjk_unified_ideographs": (
                    report.pdflite_cjk_unified_ideographs
                ),
                "markitdown_cjk_unified_ideographs": (
                    report.markitdown_cjk_unified_ideographs
                ),
                "pdftotext_cjk_unified_ideographs": (
                    report.pdftotext_cjk_unified_ideographs
                ),
                "exact_match": report.exact_match,
                "pdflite_error": report.pdflite_error,
                "markitdown_error": report.markitdown_error,
                "pdftotext_error": report.pdftotext_error,
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
        "| Fixture | pdflite chars | MarkItDown chars | pdftotext chars | Line shape | Quality repl/raw (pdflite/MarkItDown/pdftotext) | CJK glyphs (pdflite/MarkItDown/pdftotext) | Exact match | Diff |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |",
    ]
    for report in reports:
        pdflite_quality = (
            f"{report.pdflite_replacement_chars}/{report.pdflite_raw_controls}"
            if report.pdflite_replacement_chars is not None
            and report.pdflite_raw_controls is not None
            else "error"
        )
        markitdown_quality = (
            f"{report.markitdown_replacement_chars}/"
            f"{report.markitdown_raw_controls}"
            if report.markitdown_replacement_chars is not None
            and report.markitdown_raw_controls is not None
            else "error"
        )
        pdftotext_quality = (
            f"{report.pdftotext_replacement_chars}/"
            f"{report.pdftotext_raw_controls}"
            if report.pdftotext_replacement_chars is not None
            and report.pdftotext_raw_controls is not None
            else "n/a"
        )
        if (
            report.pdflite_cjk_unified_ideographs is not None
            and report.markitdown_cjk_unified_ideographs is not None
        ):
            pdftotext_cjk = (
                str(report.pdftotext_cjk_unified_ideographs)
                if report.pdftotext_cjk_unified_ideographs is not None
                else "n/a"
            )
            cjk_glyphs = (
                f"{report.pdflite_cjk_unified_ideographs}/"
                f"{report.markitdown_cjk_unified_ideographs}/"
                f"{pdftotext_cjk}"
            )
        else:
            cjk_glyphs = "error/n/a"
        if (
            report.pdflite_lines is not None
            and report.markitdown_lines is not None
            and report.pdflite_average_line_length is not None
            and report.markitdown_average_line_length is not None
        ):
            pdftotext_lines = (
                str(report.pdftotext_lines)
                if report.pdftotext_lines is not None
                else "n/a"
            )
            pdftotext_average = (
                f"{report.pdftotext_average_line_length:.1f}"
                if report.pdftotext_average_line_length is not None
                else "n/a"
            )
            line_shape = (
                f"{report.pdflite_lines}/{report.markitdown_lines}/"
                f"{pdftotext_lines} lines, "
                f"{report.pdflite_average_line_length:.1f}/"
                f"{report.markitdown_average_line_length:.1f}/"
                f"{pdftotext_average} avg"
            )
        else:
            line_shape = "error/n/a"
        quality = (
            f"{pdflite_quality}/{markitdown_quality}/{pdftotext_quality}"
        )
        lines.append(
            "| "
            + " | ".join(
                [
                    relative_path(root, report.pdf),
                    str(report.pdflite_chars)
                    if report.pdflite_chars is not None
                    else "error",
                    str(report.markitdown_chars)
                    if report.markitdown_chars is not None
                    else "error",
                    str(report.pdftotext_chars)
                    if report.pdftotext_chars is not None
                    else "n/a",
                    line_shape,
                    quality,
                    cjk_glyphs,
                    "yes" if report.exact_match else "no",
                    relative_path(root, report.diff),
                ]
            )
            + " |"
        )
    lines.append("")
    lines.append(
        "Differences are expected: pdflite currently emits explicit page "
        "headings, MarkItDown applies its own layout heuristics, and "
        "pdftotext -layout is an optional physical-layout baseline."
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
    parser.add_argument(
        "--pdftotext-cmd",
        help=(
            "Optional pdftotext command. Defaults to 'pdftotext -layout' when "
            "pdftotext is installed."
        ),
    )
    parser.add_argument(
        "--skip-pdftotext",
        action="store_true",
        help="Skip the optional pdftotext -layout baseline.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = repo_root()
    output_dir = (root / args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    markitdown = markitdown_command(args.markitdown_cmd)
    pdftotext = None if args.skip_pdftotext else pdftotext_command(
        args.pdftotext_cmd,
    )
    reports = [
        compare_fixture(
            root,
            markitdown,
            pdftotext,
            (root / fixture).resolve(),
            output_dir,
        )
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
