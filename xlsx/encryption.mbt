///|
let block_key : Bytes = Bytes::from_array(
  [0x14, 0x6e, 0x0b, 0xe7, 0xab, 0xac, 0xd0, 0xd6].map(v => v.to_byte()),
)

///|
let verifier_hash_input_block_key : Bytes = Bytes::from_array(
  [0xfe, 0xa7, 0xd2, 0x76, 0x3b, 0x4b, 0x9e, 0x79].map(v => v.to_byte()),
)

///|
let verifier_hash_value_block_key : Bytes = Bytes::from_array(
  [0xd7, 0xaa, 0x0f, 0x6d, 0x30, 0x61, 0x34, 0x4e].map(v => v.to_byte()),
)

///|
let iter_count = 50_000

///|
let package_encryption_chunk_size = 4096

///|
let package_offset = 8

///|
let max_password_length = 255

///|
priv struct KeyData {
  salt_size : Int
  block_size : Int
  key_bits : Int
  hash_size : Int
  cipher_algorithm : String
  cipher_chaining : String
  hash_algorithm : String
  salt_value : Bytes
}

///|
priv struct DataIntegrity {
  encrypted_hmac_key : Bytes
  encrypted_hmac_value : Bytes
}

///|
priv struct EncryptedKey {
  spin_count : Int
  key_data : KeyData
  encrypted_verifier_hash_input : Bytes
  encrypted_verifier_hash_value : Bytes
  encrypted_key_value : Bytes
}

///|
priv struct EncryptionInfo {
  key_data : KeyData
  data_integrity : DataIntegrity?
  encrypted_key : EncryptedKey
}

///|
priv enum EncryptionMechanism {
  Agile
  Standard
}

///|
priv struct ByteWriter {
  buf : Array[Byte]
}

///|
fn ByteWriter::new() -> ByteWriter {
  { buf: [] }
}

///|
fn ByteWriter::write_bytes(self : ByteWriter, value : BytesView) -> Unit {
  self.buf.append(value.to_array())
}

///|
fn ByteWriter::write_u16_le(self : ByteWriter, value : Int) -> Unit {
  self.buf.push((value & 0xff).to_byte())
  self.buf.push(((value >> 8) & 0xff).to_byte())
}

///|
fn ByteWriter::write_u32_le(self : ByteWriter, value : Int) -> Unit {
  let v = value.reinterpret_as_uint()
  @crypto.push_u32_le(self.buf, v)
}

///|
fn ByteWriter::write_u64_le(self : ByteWriter, value : Int) -> Unit {
  let v = value.to_uint64()
  for i in 0..<=7 {
    self.buf.push(((v >> (8 * i)) & 0xff).to_byte())
  }
}

///|
fn ByteWriter::write_utf16le(self : ByteWriter, value : StringView) -> Unit {
  let bytes = @encoding/utf16.encode(value, bom=false, endianness=Little)
  self.write_bytes(bytes)
}

///|
fn ByteWriter::to_bytes(self : ByteWriter) -> Bytes {
  Bytes::from_array(self.buf)
}

///|
fn normalize_hash_algorithm(name : StringView) -> String {
  let lower = name.to_lower().to_owned()
  if lower.has_prefix("sha-") {
    lower.replace_all(old="-", new="")
  } else {
    lower
  }
}

///|
fn hash_parts(
  algorithm : String,
  parts : ArrayView[BytesView],
) -> Bytes raise XlsxError {
  let normalized = normalize_hash_algorithm(algorithm)
  let out = @crypto.hash_concat(normalized, parts)
  if out.length() == 0 {
    raise UnsupportedEncryption(msg="unsupported hash algorithm: \{algorithm}")
  }
  out
}

///|
fn aes_ecb_encrypt(key : BytesView, data : BytesView) -> Bytes raise XlsxError {
  @crypto.aes_ecb_encrypt(key, data) catch {
    InvalidCrypto(msg~) => raise InvalidEncryptionInfo(msg~)
  }
}

