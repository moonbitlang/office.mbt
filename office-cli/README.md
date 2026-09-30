# Office CLI

Run the published Office command through Mooncakes:

```sh
moonx moonbitlang/office help all --json
moonx moonbitlang/office <command> <args...>
```

Arguments after the package coordinate are passed directly to `office`; an
explicit `--` separator is not required.

The source tree also supports PPTX identification, outline, slide/notes text,
and fresh one-slide creation. See [PPTX integration](../docs/office-pptx.md).
Check your installed version with `office help pptx --json`; source support
does not imply the feature is already published.
