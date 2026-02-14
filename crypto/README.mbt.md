# crypto

A pure MoonBit implementation of cryptographic primitives used for XLSX file encryption.

## Features

- **Hash algorithms**: MD4, MD5, RIPEMD-160, SHA-1, SHA-256, SHA-512
- **Encryption**: AES-128/192/256 in ECB and CBC modes
- **Byte utilities**: little-endian integer conversion

## Hash Functions

The `hash_concat` function supports the following algorithms:

| Algorithm | Name String |
|-----------|-------------|
| MD4 | `"md4"` |
| MD5 | `"md5"` |
| RIPEMD-160 | `"ripemd160"` |
| SHA-1 | `"sha1"` |
| SHA-256 | `"sha256"` |
| SHA-512 | `"sha512"` |

### Usage

```mbt check
///|
test "hash functions" {
  // Hash single input
  let md5_hash = @crypto.hash_concat("md5", [b"Hello, World!"])
  inspect(md5_hash.length(), content="16") // MD5 produces 16 bytes
  let sha256_hash = @crypto.hash_concat("sha256", [b"Hello, World!"])
  inspect(sha256_hash.length(), content="32") // SHA-256 produces 32 bytes

  // Hash concatenated inputs
  let combined = @crypto.hash_concat("sha1", [b"Hello", b", ", b"World!"])
  inspect(combined.length(), content="20") // SHA-1 produces 20 bytes
}
```

## AES Encryption

AES encryption supports 128-bit, 192-bit, and 256-bit keys (16, 24, or 32 bytes).

### ECB Mode

ECB (Electronic Codebook) mode encrypts each block independently.

```mbt check
///|
test "aes ecb" {
  let key : Bytes = b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f"
  let plaintext : Bytes = b"16 bytes block!!" // Must be multiple of 16 bytes

  // Encrypt
  let ciphertext = @crypto.aes_ecb_encrypt(plaintext, key)
  inspect(ciphertext.length(), content="16")

  // Decrypt
  let decrypted = @crypto.aes_ecb_decrypt(ciphertext, key)
  inspect(
    decrypted,
    content=(
      #|b")\xb0$\xfe\x0a\xefG\xe0\x7f\x14d\xe2\x5c9\x95\x8b"
    ),
  )
}
```

### CBC Mode (Decryption)

CBC (Cipher Block Chaining) mode uses an initialization vector (IV) for added security.

```mbt check
///|
test "aes cbc decrypt" {
  let key : Bytes = b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f"
  let iv : Bytes = b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f"
  let ciphertext : Bytes = b"\x76\x49\xab\xac\x81\x19\xb2\x46\xce\xe9\x8e\x9b\x12\xe9\x19\x7d"

  // Decrypt
  let decrypted = @crypto.aes_cbc_decrypt(ciphertext, key, iv)
  inspect(
    decrypted,
    content=(
      #|b"\x17\x97i\x86z\x9e7e\xbbX0Z\xc02\x05\xed"
    ),
  )
}
```

## Byte Utilities

Functions for converting between integers and byte arrays.

### Little-Endian

```mbt check
///|
test "little endian" {
  // Read UInt32 from bytes
  let bytes : Bytes = b"\x01\x02\x03\x04"
  let value = @crypto.u32_from_le(bytes, 0)
  inspect(value, content="67305985") // 0x04030201

  // Write UInt32 to bytes
  let buf : Array[Byte] = []
  @crypto.push_u32_le(buf, 0x04030201U)
  inspect(Bytes::from_array(buf), content="b\"\\x01\\x02\\x03\\x04\"")
}
```

## API Reference

### Hash Functions

| Function | Description |
|----------|-------------|
| `hash_concat(algo, parts)` | Hash concatenated byte arrays |

### AES Functions

| Function | Description |
|----------|-------------|
| `aes_ecb_encrypt(plaintext, key)` | Encrypt using AES-ECB |
| `aes_ecb_decrypt(ciphertext, key)` | Decrypt using AES-ECB |
| `aes_cbc_decrypt(ciphertext, key, iv)` | Decrypt using AES-CBC |

### Byte Utilities

| Function | Description |
|----------|-------------|
| `u32_from_le(bytes, offset)` | Read little-endian UInt32 |
| `u64_from_le(bytes, offset)` | Read little-endian UInt64 |
| `push_u32_le(buf, value)` | Write little-endian UInt32 |

## Error Handling

Operations that can fail raise `CryptoError`:

```mbt nocheck
///|
pub suberror CryptoError {
  InvalidCrypto(msg~ : String)
}
```

Common error cases:
- Invalid key length (must be 16, 24, or 32 bytes for AES)
- Invalid data length (must be multiple of 16 bytes for AES)
- Invalid IV length (must be 16 bytes for AES-CBC)
