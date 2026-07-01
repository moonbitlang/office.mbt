# zip

A pure MoonBit implementation of ZIP archive reading and writing. This package provides ZIP container handling for the XLSX file format.

## Features

- Read and write ZIP archives
- DEFLATE compression support
- GZIP compression/decompression
- CRC32 checksum calculation

## Types

### Archive

`Archive` is the main container for ZIP entries:

```mbt nocheck
///|
pub struct Archive {
  entries : Array[Entry]
}
```

### Entry

`Entry` represents a single file in the archive:

```mbt nocheck
///|
pub struct Entry {
  name : String // File path within archive
  data : Bytes // Uncompressed file content
  compression : Compression
  data_descriptor : Bool
}
```

### Compression

Supported compression methods:

```mbt nocheck
///|
pub enum Compression {
  Store // No compression
  Deflate // DEFLATE algorithm
}
```

## Usage

### Creating Archives

```mbt check
///|
test "create archive" {
  let archive = @zip.Archive::new()

  // Add uncompressed file
  archive.add("hello.txt", b"Hello, World!")

  // Add compressed file
  archive.add("data.txt", b"Large content here...", compression=Deflate)

  // List entries
  inspect(
    archive.entries().map(entry => entry.name()),
    content="[\"hello.txt\", \"data.txt\"]",
  )

  // Get file content
  inspect(archive.get("hello.txt"), content="Some(b\"Hello, World!\")")
}
```

### Reading Archives

```mbt check
///|
test "read archive" {
  // Create an archive
  let archive = @zip.Archive::new()
  archive.add("file1.txt", b"Content 1")
  archive.add("file2.txt", b"Content 2")

  // Write to bytes
  let bytes = @zip.write(archive)

  // Read back
  let loaded = @zip.read(bytes)
  inspect(
    loaded.entries().map(entry => entry.name()),
    content="[\"file1.txt\", \"file2.txt\"]",
  )
  inspect(loaded.get("file1.txt"), content="Some(b\"Content 1\")")
}
```

### GZIP Compression

```mbt check
///|
test "gzip" {
  let data : Bytes = b"Hello, World! This is some test data to compress."

  // Compress
  let compressed = @zip.gzip(data)

  // Decompress
  let decompressed = @zip.gunzip(compressed)
  inspect(
    decompressed,
    content="b\"Hello, World! This is some test data to compress.\"",
  )
}
```

### Iterating Entries

```mbt check
///|
test "iterate entries" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"A")
  archive.add("b.txt", b"B")
  archive.add("c.txt", b"C")

  // Iterate over entries
  for entry in archive.entries() {
    println("File: \{entry.name()}, Size: \{entry.data().length()}")
  }
}
```

## API Reference

### Archive Methods

| Method | Description |
|--------|-------------|
| `Archive::new()` | Create an empty archive |
| `add(name, data, compression?, data_descriptor?)` | Add a file to the archive |
| `get(name)` | Get file content by name, returns `Bytes?` |
| `entries()` | Get view of all entries |

### Functions

| Function | Description |
|----------|-------------|
| `read(bytes)` | Parse ZIP bytes into Archive |
| `write(archive)` | Serialize Archive to ZIP bytes |
| `gzip(bytes)` | Compress bytes using GZIP |
| `gunzip(bytes)` | Decompress GZIP bytes |

## Error Handling

Operations that can fail raise `ZipError`:

```mbt nocheck
///|
pub suberror ZipError {
  OutOfBounds(offset~ : Int)
  InvalidSignature(expected~ : Int, actual~ : Int, offset~ : Int)
  MissingEndOfCentral
  UnsupportedFeature(msg~ : String)
  UnsupportedCompression(method_id~ : Int)
  InvalidUtf8(offset~ : Int)
}
```

Example error handling:

```mbt check
///|
test "error handling" {
  // Invalid ZIP data
  try @zip.read(b"not a zip file") catch {
    _ => ()
  } noraise {
    _ => fail("expected read to raise")
  }
}
```
