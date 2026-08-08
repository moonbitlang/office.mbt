///|
// Reviewed golden renders for the SVG backend (design record, correctness
// reference #4). The emitter is deterministic — fixed bundled metrics,
// fixed 3-decimal rounding — so exact snapshots of the rendered SVG catch
// every change, including the text position and color a layout engine
// most needs guarded. Update with `moon test --update` and re-review the
// diff by eye before committing it.
//
// Why not svgdiff. `Milky2018/svgdiff` compares SVG semantically and
// returns typed, diagnosable differences, which is a nicer failure mode
// than a character diff. Measured against this emitter (svgdiff 0.5.13,
// 2026-08-08) it does not earn its place here:
//
//   * It cannot see text. Any document carrying a `viewBox` or a `<text>`
//     element reports `analysis_status = "partial"`
//     (`renderer_viewport_raster_unproven`, `analysis_coverage_unproven`),
//     and changing a `<text>` fill from #000000 to #ff0000 yields ZERO
//     differences — font-dependent text semantics are outside its
//     supported subset. It does see shape changes, e.g. the page
//     background rect. Text is nearly everything this backend emits.
//   * It costs five third-party packages (svgdiff, mizchi/svg,
//     mizchi/pixelmatch, Milky2018/xml, svgdiff-raster-codec) inside the
//     dependency closure that office's fresh-agent release gate reviews
//     and locks.
//
// Revisit if svgdiff gains text coverage: it would then guard the thing
// that matters, and the trade would look different.
