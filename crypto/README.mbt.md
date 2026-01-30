# crypto

A pure MoonBit implementation of cryptographic primitives used for XLSX file encryption.

## Features

- **Hash algorithms**: MD4, MD5, RIPEMD-160, SHA-1, SHA-256, SHA-512
- **Encryption**: AES-128/192/256 in ECB and CBC modes
- **Byte utilities**: Big-endian and little-endian integer conversion

## Hash Functions

The `hash_bytes` and `hash_concat` functions support the following algorithms:

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
  let md5_hash = @crypto.hash_bytes("md5", b"Hello, World!")
  inspect(md5_hash.length(), content="16") // MD5 produces 16 bytes
  let sha256_hash = @crypto.hash_bytes("sha256", b"Hello, World!")
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

### CBC Mode

CBC (Cipher Block Chaining) mode uses an initialization vector (IV) for added security.

```mbt check
///|
test "aes cbc" {
  let key : Bytes = b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f"
  let iv : Bytes = b"\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f"
  let plaintext : Bytes = b"16 bytes block!!"

  // Encrypt
  let ciphertext = @crypto.aes_cbc_encrypt(plaintext, key, iv)
  inspect(ciphertext.length(), content="16")

  // Decrypt
  let decrypted = @crypto.aes_cbc_decrypt(ciphertext, key, iv)
  inspect(
    decrypted,
    content=(
      #|b"cE\xd9\x9f\xaa\x93\x01\xd4Hq\x09\xcf\x06o \xa5"
    ),
  )
}
```

## Byte Utilities

Functions for converting between integers and byte arrays:

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

### Big-Endian

```mbt check
///|
test "big endian" {
  // Read UInt32 from bytes
  let bytes : Bytes = b"\x01\x02\x03\x04"
  let value = @crypto.u32_from_be(bytes, 0)
  inspect(value, content="16909060") // 0x01020304

  // Read UInt64 from bytes
  let bytes64 : Bytes = b"\x01\x02\x03\x04\x05\x06\x07\x08"
  let value64 = @crypto.u64_from_be(bytes64, 0)
  inspect(value64, content="72623859790382856")

  // Write UInt32 to bytes
  let buf : Array[Byte] = []
  @crypto.push_u32_be(buf, 0x01020304U)
  inspect(Bytes::from_array(buf), content="b\"\\x01\\x02\\x03\\x04\"")
}
```

## API Reference

### Hash Functions

| Function | Description |
|----------|-------------|
| `hash_bytes(algo, data)` | Hash a single byte array |
| `hash_concat(algo, parts)` | Hash concatenated byte arrays |

### AES Functions

| Function | Description |
|----------|-------------|
| `aes_ecb_encrypt(plaintext, key)` | Encrypt using AES-ECB |
| `aes_ecb_decrypt(ciphertext, key)` | Decrypt using AES-ECB |
| `aes_cbc_encrypt(plaintext, key, iv)` | Encrypt using AES-CBC |
| `aes_cbc_decrypt(ciphertext, key, iv)` | Decrypt using AES-CBC |

### Byte Utilities

| Function | Description |
|----------|-------------|
| `u32_from_le(bytes, offset)` | Read little-endian UInt32 |
| `u32_from_be(bytes, offset)` | Read big-endian UInt32 |
| `u64_from_le(bytes, offset)` | Read little-endian UInt64 |
| `u64_from_be(bytes, offset)` | Read big-endian UInt64 |
| `push_u32_le(buf, value)` | Write little-endian UInt32 |
| `push_u32_be(buf, value)` | Write big-endian UInt32 |

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