///|
fn aes_ecb_decrypt(key : BytesView, data : BytesView) -> Bytes raise XlsxError {
  @crypto.aes_ecb_decrypt(key, data) catch {
    InvalidCrypto(msg~) => raise InvalidEncryptionInfo(msg~)
  }
}

///|
fn aes_cbc_decrypt(
  key : BytesView,
  iv : BytesView,
  data : BytesView,
) -> Bytes raise XlsxError {
  @crypto.aes_cbc_decrypt(key, iv, data) catch {
    InvalidCrypto(msg~) => raise InvalidEncryptionInfo(msg~)
  }
}

///|
fn byte_xor(a : Byte, b : Byte) -> Byte {
  (a.to_int() ^ b.to_int()).to_byte()
}

///|
fn u32_le_bytes(value : Int) -> Bytes {
  let out : Array[Byte] = []
  @crypto.push_u32_le(out, value.reinterpret_as_uint())
  Bytes::from_array(out)
}

///|
fn u64_le_bytes(value : UInt64) -> Bytes {
  let out : Array[Byte] = []
  for i in 0..<=7 {
    out.push(((value >> (8 * i)) & 0xff).to_byte())
  }
  Bytes::from_array(out)
}

///|
fn pad_zero(data : BytesView, block_size : Int) -> Bytes {
  let len = data.length()
  let remainder = len % block_size
  if remainder == 0 {
    return data.to_owned()
  }
  let padded_len = len + (block_size - remainder)
  let out : Array[Byte] = data.to_array()
  while out.length() < padded_len {
    out.push((0).to_byte())
  }
  Bytes::from_array(out)
}

///|
/// Lazily-initialized process-global generator behind `random_bytes`.
/// A fresh `Rand::new()` per call would reuse ChaCha8's fixed default
/// seed, making every salt/verifier identical across files and runs.
let random_bytes_rng : Ref[@random.Rand?] = Ref::new(None)

///|
/// Optional user-supplied source of cryptographically secure bytes.
let random_bytes_override : Ref[((Int) -> Bytes)?] = Ref::new(None)

///|
/// Installs a custom source for the random bytes used in workbook
/// encryption and sheet-protection salts, verifiers, and keys. The
/// function receives the byte count required and must return exactly
/// that many bytes.
///
/// Use this to supply cryptographically secure entropy (Go excelize
/// uses crypto/rand for these values). The built-in fallback is a
/// ChaCha8 generator seeded from wall-clock entropy whitened through
/// SHA-256: best-effort unique per process (millisecond clock
/// resolution means simultaneous process starts can collide), and not
/// a CSPRNG.
pub fn set_random_source(source : (Int) -> Bytes) -> Unit {
  random_bytes_override.val = Some(source)
}

///|
fn seeded_random_rng() -> @random.Rand {
  match random_bytes_rng.val {
    Some(rng) => rng
    None => {
      let tag : Bytes = b"mbtexcel-random-bytes-seed"
      let first = @crypto.hash_concat("sha256", [
        u64_le_bytes(@env.now())[:],
        tag[:],
      ])
      let seed = @crypto.hash_concat("sha256", [
        first[:],
        u64_le_bytes(@env.now())[:],
      ])
      let rng = @random.Rand::chacha8(seed~)
      random_bytes_rng.val = Some(rng)
      rng
    }
  }
}

///|
fn random_bytes(count : Int) -> Bytes {
  match random_bytes_override.val {
    Some(source) => {
      let bytes = source(count)
      if bytes.length() != count {
        abort("random source returned \{bytes.length()} bytes, need \{count}")
      }
      return bytes
    }
    None => ()
  }
  let rng = seeded_random_rng()
  let out : Array[Byte] = Array::make(count, (0).to_byte())
  for i in 0..<count {
    out[i] = rng.int(limit=256).to_byte()
  }
  Bytes::from_array(out)
}

