# base64

A pure MoonBit implementation of Base64 encoding and decoding.

## Features

- Standard Base64 encoding (RFC 4648)
- Encoding and decoding support
- Proper padding handling

## Usage

### Encoding

```mbt check
///|
test "encode" {
  // Encode bytes to Base64 string
  let encoded = @base64.encode(b"Hello, World!")
  inspect(encoded, content="SGVsbG8sIFdvcmxkIQ==")

  // Empty input
  let empty = @base64.encode(b"")
  inspect(empty, content="")

  // Binary data
  let binary = @base64.encode(b"\x00\x01\x02\x03")
  inspect(binary, content="AAECAw==")
}
```

### Decoding

```mbt check
///|
test "decode" {
  // Decode Base64 string to bytes
  let decoded = @base64.decode("SGVsbG8sIFdvcmxkIQ==")
  inspect(decoded, content="b\"Hello, World!\"")

  // Binary data
  let binary = @base64.decode("AAECAw==")
  inspect(binary, content="b\"\\x00\\x01\\x02\\x03\"")
}
```

### Round-Trip

```mbt check
///|
test "round trip" {
  let original : Bytes = b"The quick brown fox jumps over the lazy dog"
  let encoded = @base64.encode(original)
  let decoded = @base64.decode(encoded)
  inspect(decoded == original, content="true")
}
```

## API Reference

| Function | Description |
|----------|-------------|
| `encode(bytes)` | Encode bytes to Base64 string |
| `decode(string)` | Decode Base64 string to bytes |

## Error Handling

The `decode` function raises `Base64Error` for invalid input:

```mbt nocheck
///|
pub suberror Base64Error {
  InvalidBase64(msg~ : String)
}
```

Common error cases:
- Invalid characters (not in Base64 alphabet)
- Invalid padding
- Invalid length

```mbt check
///|
test "error handling" {
  // Invalid character
  let result1 : Result[Bytes, Error] = try? @base64.decode("Invalid!")
  guard result1 is Err(_) else { return }

  // Invalid padding
  let result2 : Result[Bytes, Error] = try? @base64.decode("A===")
  guard result2 is Err(_) else { return }
}
```

## Base64 Alphabet

The standard Base64 alphabet is used:

```
ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/
```

Padding character: `=`
