# Corpus Smoke

Real-world DOCX fixtures (see `fixtures/MANIFEST.md` for provenance) with the
`docx` CLI's behaviour on each pinned in `expectations.tsv`. The harness
(`run.sh`) re-runs `validate` / `text` / `convert` / `annotate add` over every
fixture and compares normalised outcomes, and for every document the CLI
agrees to annotate it also requires the round trip surgery demands: the
annotated package still validates, and every story other than the new comment
reads back identical.

This pins two different kinds of fact:

* **acceptance** — documents from producers our authored fixtures do not cover
  (WPS, PHPWord, Apache POI, LibreOffice, Outlook, Mac Word, and Word itself
  across scripts from Arabic to Thai) stay readable and annotatable;
* **refusal** — documents our tools deliberately refuse keep being refused for
  the same *named* reason, recorded in the `class` column. A refusal turning
  into acceptance is progress, but it should be a deliberate diff to
  `expectations.tsv`, not a silent behaviour change; a refusal changing class
  is a regression until proven otherwise.

Which labels each fixture was selected to cover is committed as `labels.tsv`,
so the set-cover claim is checkable from this directory alone.

The refusal classes present, from a 591-document stratified sweep
(counts are for the whole sweep, not just the vendored subset):

| class | sweep count | meaning |
|---|---:|---|
| `xml-token-budget` | 39 | resource-limit refusals on real documents: 38 hit the XML token budget (262,144 tokens), one a zip resource limit that this harness's message mapping folds into the same class. Recalibrated for #438: with per-parse name interning and the token ceiling at one per four source units, every vendored fixture of this class now passes, and the rows here pin the acceptance |
| `orphan-comments-part` | 21 | `word/comments.xml` exists but no relationship wires it |
| `opc-noncanonical-entry` | 11 | ZIP entry like `[trash]/0001.dat` refuses the whole package |
| `eocd-trailing-bytes` | 4 | garbage after the end-of-central-directory record (Word also refuses) |
| `ms-sidecar-parts` | 4 | Microsoft annotation sidecars we refuse to desynchronise |
| `zip64-phantom-field` | 2 | zip64 extra field present with nothing masked |
| `wt-child-element` | 2 | markup like `<w:br/>` inside `w:t` |
| `sidecar-unknown-paraid` | 1 | a `commentsExtended` record referencing a paraId that does not exist |
| `invalid-relationship-iri` | 1 | an external relationship target that is not a valid IRI |
| `missing-source-part` | 1 | a relationship part describing a customXml part that is absent |

Refreshing or extending the subset: the sweep and set-cover tooling lives in
`.repos/corpus-sample` (untracked); `fixtures/MANIFEST.md` records the repair
rule and both hashes so any fixture can be re-derived from its source URL.