///|
fn parse_required_attr(
  tag : StringView,
  name : String,
) -> String raise XlsxError {
  match attr_value(tag, name) {
    Some(value) => value
    None => raise InvalidEncryptionInfo(msg="missing \{name} attribute")
  }
}

///|
fn parse_int_attr(tag : StringView, name : String) -> Int raise XlsxError {
  let text = parse_required_attr(tag, name)
  @string.parse_int(text, base=10) catch {
    _ => raise InvalidEncryptionInfo(msg="invalid \{name} value")
  }
}

///|
fn parse_bytes_attr(tag : StringView, name : String) -> Bytes raise XlsxError {
  let text = parse_required_attr(tag, name)
  base64_decode(text)
}

///|
fn tag_attributes(
  xml : StringView,
  tag_name : StringView,
) -> String? raise XlsxError {
  let xml_str = xml.to_owned()
  let needle = "<" + tag_name.to_owned()
  match xml_str.find(needle) {
    None => None
    Some(start) => {
      let rest = xml_str[start + needle.length():]
      let end = match rest.find(">") {
        Some(pos) => pos
        None => raise InvalidEncryptionInfo(msg="tag not closed")
      }
      let tag = rest[:end]
      Some(tag.to_owned())
    }
  }
}

///|
fn parse_key_data(tag : StringView) -> KeyData raise XlsxError {
  {
    salt_size: parse_int_attr(tag, "saltSize"),
    block_size: parse_int_attr(tag, "blockSize"),
    key_bits: parse_int_attr(tag, "keyBits"),
    hash_size: parse_int_attr(tag, "hashSize"),
    cipher_algorithm: parse_required_attr(tag, "cipherAlgorithm"),
    cipher_chaining: parse_required_attr(tag, "cipherChaining"),
    hash_algorithm: parse_required_attr(tag, "hashAlgorithm"),
    salt_value: parse_bytes_attr(tag, "saltValue"),
  }
}

///|
fn parse_data_integrity(tag : StringView) -> DataIntegrity raise XlsxError {
  {
    encrypted_hmac_key: parse_bytes_attr(tag, "encryptedHmacKey"),
    encrypted_hmac_value: parse_bytes_attr(tag, "encryptedHmacValue"),
  }
}

///|
fn parse_encrypted_key(tag : StringView) -> EncryptedKey raise XlsxError {
  {
    spin_count: parse_int_attr(tag, "spinCount"),
    key_data: parse_key_data(tag),
    encrypted_verifier_hash_input: parse_bytes_attr(
      tag, "encryptedVerifierHashInput",
    ),
    encrypted_verifier_hash_value: parse_bytes_attr(
      tag, "encryptedVerifierHashValue",
    ),
    encrypted_key_value: parse_bytes_attr(tag, "encryptedKeyValue"),
  }
}

///|
fn parse_encryption_info(xml : StringView) -> EncryptionInfo raise XlsxError {
  let key_data_tag = match tag_attributes(xml, "keyData") {
    Some(value) => value
    None => raise InvalidEncryptionInfo(msg="keyData tag missing")
  }
  let encrypted_key_tag = match tag_attributes(xml, "p:encryptedKey") {
    Some(value) => value
    None =>
      match tag_attributes(xml, "encryptedKey") {
        Some(value) => value
        None => raise InvalidEncryptionInfo(msg="encryptedKey tag missing")
      }
  }
  let data_integrity_tag = tag_attributes(xml, "dataIntegrity")
  {
    key_data: parse_key_data(key_data_tag),
    data_integrity: match data_integrity_tag {
      Some(value) => Some(parse_data_integrity(value))
      None => None
    },
    encrypted_key: parse_encrypted_key(encrypted_key_tag),
  }
}

