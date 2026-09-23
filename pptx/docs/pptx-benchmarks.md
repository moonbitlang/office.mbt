# PPTX benchmarks

Run from the repository root. The benchmark executable is a package of
`moonbitlang/pptx`; it uses the root `moon.work` and `_build` directory:

```sh
moon run --target native --release pptx/cmd/bench -- 100
moon bench --target native --release pptx/integration
```

The executable builds N slides with one text box each, serializes in memory,
and prints the output byte count. The integration benchmarks measure individual
operations.

For an optional process-time/RSS comparison with python-pptx and PptxGenJS:

```sh
bash scripts/bench_pptx.sh 3 10 100 1000
```

Install `python-pptx` in the Python environment and `pptxgenjs` in
`tools/pptx-bench/` before running that comparison. The root script builds
`pptx/cmd/bench` through the Office workspace and uses the comparative drivers
under `tools/pptx-bench/`. Optional third-party benchmarks are not CI gates.
The drivers originate from moon-pptx; see [provenance](../UPSTREAM.md).
