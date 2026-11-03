# Office CLI

Run the published Office command through Mooncakes:

```sh
moonx moonbitlang/office help all --json
moonx moonbitlang/office <command> <args...>
```

Arguments after the package coordinate are passed directly to `office`; an
explicit `--` separator is not required.

The source tree also supports PPTX identification, outline, slide/notes text,
and fresh one-slide creation. See [PPTX integration](references/office-pptx.md).
Check your installed version with `office help pptx --json`; source support
does not imply the feature is already published.

Existing-PDF inspection and manipulation live under `office pdf`; pdflite is
now library-only. See [PDF commands](references/office-pdf.md) for every migrated
operation, JSON/JSONL results, passwords, dry runs, and overwrite behavior.

## Skill packaging

`SKILL.md` and its supporting guides in `references/` are distributed together
in the standalone Office skill. Keep local documentation links inside this
directory; use repository URLs for source-only library documentation.

From the repository root, check the source references or a generated archive:

```sh
python3 scripts/check_office_skill.py
python3 scripts/check_office_skill.py /path/to/skills.zip
```

Publish documentation fixes as a new standalone skill version; existing
versions are immutable and installed clients do not redownload the same version.