///|
fn validate_key_data(key_data : KeyData) -> Unit raise XlsxError {
  if key_data.salt_value.length() != key_data.salt_size {
    raise InvalidEncryptionInfo(msg="salt size mismatch")
  }
  let hash = hash_parts(key_data.hash_algorithm, [Bytes::default()])
  if hash.length() != key_data.hash_size {
    raise InvalidEncryptionInfo(msg="hash size mismatch")
  }
}

///|
fn validate_encryption_info(
  encryption : EncryptionInfo,
) -> Unit raise XlsxError {
  validate_key_data(encryption.key_data)
  validate_key_data(encryption.encrypted_key.key_data)
  if encryption.encrypted_key.encrypted_verifier_hash_input.length() == 0 ||
    encryption.encrypted_key.encrypted_verifier_hash_value.length() == 0 {
    raise InvalidEncryptionInfo(msg="verifier data missing")
  }
  match encryption.data_integrity {
    Some(value) =>
      if value.encrypted_hmac_key.length() == 0 ||
        value.encrypted_hmac_value.length() == 0 {
        raise InvalidEncryptionInfo(msg="hmac data missing")
      }
    None => ()
  }
}

///|
fn is_aes_cipher(key_data : KeyData) -> Bool {
  key_data.cipher_algorithm.to_lower() == "aes" &&
  key_data.cipher_chaining.to_lower().contains("cbc") &&
  key_data.block_size == 16
}

///|
fn encryption_mechanism(
  info : BytesView,
) -> EncryptionMechanism raise XlsxError {
  if info.length() < 4 {
    raise InvalidEncryptionInfo(msg="invalid encryption info")
  }
  let major = read_u16_le(info, 0)
  let minor = read_u16_le(info, 2)
  if major == 4 && minor == 4 {
    Agile
  } else if major >= 2 && major <= 4 && minor == 2 {
    Standard
  } else if (major == 3 || major == 4) && minor == 3 {
    raise UnsupportedEncryption(msg="unsupported extensible encryption")
  } else {
    raise UnsupportedEncryption(msg="unknown encryption mechanism")
  }
}

///|
fn derive_password_hash(
  password : String,
  encryption : EncryptionInfo,
) -> Bytes raise XlsxError {
  let key_data = encryption.encrypted_key.key_data
  let salt_value = key_data.salt_value
  let password_bytes = @encoding/utf16.encode(
    password,
    bom=false,
    endianness=Little,
  )
  let mut key = hash_parts(key_data.hash_algorithm, [salt_value, password_bytes])
  for i in 0..<encryption.encrypted_key.spin_count {
    let iterator = u32_le_bytes(i)
    key = hash_parts(key_data.hash_algorithm, [iterator, key])
  }
  key
}

///|
fn derive_password_key_from_hash(
  password_hash : BytesView,
  block : BytesView,
  encryption : EncryptionInfo,
) -> Bytes raise XlsxError {
  let key_data = encryption.encrypted_key.key_data
  let key = hash_parts(key_data.hash_algorithm, [password_hash, block])
  let key_bytes = key_data.key_bits / 8
  if key.length() < key_bytes {
    let out : Array[Byte] = key.to_array()
    while out.length() < key_bytes {
      out.push((0x36).to_byte())
    }
    Bytes::from_array(out)
  } else if key.length() > key_bytes {
    key[:key_bytes].to_owned()
  } else {
    key
  }
}

