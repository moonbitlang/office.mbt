# Recipe: safely inspect a file you don't trust

Goal: someone handed you an `.xlsx` or `.docx` of unknown provenance and you
want to see what's inside without risking your machine.

## Why the wasm sandbox helps

These tools run as WebAssembly on MoonBit's runtime. The module is memory-safe
and can only read/write files and print — it **cannot execute other programs or
make network connections**. So parsing a hostile document can't corrupt memory,
run code, or exfiltrate data. (It is not a resource limiter: a crafted file can
still consume CPU/memory, and the tool writes to the paths you give it — so pass
an output directory you're comfortable with, and don't feed it endless input.)

## Inspect a spreadsheet

```
# structural check first — does it even parse as a valid OOXML package?
moon run --target wasm cmd/xlsx -- validate suspicious.xlsx

# what sheets are in it?
moon run --target wasm cmd/xlsx -- sheets suspicious.xlsx

# dump a sheet as CSV to read the contents
moon run --target wasm cmd/xlsx -- rows suspicious.xlsx --sheet Sheet1
```

`validate` reads the file's own bytes (not a rewritten copy), so it reports real
package defects. It prints `valid` or one problem per line.

## Inspect a Word document

```
# convert to Markdown and read the text; images stay inlined, nothing is executed
moon run --target wasm docx2html/cmd/docx2html -- --output-format=markdown suspicious.docx
```

If the file isn't a real DOCX (or is malformed), the tool exits non-zero with a
single `docx2html: …` message rather than doing anything dangerous.

## Good hygiene

- Run from, and write outputs into, a scratch directory.
- Treat a non-zero exit as "couldn't safely parse" — read the one-line message.
- Don't pipe extracted content into a shell; read it as data.