///|
fn agile_verify_password(
  password_hash : BytesView,
  encryption : EncryptionInfo,
) -> Bool raise XlsxError {
  let key_data = encryption.encrypted_key.key_data
  let salt = key_data.salt_value
  let input_key = derive_password_key_from_hash(
    password_hash, verifier_hash_input_block_key, encryption,
  )
  let value_key = derive_password_key_from_hash(
    password_hash, verifier_hash_value_block_key, encryption,
  )
  let verifier_input = aes_cbc_decrypt(
    input_key,
    salt,
    encryption.encrypted_key.encrypted_verifier_hash_input,
  )
  let verifier_hash_value = aes_cbc_decrypt(
    value_key,
    salt,
    encryption.encrypted_key.encrypted_verifier_hash_value,
  )
  let expected_hash = hash_parts(key_data.hash_algorithm, [verifier_input])
  let hash_size = key_data.hash_size
  let size = if hash_size < expected_hash.length() {
    hash_size
  } else {
    expected_hash.length()
  }
  expected_hash[:size].equal(verifier_hash_value[:size])
}

///|
fn create_iv_from_block(
  block : BytesView,
  encryption : EncryptionInfo,
) -> Bytes raise XlsxError {
  let salt = encryption.key_data.salt_value
  let mut iv = hash_parts(encryption.key_data.hash_algorithm, [salt, block])
  let block_size = encryption.key_data.block_size
  if iv.length() < block_size {
    let out : Array[Byte] = iv.to_array()
    while out.length() < block_size {
      out.push((0x36).to_byte())
    }
    iv = Bytes::from_array(out)
  } else if iv.length() > block_size {
    iv = iv[:block_size].to_owned()
  }
  iv
}

///|
fn create_iv(
  block_index : Int,
  encryption : EncryptionInfo,
) -> Bytes raise XlsxError {
  let block_bytes = u32_le_bytes(block_index)
  create_iv_from_block(block_bytes, encryption)
}

///|
fn decrypt_package(
  package_key : BytesView,
  input : BytesView,
  encryption : EncryptionInfo,
) -> Bytes raise XlsxError {
  let payload : BytesView = if input.length() > package_offset {
    input[package_offset:]
  } else {
    Bytes::default()
  }
  let out : Array[Byte] = []
  let mut offset = 0
  let mut index = 0
  while offset < payload.length() {
    let end = if offset + package_encryption_chunk_size < payload.length() {
      offset + package_encryption_chunk_size
    } else {
      payload.length()
    }
    let chunk = payload[offset:end]
    let padded = pad_zero(chunk, encryption.key_data.block_size)
    let iv = create_iv(index, encryption)
    let decrypted = aes_cbc_decrypt(package_key, iv, padded)
    out.append(decrypted.to_array())
    offset = end
    index = index + 1
  }
  if input.length() >= 8 {
    let raw_size = @crypto.u64_from_le(input, 0).to_int()
    if raw_size >= 0 && raw_size <= out.length() {
      out.truncate(raw_size)
    }
  }
  Bytes::from_array(out)
}

///|
fn agile_decrypt(
  encryption_info_buf : BytesView,
  encrypted_package_buf : BytesView,
  password : String,
) -> Bytes raise XlsxError {
  let xml = @encoding/utf8.decode(encryption_info_buf) catch {
    _ => raise InvalidEncryptionInfo(msg="invalid encryption info xml")
  }
  let encryption = parse_encryption_info(xml)
  validate_encryption_info(encryption)
  if !is_aes_cipher(encryption.key_data) ||
    !is_aes_cipher(encryption.encrypted_key.key_data) {
    raise UnsupportedEncryption(msg="unsupported cipher settings")
  }
  let password_hash = derive_password_hash(password, encryption)
  let key = derive_password_key_from_hash(password_hash, block_key, encryption)
  let password_ok = agile_verify_password(password_hash, encryption)
  let salt = encryption.encrypted_key.key_data.salt_value
  let package_key = aes_cbc_decrypt(
    key,
    salt,
    encryption.encrypted_key.encrypted_key_value,
  )
  let decrypted = decrypt_package(
    package_key, encrypted_package_buf, encryption,
  )
  if !password_ok && !is_valid_zip(decrypted) {
    raise InvalidPassword
  }
  decrypted
}

///|
fn standard_convert_password_to_key(
  key_bits : Int,
  salt : BytesView,
  password : String,
) -> Bytes raise XlsxError {
  let password_bytes = @encoding/utf16.encode(
    password,
    bom=false,
    endianness=Little,
  )
  let mut key = hash_parts("sha1", [salt, password_bytes])
  for i in 0..<iter_count {
    let iterator = u32_le_bytes(i)
    key = hash_parts("sha1", [iterator, key])
  }
  let h_final = hash_parts("sha1", [key, u32_le_bytes(0)])
  let cb_required = key_bits / 8
  let cb_hash = 20
  let buf1 : Array[Byte] = Array::make(64, (0x36).to_byte())
  for i in 0..<cb_hash {
    buf1[i] = byte_xor(h_final[i], buf1[i])
  }
  let x1 = hash_parts("sha1", [Bytes::from_array(buf1)])
  let buf2 : Array[Byte] = Array::make(64, (0x5c).to_byte())
  for i in 0..<cb_hash {
    buf2[i] = byte_xor(h_final[i], buf2[i])
  }
  let x2 = hash_parts("sha1", [Bytes::from_array(buf2)])
  let combined : Array[Byte] = x1.to_array()
  combined.append(x2.to_array())
  let key_derived = combined[:cb_required].to_owned()
  Bytes::from_array(key_derived)
}

///|
fn standard_decrypt(
  encryption_info_buf : BytesView,
  encrypted_package_buf : BytesView,
  password : String,
) -> Bytes raise XlsxError {
  let header_size = read_u32_le(encryption_info_buf, 8).to_uint64().to_int()
  let header_block = encryption_info_buf[12:12 + header_size]
  let alg_id = @crypto.u32_from_le(header_block, 8)
  let key_bits = @crypto.u32_from_le(header_block, 16).to_uint64().to_int()
  let algorithm = match alg_id {
    0x0000_660e | 0x0000_660f | 0x0000_6610 => "AES"
    // Excelize treats any other AlgID as the RC4-style layout: the
    // verifier hash is 20 bytes instead of 32, but key derivation and
    // package decryption still run SHA-1 + AES-ECB (crypt.go
    // standardDecrypt/standardEncryptionVerifier).
    _ => "RC4"
  }
  let verifier_block = encryption_info_buf[12 + header_size:]
  // salt size (4) + salt (16) + encrypted verifier (16) +
  // verifier hash size (4) + encrypted verifier hash (20 or 32)
  let min_verifier_len = if algorithm == "RC4" { 60 } else { 72 }
  if verifier_block.length() < min_verifier_len {
    raise InvalidEncryptionInfo(msg="invalid verifier block")
  }
  let salt = verifier_block[4:4 + 16]
  let secret_key = standard_convert_password_to_key(key_bits, salt, password)
  let decrypted = aes_ecb_decrypt(secret_key, encrypted_package_buf[8:])
  if encrypted_package_buf.length() >= 8 {
    let raw_size = @crypto.u64_from_le(encrypted_package_buf, 0).to_int()
    if raw_size >= 0 && raw_size <= decrypted.length() {
      return decrypted[:raw_size].to_owned()
    }
  }
  decrypted
}

///|
fn is_encrypted_package(bytes : BytesView) -> Bool {
  if bytes.length() < 8 {
    return false
  }
  for i in 0..<=7 {
    if bytes[i] != ole_identifier[i] {
      return false
    }
  }
  true
}

///|
fn looks_like_zip(bytes : BytesView) -> Bool {
  bytes.length() >= 4 &&
  bytes[0] == b'P' &&
  bytes[1] == b'K' &&
  bytes[2] == 0x03 &&
  bytes[3] == 0x04
}

///|
fn is_valid_zip(bytes : BytesView) -> Bool {
  if !looks_like_zip(bytes) {
    return false
  }
  let result : Result[@zip.Archive, Error] = try? @zip.read(bytes)
  result is Ok(_)
}

///|
fn decrypt_encrypted_package(
  bytes : BytesView,
  password : String,
) -> Bytes raise XlsxError {
  let reader = cfb_read(bytes) catch {
    _ => raise InvalidEncryptedPackage(msg="invalid cfb package")
  }
  let encryption_info = reader.read_stream("EncryptionInfo") catch {
    _ => raise InvalidEncryptedPackage(msg="encryption info missing")
  }
  let encrypted_package = reader.read_stream("EncryptedPackage") catch {
    _ => raise InvalidEncryptedPackage(msg="encrypted package missing")
  }
  if encryption_info.length() < 8 {
    raise InvalidEncryptionInfo(msg="encryption info too short")
  }
  if encrypted_package.length() <= 8 {
    raise InvalidEncryptedPackage(msg="encrypted streams empty")
  }
  match encryption_mechanism(encryption_info) {
    Agile => agile_decrypt(encryption_info[8:], encrypted_package, password)
    Standard => standard_decrypt(encryption_info, encrypted_package, password)
  }
}

///|
fn standard_key_encryption(password : String) -> (Bytes, Bytes) raise XlsxError {
  let password_len = password.length()
  if password_len == 0 || password_len > max_password_length {
    raise InvalidPasswordLength(len=password_len)
  }
  let salt_value = random_bytes(16)
  let verifier_hash_input = random_bytes(16)
  let key_bits = 128
  let encrypted_key_value = standard_convert_password_to_key(
    key_bits, salt_value, password,
  )
  let verifier_hash_input_key = hash_parts("sha1", [verifier_hash_input])
  let encrypted_verifier_hash_input = aes_ecb_encrypt(
    encrypted_key_value, verifier_hash_input,
  )
  let encrypted_verifier_hash_value = aes_ecb_encrypt(
    encrypted_key_value,
    pad_zero(verifier_hash_input_key, 16),
  )
  let writer = ByteWriter::new()
  writer.write_u16_le(0x0003)
  writer.write_u16_le(0x0002)
  writer.write_u32_le(0x24)
  writer.write_u32_le(0xa4)
  writer.write_u32_le(0x24)
  writer.write_u32_le(0x00)
  writer.write_u32_le(0x660e)
  writer.write_u32_le(0x8004)
  writer.write_u32_le(0x80)
  writer.write_u32_le(0x18)
  writer.write_u64_le(0x00)
  writer.write_utf16le(
    "Microsoft Enhanced RSA and AES Cryptographic Provider (Prototype)",
  )
  writer.write_u16_le(0x00)
  writer.write_u32_le(0x10)
  writer.write_bytes(salt_value)
  writer.write_bytes(encrypted_verifier_hash_input)
  writer.write_u32_le(0x14)
  writer.write_bytes(encrypted_verifier_hash_value)
  (writer.to_bytes(), encrypted_key_value)
}

///|
fn encrypt_package(raw : BytesView, password : String) -> Bytes raise XlsxError {
  let (encryption_info, key) = standard_key_encryption(password)
  let raw_len = raw.length().to_uint64()
  let size_bytes = u64_le_bytes(raw_len)
  let encrypted = aes_ecb_encrypt(key, pad_zero(raw, 16))
  let encrypted_package : Array[Byte] = size_bytes.to_array()
  encrypted_package.append(encrypted.to_array())
  let builder = cfb_builder_new()
  builder.put("EncryptionInfo", encryption_info)
  builder.put("EncryptedPackage", Bytes::from_array(encrypted_package))
  builder.write()
}

///|
pub fn encrypt(
  raw : BytesView,
  options? : Options = Options::new(),
) -> Bytes raise XlsxError {
  encrypt_package(raw, options.password)
}

///|
pub fn decrypt(
  raw : BytesView,
  options? : Options = Options::new(),
) -> Bytes raise XlsxError {
  decrypt_encrypted_package(raw, options.password)
}
