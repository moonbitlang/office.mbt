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
let random_bytes_rng : Ref[@random.Rand?] = { val: None }

///|
/// Optional user-supplied source of cryptographically secure bytes.
let random_bytes_override : Ref[((Int) -> Bytes)?] = { val: None }

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
      let first = @crypto.hash_concat("sha256", [u64_le_bytes(@env.now()), tag])
      let seed = @crypto.hash_concat("sha256", [first, u64_le_bytes(@env.now())])
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
  let result : Result[@zip.Archive, Error] = Ok(@zip.read(bytes)) catch {
    e => Err(e)
  }
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

///|
fn bytes_to_hex(bytes : BytesView) -> String {
  let digits = "0123456789abcdef"
  let sb = StringBuilder::new()
  for b in bytes {
    let v = b.to_int()
    let hi = (v >> 4) & 0xf
    let lo = v & 0xf
    sb.write_char(digits.get_char(hi).unwrap_or('?'))
    sb.write_char(digits.get_char(lo).unwrap_or('?'))
  }
  sb.to_string()
}

///|
fn hex_value(ch : Char) -> Int raise XlsxError {
  if ch >= '0' && ch <= '9' {
    ch.to_int() - '0'.to_int()
  } else if ch >= 'a' && ch <= 'f' {
    ch.to_int() - 'a'.to_int() + 10
  } else if ch >= 'A' && ch <= 'F' {
    ch.to_int() - 'A'.to_int() + 10
  } else {
    raise InvalidBase64(msg="invalid hex")
  }
}

///|
fn hex_to_bytes(text : StringView) -> Bytes raise XlsxError {
  let out : Array[Byte] = Array::new(capacity=text.length() / 2)
  let mut pending_hi : Int? = None
  for ch in text {
    let v = hex_value(ch)
    match pending_hi {
      None => pending_hi = Some(v)
      Some(hi) => {
        out.push(((hi << 4) | v).to_byte())
        pending_hi = None
      }
    }
  }
  if pending_hi is Some(_) {
    raise InvalidBase64(msg="invalid hex length")
  }
  Bytes::from_array(out)
}

///|
test "base64 encode/decode" {
  let input = @encoding/utf8.encode("hello")
  inspect(base64_encode(input), content="aGVsbG8=")
  let decoded = base64_decode("aGVsbG8=")
  inspect(@encoding/utf8.decode(decoded), content="hello")
  let result : Result[Bytes, Error] = Ok(base64_decode("!!")) catch {
    e => Err(e)
  }
  inspect(result is Err(XlsxError::InvalidBase64(_)), content="true")
}

///|
test "hash vectors" {
  let data = @encoding/utf8.encode("abc")
  inspect(
    bytes_to_hex(@crypto.hash_concat("md4", [data])),
    content="a448017aaf21d8525fc10ae87aa6729d",
  )
  inspect(
    bytes_to_hex(@crypto.hash_concat("md5", [data])),
    content="900150983cd24fb0d6963f7d28e17f72",
  )
  inspect(
    bytes_to_hex(@crypto.hash_concat("sha1", [data])),
    content="a9993e364706816aba3e25717850c26c9cd0d89d",
  )
  inspect(
    bytes_to_hex(@crypto.hash_concat("sha1", [Bytes::default()])),
    content="da39a3ee5e6b4b0d3255bfef95601890afd80709",
  )
  inspect(
    bytes_to_hex(
      @crypto.hash_concat("sha1", [
        @encoding/utf8.encode(
          "abcdbcdecdefdefgefghfghighijhijkijkljklmnlmnomnopnopq",
        ),
      ]),
    ),
    content="967b4ca81ed24d3fad00dcd88994c4e380d1090a",
  )
  inspect(
    bytes_to_hex(
      @crypto.hash_concat("sha1", [
        @encoding/utf8.encode(String::repeat("a", 56)),
      ]),
    ),
    content="c2db330f6083854c99d4b5bfb6e8f29f201be699",
  )
  inspect(
    bytes_to_hex(@crypto.hash_concat("sha256", [data])),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
  let sha384_expected = String::add(
    "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed", "8086072ba1e7cc2358baeca134c825a7",
  )
  inspect(
    bytes_to_hex(@crypto.hash_concat("sha384", [data])),
    content=sha384_expected,
  )
  let sha512_expected = String::add(
    "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a", "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
  )
  inspect(
    bytes_to_hex(@crypto.hash_concat("sha512", [data])),
    content=sha512_expected,
  )
  inspect(
    bytes_to_hex(@crypto.hash_concat("ripemd-160", [data])),
    content="8eb208f7e05d987a9b044a8e98c6b087f15a0bfc",
  )
}

///|
test "aes block vectors" {
  let key = hex_to_bytes("000102030405060708090a0b0c0d0e0f")
  let plain = hex_to_bytes("00112233445566778899aabbccddeeff")
  let expected = "69c4e0d86a7b0430d8cdb78070b4c55a"
  let enc = aes_ecb_encrypt(key, plain)
  inspect(bytes_to_hex(enc), content=expected)
  let dec = aes_ecb_decrypt(key, enc)
  inspect(bytes_to_hex(dec), content="00112233445566778899aabbccddeeff")
}

///|
test "aes cbc decrypt vector" {
  let key = hex_to_bytes("2b7e151628aed2a6abf7158809cf4f3c")
  let iv = hex_to_bytes("000102030405060708090a0b0c0d0e0f")
  let enc = hex_to_bytes(
    String::add(
      "7649abac8119b246cee98e9b12e9197d", "5086cb9b507219ee95db113a917678b2",
    ),
  )
  let dec = aes_cbc_decrypt(key, iv, enc)
  let expected = String::add(
    "6bc1bee22e409f96e93d7e117393172a", "ae2d8a571e03ac9c9eb76fac45af8e51",
  )
  inspect(bytes_to_hex(dec), content=expected)
}

///|
test "cfb roundtrip" {
  let builder = cfb_builder_new()
  builder.put("EncryptionInfo", @encoding/utf8.encode("info"))
  builder.put("EncryptedPackage", @encoding/utf8.encode("package"))
  let bytes = builder.write()
  let reader = cfb_read(bytes)
  let info = reader.read_stream("EncryptionInfo")
  let encrypted = reader.read_stream("EncryptedPackage")
  inspect(@encoding/utf8.decode(info), content="info")
  inspect(@encoding/utf8.decode(encrypted), content="package")
}

///|
test "random_bytes draws differ across calls and runs are seeded" {
  let a = random_bytes(16)
  let b = random_bytes(16)
  inspect(a.length(), content="16")
  inspect(b.length(), content="16")
  // consecutive draws from the stateful generator must differ
  inspect(a == b, content="false")
  // and must not reproduce ChaCha8's fixed default-seed stream
  let default_rng = @random.Rand::chacha8()
  let default_stream : Array[Byte] = Array::make(16, (0).to_byte())
  for i in 0..<16 {
    default_stream[i] = default_rng.int(limit=256).to_byte()
  }
  inspect(a == Bytes::from_array(default_stream), content="false")
}

///|
test "set_random_source overrides random_bytes" {
  set_random_source(count => {
    let out : Array[Byte] = Array::make(count, (0x5a).to_byte())
    Bytes::from_array(out)
  })
  let fixed = random_bytes(4)
  // restore the built-in generator before other tests observe the override
  random_bytes_override.val = None
  debug_inspect(
    fixed,
    content=(
      #|<Bytes: [0x5a, 0x5a, 0x5a, 0x5a]>
    ),
  )
  inspect(random_bytes(4) == fixed, content="false")
}

///|
fn decode_base64_multiline(text : StringView) -> Bytes raise XlsxError {
  let compact = text.to_owned().replace_all(old="\n", new="")
  base64_decode(compact)
}

///|
let encrypt_sha1_b64 =
  #|0M8R4KGxGuEAAAAAAAAAAAAAAAAAAAAAPgADAP7/CQAGAAAAAAAAAAAAAAADAAAAAQAAAAAAAAAAEAAA
  #|AgAAAAEAAAD+////AAAAAAAAAAAHAAAACAAAAP//////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|///////////////////////////////////////////9////BAAAAP7///8GAAAABQAAAP7///8ZAAAA
  #|/f////3///8KAAAACwAAAAwAAAANAAAADgAAAA8AAAAQAAAAEQAAABIAAAATAAAAFAAAABUAAAAWAAAA
  #|FwAAABgAAAD+////GgAAAP7/////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|/////1IAbwBvAHQAIABFAG4AdAByAHkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAWAAUA//////////8KAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAODbfLh1f9YB
  #|AwAAAIAGAAAAAAAARQBuAGMAcgB5AHAAdABlAGQAUABhAGMAawBhAGcAZQAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAACIAAgD///////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAJAAAAmB4AAAAAAAAGAEQAYQB0AGEAUwBwAGEAYwBlAHMAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGAABAP//////////BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|8CB4uHV/1gHganq4dX/WAQAAAAAAAAAAAAAAAFYAZQByAHMAaQBvAG4AAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAIB////////////////AAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEwAAAAAAAAAAQAAAP7///8DAAAA/v////7///8GAAAA
  #|BwAAAAgAAAD+////CgAAAAsAAAAMAAAADQAAAA4AAAAPAAAAEAAAABEAAAASAAAAEwAAABQAAAAVAAAA
  #|FgAAABcAAAAYAAAAGQAAAP7/////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|//////////88AAAATQBpAGMAcgBvAHMAbwBmAHQALgBDAG8AbgB0AGEAaQBuAGUAcgAuAEQAYQB0AGEA
  #|UwBwAGEAYwBlAHMAAQAAAAEAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAgAAAABAAAAaAAAAAEAAAAAAAAAIAAAAEUAbgBjAHIAeQBwAHQAZQBkAFAA
  #|YQBjAGsAYQBnAGUAMgAAAFMAdAByAG8AbgBnAEUAbgBjAHIAeQBwAHQAaQBvAG4ARABhAHQAYQBTAHAA
  #|YQBjAGUAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAEAAAAyAAAAUwB0AHIAbwBuAGcARQBuAGMAcgB5AHAA
  #|dABpAG8AbgBUAHIAYQBuAHMAZgBvAHIAbQAAAFgAAAABAAAATAAAAHsARgBGADkAQQAzAEYAMAAzAC0A
  #|NQA2AEUARgAtADQANgAxADMALQBCAEQARAA1AC0ANQBBADQAMQBDADEARAAwADcAMgA0ADYAfQBOAAAA
  #|TQBpAGMAcgBvAHMAbwBmAHQALgBDAG8AbgB0AGEAaQBuAGUAcgAuAEUAbgBjAHIAeQBwAHQAaQBvAG4A
  #|VAByAGEAbgBzAGYAbwByAG0AAAABAAAAAQAAAAEAAAAAAAAAAAAAAEQAYQB0AGEAUwBwAGEAYwBlAE0A
  #|YQBwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAaAAIBAwAAAAUAAAD/////
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAHAAAAAAAAAARABhAHQAYQBTAHAA
  #|YQBjAGUASQBuAGYAbwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABwAAQH/////
  #|BwAAAAYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOBqerh1f9YB4Gp6uHV/1gEAAAAAAAAAAAAAAABTAHQA
  #|cgBvAG4AZwBFAG4AYwByAHkAcAB0AGkAbwBuAEQAYQB0AGEAUwBwAGEAYwBlAAAAAAAAAAAAAAAAAAAA
  #|NAACAf///////////////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAABAAAAA
  #|AAAAAFQAcgBhAG4AcwBmAG8AcgBtAEkAbgBmAG8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAcAAEA//////////8IAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADganq4dX/WAeBqerh1f9YB
  #|AAAAAAAAAAAAAAAAUwB0AHIAbwBuAGcARQBuAGMAcgB5AHAAdABpAG8AbgBUAHIAYQBuAHMAZgBvAHIA
  #|bQAAAAAAAAAAAAAAAAAAADQAAQH//////////wkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOBqerh1f9YB
  #|4Gp6uHV/1gEAAAAAAAAAAAAAAAAGAFAAcgBpAG0AYQByAHkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEgACAf///////////////wAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAUAAADIAAAAAAAAAEUAbgBjAHIAeQBwAHQAaQBvAG4ASQBuAGYAbwAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAeAAIBAgAAAAEAAAD/////AAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACQAAACEEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD///////////////8AAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAEAEAAAAA8P3ht
  #|bCB2ZXJzaW9uPSIxLjAiIGVuY29kaW5nPSJVVEYtOCIgc3RhbmRhbG9uZT0ieWVzIj8+DQo8ZW5jcnlw
  #|dGlvbiB4bWxucz0iaHR0cDovL3NjaGVtYXMubWljcm9zb2Z0LmNvbS9vZmZpY2UvMjAwNi9lbmNyeXB0
  #|aW9uIiB4bWxuczpwPSJodHRwOi8vc2NoZW1hcy5taWNyb3NvZnQuY29tL29mZmljZS8yMDA2L2tleUVu
  #|Y3J5cHRvci9wYXNzd29yZCI+PGtleURhdGEgc2FsdFNpemU9IjE2IiBibG9ja1NpemU9IjE2IiBrZXlC
  #|aXRzPSIxMjgiIGhhc2hTaXplPSIyMCIgY2lwaGVyQWxnb3JpdGhtPSJBRVMiIGNpcGhlckNoYWluaW5n
  #|PSJDaGFpbmluZ01vZGVDQkMiIGhhc2hBbGdvcml0aG09IlNIQTEiIHNhbHRWYWx1ZT0iazJnUjdQa2pz
  #|WXZKNGFreGJTa1pSdz09Ii8+PGRhdGFJbnRlZ3JpdHkgZW5jcnlwdGVkSG1hY0tleT0iaWIxZzNIV01T
  #|dWVkU1cxbEJkeml3c1NST///////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|//////////////////////////+DHgAAAAAAABUGNYtOhqc4yUj9wgYGQV42fwvbcRbwK4nLn31yN8Yg
  #|bJEmSxo4acfo+RyD7TYTd+q2jjGAujGOHhxO6+8MXyeT77kbpNQajlHGgCnLpJ9t3F/vrQWlIcm62ONk
  #|ajmo8jSl5LZnSLB2Z8SSdlzwcPpZI2+l9P2wyBYLQPuqHwsb+KPhBHZMu6xYoYp6hvTelNV/nKrZ3ZJH
  #|onvzr3xY5dAi53ZxP6yyQm1xFmTcSOCCKNhTCXxrC+RafEt4fWFwp60R5OmVujOiYSAs9R/FFSunXVfr
  #|2yBy4DSJVqnopDYC1nV7JXY2yR1ImtgQA/pEL9x1P9g71NCDJ3CCqtWJvxjNnhNy6vVv8fYZStfS3y5w
  #|KsbtEfulmrJJCrf1eR4HGrBOzbYmep0WJMGMIeAGt68u5reuzDNte2aX8Lgb6Gf7cSM6gI0yDNstrcEQ
  #|mzdLgXiCv6ROMyY1YDZl9a7PjKc0W+099YXC/iu8zff6WQunfpxdWVryr7aIRlNY3hYTbyiOwp8shv9B
  #|L9lIXUw2+XgYdYRVXuuC6ITadtiXC1eHYrDClhxi5vyFlx/BdYGA6QoeWoY4Z/6NhsiES+ybuer1Zuia
  #|+hyC5o0Ap+rrxTQFMLwnBz1nIujXHTMnlqAPWVGOAcjxr6n/7TMyaGI7rXm975Qkd9CZNjLB799zXsG0
  #|V85nf7M/MEexFUTpT6c7X8S2HARcmC5AfdsQeu3w9LsuMXm8kXw0E2EA9NCCyPD0TLrQagxhwfoUsh2c
  #|/Gx+t6/P5M/+X02vviXpPIckZT03kR6ejTGQZu+uzAErqvF4Jdp62LGteZ7hHvqEjyYStrJSH4gtlt/k
  #|NErxszSWhjzlByftoIUa4Jv6mB7ba/0k+im5GbXTo5EXd/gNyLvmCrchR939AbgpYYSRQWQt1rZzzpYH
  #|/k0P1+kibb4BMmbyZqyym4QVCOd25pLpgrtGrtMRHj0NoqIx8gDjblU/m/tfW3i+RbiIqxToObE2tjbJ
  #|GmgqOHjba5jo8seGomvHZqGRegWqE1MZTUNnVsVsjb1+chh33ny+aCc3LzdYyqyeJjo4teXCjeGOISo1
  #|lPu53UAwPe+t2UeKHeQ6UKCyQuRVzk73k8KSSjaeg7PdAyFwBXz/JXRXgAWW/OBeqJuzmJwQigP95Nnf
  #|L0HT9CKy5cD1V35GPFTK1exfAbqrzS8ENDFQAUOmKepLWHZgAkauPp9SYX1eaztLbtOWk55TOtkt3Fq/
  #|ILkE4+8MKyoc3fA4hs3RV/wmhRF/UHfKzAd82hU7+/Tnz8Gd92upTws2Czv5mrc3V1XJB1ZAiNpoS+5U
  #|8BgLgeDbA0LJTYD/YfO+Rv+J2E28FZNeItrcFHA0nTjqXave2HJFiUP1iba8rYweiotoEPeqzkeww+io
  #|dMfksyDLLCCBXu3i7ECLj5yihX1ZZi4J42ZVTvXnvjyqOujcjsdpJGgw0tkCY9PJOltb4Yqui4l4ybyK
  #|Wu1YqPoRGLTs0DpSlbW82MyQfjcqyikIl6+2bmC9SwADzA8DOgF17FWhYzCm7mqim7MwG4geWmZ2p32T
  #|7QhNYGCZLsLQ8LrcoN1+HYEJsfZkkHy5e4EfXetMpJz7ItlPwnBJr3ieUmmBZmAOKg1pRUlX9mi2HO9t
  #|+TUG8arqaZEWIMMiMIVL/kto1nIvOW1XBW6jhtuH2kJpVYV467xlgfzVH+ewuWVespo6hu1IvmlvCyCF
  #|Luk4xz6k13bNDp1hDEOs94evCq0ehNv+S7rQG+Oq1dW3QtjtRhVIFjqxrOkhROsFnOa7RmbCyZ+5ZS67
  #|NH2N6oV8gyb1vRNfzR9IkEH/pGpbpXewYnymKGDsQoc+o8i3RU8/+1bruiFZDbHsyfs2raT3234wS64L
  #|vAWTmu4LOGGtyjUd4rD+a+DpQtj5X8LS7OOcIoVmatR/WPQcPM2Cs+q39yq3u/YiRlqtIXL+P8mpxpwm
  #|rRMl5MYoIcbv7jbF8a1Ab0rbkymxXgfT2qCO5NE9a76RehgWiy1RtHokFsnhM7nVNCtjxgtQq52h7H5h
  #|j4QcCTlpQ2KafEzwrtk7KjGoxpyBxsmHIuA6ZHHw/ZeiSCWlR4QkZhd1L8dUbiH08KNkRUc8msguqcld
  #|GVBqWlfv0M6CdF0MmU1RGRbN17c6m5GZPJM3ii6pkfc8WRHxJhkdORmuTmeqqPXdXgAdgFRZTBsivPHT
  #|cvIOv39Df9/V42jOS3WuQbOTzAfMA17U4rhq616iz9qpaskbbPYUyUdJmLMO3c0QREltvcof1YNZnOOl
  #|XeBc5J5RRsNamALNpqQKllwirhwH/VJYxB6lthQY7t0nr/3LeDXLxob0HXjXz8D58Wmxm3Xb0tSI3AiG
  #|ZDOLBuV8iE1LGS+nVhuqcdS9Rl4ssRfcgIAgytlwEbRxmiUuQmPLHr3zIFppGJAuO711B03FEBZQq6iD
  #|/I7OguswbSm72/rFccSZ+zb5RUH7LSHn+fuYerjuI3vP1tO8Xd6Mxdja8ceatmK+mHYnx6OCNk2zizKN
  #|hD6YuGBh834jEIUQpSRAzTmK7MdYZZW8Mvn9viEkrt9owO5C9rHwewlNKKVDzVWM6PHV2r6z6sEiAy/l
  #|yJ1PQ7mu2Kz9R1Vn2YYECHqSm0YfLSkERZiv7tBM2dhn6WKYWRSQqhCPz/upxB6i127CeK4mHe3VkfZN
  #|5SgjDfa1ZCLVn43bL+JLYe3HZZnp2NFKizCIxTNYFc+oa3DYk+q7N8v44FuT1MSaWpERGRtibUr2jZ3K
  #|IuICXlQOVNxzvTKDmgJfyU/OUr8Jov+n5Bp5kG44G5rFYvSJ2zfWIBdZ89GIHcc0xUTB117kFGC2RuEf
  #|MLkT+qAMti+0Z2tPAvQE3fC0uOj+kQvguf+GRrjd2m8GuWXd5/9ZRf0v0W3gktsgjYnGSCWwJ0CRsAmp
  #|i93K2pajGVWZkecMnaZTLhxGKfo5BrIo8oEZSMJ5IOXSCQdcErPifrwIVUvHF3xIiKBEXG8o4zl1YeUr
  #|ICJCEQaXR6ocNNi4Eti4VyQbF5yssK/7ksDa0+bk2z9ncTYzjy09b4NOxxOuKo+7/l6s8h2B296CFUMT
  #|W8Nznx5tokZKm5FpuzR//weZU+F+K0m2wP+zOjrnKPczS9e+0Epvpz7XPz1pNaFlsMgwCtgosvUzs+cc
  #|UoodGy6/nXQxGigbQbwrby/2CFQt91oQqq4jz+ijcvCWid+hwvADqWzM2PgE7iFefdbB5Uj8nkmTtf6J
  #|O4gZAbeDLsOsgl3SbkiOM1+Y73YdLs8Am3K9lYC0B1mrUIrmfKwPhUs+OYxzDFdYSFwA3e4bH2EjgeUI
  #|948XSelibyfiT97kP/0vsrXgf1PPINeZm5q5u4pnI95olDYIBThix7kkLpb9SO2AtbVgVtTVS6spC8Js
  #|5cYN9lei28O6aDQx/W5pgJXQQhKom2sQUtENWQjY6J+F3XS+RjUvkRnR4gwasSr53SlR1buco3sqCrpx
  #|AZnJb1vMS/7JkmYCTz2Hibsr4LsVH255eEGkddHwV5PnKtLZ/Sic//pQS3fzLgzcv5fcCQuNFuXpu7cn
  #|oo0EmLkZa1GWH4Sotpc6zPxDHsdDSV/GldCq/dayS3VAsT+zZDEdxJIvUareocqzi9sTiW1QpPTaa3sW
  #|+43L9F34pzk5MIxlOJxaA0oY7HI2yRKSXnnbUbzPoVyfzZ6I8lS/M4iAyIvd74rhvYU68Jouqz/tBuqe
  #|PhJys2ylte7BFk4MIl44Blh9zCtBxgz2xJOWApEOoGVF0nCJjRA5SC50lHMX9lil8sHXXCXVVqO4lA2o
  #|1LCWY/ONguOJvnCrMiK/NQBHgDv5RXqmf7lOnoZ+QZB/rvd3EHq5CipTy9tX76HKIzWe49fx/F0LXQAT
  #|scWYCEItUEVo/tTjOgQDfgQSXmww7b570i6zj91jhmOuuNMpQp6grye20yqE4PTpSF9R72+Es2nTpBKE
  #|pNoo3bkFgwAGnEToN6YlbOtgIDNlhyDyqsc/TwHgaMUUkFQiFJkABpMpUDczhFx6NZhY6Txk3GLnHD3C
  #|Rf6kYMrpMSqoWb1rbJ/k6j+tUtXqDVCgo/GjPp2GbX2UTC93bT78UF7Vn1Yb/vjldk/qwVhkQmT8dkdi
  #|QofCPd/MqBxHSgaafTkwikqeJYiDi91mCqMdylzyEbzxW881//xcmJ37Q2FxkQ2BcnG3Y/H6qjUygLJU
  #|WC2UH7NfhDuvOaZCPBx5hQSmfHAgX+fiRXbEJNYuvqTi4qX6r5SXRpkOBB/YTBYoyizXFZxowxlOO/FY
  #|+afsvPw3ppxNgUxX8JvPTi0g5+M11jQdweU/lG5g5NC5iDPDmlmNDXyHTUHyTyF0+ljXTH8A/VFIbT07
  #|CqzUEsvwLm98QqzbC2NPHQ1WBUkJUe93m0/0JMaX/x2xNr6d5rbTx/NrmhR8YNMjyuHa9sdeyLfk9vzJ
  #|/RChbf3QGlNUdBR+VJYWwIFfdqXf3jHkw/rT+FhLLbSIo8Y7O4AlSPz5jSiv6xXRFL3i3XBukNS6RWFE
  #|9X7pHJ9IqI+yZBkd0QzC4atf/EoY5O76X+aJopG++/hi3C1eHSVIfzEfcUeNwKpBoam2ptVhnlXNBw8a
  #|v42nkgPxb7O+ka8PgR9R21Vb9XIlFjf1IsqMKua+ZfCBjXLmIkRD21SUujQoXbuAggVGbiXYcg7ewBB8
  #|EbrmDjgrRZd/rJqmr8JF3CKTeNJtqbZ5QDn5AmFwC9IAMZmZtHpdAZbrXzsEI+03NEoIXEqG7C1L+rNC
  #|cd8EgHE0Z1WCzVadzjx8RwyN7UUQ9TtbSE61N1qq66sKXYCYFVBnOicbZDblXE8UUewfHuNBrY4iyKpF
  #|6iv1Qh6A/boY9iWEYwEF5cGwbON2Ou64OfY8Y1m4zy9K5cjYzko697hzpwLdMaBLSLQFASMoWjxbUuFU
  #|QnJ5+D5IVSDmqB6dCe+cVHfHn1WDf0wrWtDS6hYSskhe+mn7VJfQpNiGzvqn5nX02KRwh/V+JwHq+pft
  #|bCg2pE9Epz2Ok7rX6Ng5aEe28RDqjhKqlPpudq9wT+9tsYoFAjEAkHmWtzRmZGwigDFdWhWsulAfRXTD
  #|yktq+lBKA1d8QvuKyZJKdVFPZpm5FAEjJCns7xjKh08DSzQAGcmvLrY70IyCUKI26RHxJkUExf2KIYtU
  #|cRq/ra9bDTvLynCeFZSFThI35Kx2lo2BF8tuiDjOiScR8QKU6+Y+oTYYkzgpGgXbPokLXUgdcH+fpqjC
  #|eL5zao+qRM2kmyu6cCtfg6QBYiDEZXBTcBF6yvgNc++8QUpuJYYbOccIxw28Sl8cr2rp+uv1uq36w4QH
  #|GhMIZsfN6o5m3MDNS4bvvJmP8rhLiqQ6NSCWCmFtY6ai34dpcveOPw2YHmgglHw8cEx9N48Jsdx7Jb8w
  #|E6DJsU2sYnn53nHFM3LugCQRBVEOcWB2EWESMLHEFkMP/T6ep3iuz9LjqnmLEqbyP/deTVXYTMWUSCW5
  #|Clm3lMBw1bGR/iAbpzMBWdXu9L8/WS1dfbqHy9dD60BHypVwXn+aTGWv0/MXerFKobAeTx3NASN15fjr
  #|0dQrl6jl2Oe7Pt9KxP+uoAyXt5+RlWa2049iIB8WRxyca9ZqHsdKP4PTh+RksO3RXdQiar8kFEbxUfZ0
  #|/lzrj8dniRFzgQfOtU6wCDoFgULc+ac51MXkmzwpRDJQzH7FzIYoXyHeM8bIyp+V9n9+CsingDM5CIOd
  #|2d8Cz213A+4ak5YFpnWZGn/a8zC214GQGftms0FRmYiEOn02ev4uzd5l+lWVM7rZ/l5W9aEW0/1jBoBC
  #|yDXbcZ9LZO+bQy/315Zg1RadyFvsMgnZxJHXzdsAXgsaHanx5DflsN6gXUxzeha1B4jbN5NOHCONIbOw
  #|MgmmjuVh7t8nghP/9YKsh/nRxsrDae+DmtOpJbqGuW+iu3AgxNaFL/tvJR2q3g9mwunQgrrzIV7iw1pZ
  #|gPHNEVsRn7quXPEa7FWoVs8Djv2lO3i/wlolKLCzdh1Lyy9fFHAPLFU4qpjuUR/NAVpnlqJlLqtiQIYc
  #|JG9ycFzIAa/+8wbuO2tWrWmGN+6XEI43sLjjNDsmQUgny5McYgxQ56vY/Cig3TMeiwQ5Sw80zgi3UXXa
  #|JaIfuvIM7PGqGmAFwtf6rtJsiCvVJSzr1YRlq2cmAdajHU5296CFmYat8nk6MQa1i6bUAlWONSuR7nUC
  #|+yuAcoNBpANBlUT6oomDTf2RYM36gcjOYZpvaJuXo2T+LAlC0cWv3AE+uREWeJtw8G8sXzWyJlBRXCP3
  #|rhL2MGUfWtggAXHn4M+j9DQbvqEA+qG4MrViFturYY3+9cRWDKwiABWYvsdHVtCpttSF2TM9s+WPlDP5
  #|708irzhEomciYSCMhkibLOcoSDyl6m2vJS+q1SUZLEDHHHmU3kyAOPf6GRiEfnFm+0/c/jd6iFTTVBea
  #|zwTxnB6kclblCsdTu8orFh9c7oZqZH/11G71of93ZJzxN+0kJoH+g1ArxS4gBHyEORdK+3XC4aB5xPyq
  #|hY4BJj8qYWjMYWQvllD/QZEofMkKo/EbRoUK7Zx9uUU3YetohYRBRtAwEnLb27AMUyijaTydOMDKM1Oi
  #|39K55K7XTNQNQQw2cZLNx4lppHSPvkKsbZwH3PjjlobXol45FxsczYwwdqd+68NuHQJr24vIcXgfIJ3X
  #|F9jeEZYAOJ1ZIEroalv/6XqADcR8+QeW9PJdjZGN1LIe0KKaWoX6T73TyF9rKQjf0sSm3W2JgMzUwydS
  #|wEcVEmwza/8QkqsaaFP25EBsYGHOYxupKTDdqpDem1dfbErzbmOhHaFjG9Nd+Ojz4urVxjUoDM14SoCX
  #|k+9H75oBsaFvBb3EaciYWQAC3e6nagjXofsnVkqOCO1sxU+OhWHi5cwyS3TLWL6DRgKgebzVGlgHII1m
  #|WnYkERTE8HlzYJdbi3yCORDchWvqz0KFK21q/Po588MMQJimFbcpHTWSSl6c/gAYTRMKyURR5gdU8ta8
  #|u8PaLNyL6NpTqBqXjyfQXZNkAqHth6Ksp8kJyqqtfD1qnFroWy5D6DdgDZVw/8lJCDsS5VFwcAuJGNhH
  #|W32WiGwks14PmeVY1e8HpzFuKCRgdjvU1SFXR7y/JSbnKVQ21Qs+1dK13ZehIc6Rpb7CmX7IWiIMUss8
  #|h5ALuwmqb+JuF53rAj0DSmqBxw5EjqacCrANY6I1dRlBi8hOleDOKq88uR1U/va5Qfr0c2nnjk/AUe9N
  #|du4GjfDc8rk2U5A6MuHeswHlBPCVP2lIDcNa+fEr6gkbkzF4lzEZfTH9/AQ31t2YaZePb7cKEXdHmu+H
  #|UIS2bHBhDMVLvPDzg98QrRIrIAsn9+2XjZbCv2y+OzZuDz4QqjXpcxMgPQ2ee9OAK6VILqZm6ePBTrlr
  #|5V0wCabk7QvRr0DtdBkpzvO8+05FKtHKJjoWLo4NqfF3PrPgrI9OrjdN+miOIvhAAuWs51APbtp4m+QP
  #|/5RzZRVLXPp2VVTlsA4Lt3NXp6MWLzpQ8BhT4S1GobmU2/Vi07sxGKhyL2ipGI1j4cmLoFd1hf/Y6kSQ
  #|Jb4PhWWkyTm8g7fLj+9x+92rQbnxZsdXRKNGGFdZtM1OXkcnZy2wnAJmwPPJFZrzYgHdxaMMV5sTi93l
  #|QWLQ7v4kHrRVh/iRb5DPuNdXDWAQjAqxNpsBtPpbcbcxHHVPDMGIDwIwyixVKh9JAh1eiqjB8KPL9lCk
  #|VwA4A9tXBkq6/NopNViuqv/scDxD5IHDtljdJZZGdoZUFzydGdO4nfOUi8Csn1VYiqkyOSjJlq3iKjDI
  #|ReAGqSDXrNb8z6ktgnzUm08cB7epnyOWSM90sS7MCWVephxUPFFFrYc0zGK3yHKfUxnQPPW+887XrDA0
  #|JDQOu7mVbGJyjVZFI6Tx8zbL+9CmujfF0DBZpN0IEa61R8Suj1M68x6yQdMfvLZjrz1dSXglH6YVJFy3
  #|Z6pWEi5+73Bs9oMMt0U9cBfae1lXQG4d6goPRBLg4GbHrL2arZZTs9uLnCyl3ZNeXioRQu3pDgIbZpl7
  #|hkjDVgdXfEs2sZTy1i2leap6vYp4j74fUICd0VSVvP/sq0QrkjSqUtSqDoxdB+IfRYbz1E5RLMVbef0v
  #|rPdx9KBxI+ch0CUd3x8ik2w2IzO0JERGzbW/6IcwJ+GiBocEgKW5AFZhZHMpa7ag2gLB0GzmIb+a5Hrm
  #|zMHoNUUOjsW7vPOSWoQf8ts292YsRUKDUBFDlefFSDQiyV2kzPz2+U5CZBK60YnObwn59SlpvG62PfxU
  #|Goj9h9f7gV711c4sRuQPkB2oGSISiW+W3D2iTL4TETz5rduwb1+cbGF8n9g1fkKyLdrxNsBTG9U3IGhR
  #|+KwmMROhqwrZl5HWiKe3HDoQ8NzqP/tYZ6GKhE1Rt19SwP9wZcNQYDaps7APHn4OcSLoxye6vxgr8LvH
  #|mPL32/4ROR04OAU79VsMLXU8E9JJ8AklW/fe5etcKgy99mZa+tYUIWEMTuVwDUO7ktouahUIGLuK27/p
  #|elgYXfk281UcXI2575pcN+rDmfH0he2AA2tA35+cA1iSHUvN119NE3k2TvbJYG6f4KGUGOQRnILEtG3y
  #|DHaGIxOCPPjHvQpnrpH0lq0WW0yJ02w4CsJcY5TCZfIa4GHpn2j/zh6v7V4fYsk/4MOANuzDh5FV4an6
  #|bJhvYdrIvBrzgkfFqaCQth0D1rS/CnycX/GrotQzZbGunQdrU3UWopeUtlRya5EsefNcAPTSTYJmwWYV
  #|G0AuAEuvnLmbyAfBHoDXDapbqYvnkFyatb4p0mm6gh1rjEXfVrYEiUxMQGk+lrca8GqeVsDGjyWIxJsq
  #|fkhuIcgrPzcIh5aUM7T6b7Ojw5pJC41k5NAUqAkS1bKB2YA+VqJqEANrRH1AaBsAx22kVvRTG62pLy8p
  #|/ogVvZ7NzZIeaAG7CYY8ZhjEobu3o9fXP4aVInTfZ1BZo05L2IXTJZOSX93sisIlxiaQwJwefTSPOlEI
  #|gTRBsZbDq+5O7VTpcxhz2zSpo0PX2jI5249zzJxZdqDaA+DrYrazG4kOmhrxsa8RodyPnrtXuqbGSeXF
  #|XvsmAQezJJV8sYZHiL1KxVskQinDx3t7wCzhaLkwjYIcVm5Nqb85EGWNI9ifdA/ZAizG4dnC7+EAcpuy
  #|TaOCFimd5+r6Tz/nyuzDlppnkO6HUbScMiajU67z/U173C78r1CudaOqLHGjrvCUMRdsi+4JpNAqedHs
  #|0tGB7O0WfldAzG7Ry+8DKn+phMl+x3va9/6x4nkOl6lmx+6k2a+vTOSI0M3DT7Mahe3g+H/tq0BopXL0
  #|QePZ4mWbcmQiaG29k500ONtsEmjQ4+Y8VMYZOHppuwhBcN/7lgNG9i+S2EdDwrxGdw8IEoWJ8BgUbOlj
  #|l3iutwmJaSDSmwaWhZMJ6bXug35Cymj1JsxrXNarpqYK6PexTGMWDxMnnvcEEm5qnlQCxDCQEAQK+V4s
  #|ifeBoHQLGqvEqKvOlGfe0ZLYzHF6EGJVfsIMkd7pqNv7hDhDQhnVvC6esF0NmKlEvLd0ym/6L/vq+nr7
  #|kLfUpA4W1yHUHxx3YwyARxKkU3UJPo7zf987j8MJj/uS6m0hNWA/peiXbTwosZIZaEIMqt//xA50cg0J
  #|ZG4twBmF5a+ABCPZxEN+X3uD+oteHofI09Xn9JJ117ejkbVefDl3QAHIWw8lLVHj+Uz3Xcq18b1Kfote
  #|alhN1x2Isk6aWDrOJEXcamUt0nMHj3jt/YVL7dI4fFtrlN7LQ6IqVfSGHcOfXtTFRfqczVCCJ2RJRo5g
  #|qKM6O59cza7C8yoolp4TqbbtvHyLMWElexVC8QsdBLrmqxEw5qTfTYtf1jsq6cgCfRa+s01KqaOF6rOo
  #|2i/ogUrUcKY5R3fAGRIk/20Usqa9ptwbrVVymn7IPCxY8LidPevxwGdXKzDIKh2h1WliCbi/NVjEC4KM
  #|AixwK45M0icknKWlpU8+dHdcrQcuzwMAb9HdaaQTF+1G/umPjlPmMxH3OyKXm69fkQiyyCe47SiT0VkH
  #|C3IBNz4KjJAeDhv9BqtXvEb2HLKYLqtgYrNJrOIGN2dtZ5fz/vupY9n1LeEqKtLrMsG/lrY5Q8CV1d+Z
  #|KsZe0AORGc03BT9IVnyHsgWIz10QVr9JfzhG1qu2x/Bj2vCP3k8RbBQLL5cjVF6pW5OcdEJLx0wyLR5x
  #|2qWvhVr5RSZuQQaAetD33qRhkQgSMSO4G7l0phYL/uG9TQZCdMk/my3zzcqxcItQCTFU0T25OUlw46kh
  #|31FZeurDNgR0EP+YS0qb8X7xMispNZ5Y+ps/8PJAg7lElkmBbKwbCeSkW/8cbvqii5JqLD9V7+If4P7J
  #|Gnv595kXIeeAizsskhF2EL39JPdFFWGijBYZm1DbeENIVafSaOSSvlpnX3HMzuWnrl+tBuOiJh0jv980
  #|WpeoAX9opSZXC5E6wp2IX6dr5y7UnALQje5umxuM5Ps4lRHQg96rR6yr3utzgg0zcwyFxxpkBscrq3u9
  #|5ZBHrY4y5UbykSf1eoO1pEr61TkR0oLKryL/9P1QDnR+FCNwM81xbPlbjRbH4kBvJLX76etcdkUnCWf1
  #|gQK+Ska2p760HmEt2kBhValRe99yF4u3maIoONxYuG4v6mR0ib1jUsPYFPYPKhxgkMrn/6Vu1xOh6h9C
  #|FbEhvj3mOvKUAG1usWSdHQdVZlhTmMuFXMSVz+RVtAchv6W6TG6ktVTrzuQwbOH3nC07R28n2LhFCsXU
  #|LxpxSWef5KzUAlPYheI3HthSnRWsNr3GsOp2pJXJIz/9g0uQrCRmucXH3Fc46oIFAF/KwLGAnh4o6ui/
  #|JX8mWzs08uzdypnT+x6UN8Dvs6S5vYz7A9eB1gacMkjV9nav+ccM6q6Mm09WhX1cUuTm1WNTN1AxeFpp
  #|Y2NkUTZueEJlbz0iIGVuY3J5cHRlZEhtYWNWYWx1ZT0iaEdsV3JrR1p1K0ttTUV4U0ZsRG1QbnFJNlB6
  #|RHJrWm5zNWJjQmx2NmVwMD0iLz48a2V5RW5jcnlwdG9ycz48a2V5RW5jcnlwdG9yIHVyaT0iaHR0cDov
  #|L3NjaGVtYXMubWljcm9zb2Z0LmNvbS9vZmZpY2UvMjAwNi9rZXlFbmNyeXB0b3IvcGFzc3dvcmQiPjxw
  #|OmVuY3J5cHRlZEtleSBzcGluQ291bnQ9IjEwMDAwMCIgc2FsdFNpemU9IjE2IiBibG9ja1NpemU9IjE2
  #|IiBrZXlCaXRzPSIxMjgiIGhhc2hTaXplPSIyMCIgY2lwaGVyQWxnb3JpdGhtPSJBRVMiIGNpcGhlckNo
  #|YWluaW5nPSJDaGFpbmluZ01vZGVDQkMiIGhhc2hBbGdvcml0aG09IlNIQTEiIHNhbHRWYWx1ZT0iV29v
  #|WUNRNmhvRFIyZ0VSOXp3RFZLdz09IiBlbmNyeXB0ZWRWZXJpZmllckhhc2hJbnB1dD0iYnB6YWJ3akho
  #|K3UrZmx4TXRzcHpoZz09IiBlbmNyeXB0ZWRWZXJpZmllckhhc2hWYWx1ZT0iN0QycnJybmhTWXAvNjFI
  #|Z2o2L3VQaTRHV1paN2lmMGE3K1QvQ1BOMTJLdz0iIGVuY3J5cHRlZEtleVZhbHVlPSI4OWwxbHdrTlla
  #|QnVrL2tZTmV1R1dBPT0iLz48L2tleUVuY3J5cHRvcj48L2tleUVuY3J5cHRvcnM+PC9lbmNyeXB0aW9u
  #|PgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
  #|

///|
let encrypt_aes_b64 =
  #|0M8R4KGxGuEAAAAAAAAAAAAAAAAAAAAAOwADAP7/CQAGAAAAAAAAAAAAAAABAAAADgAAAAAAAAAAEAAA
  #|AgAAAAEAAAD+////AAAAAAAAAAD/////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|///////////////////////////////////////////9//////////7////+////BQAAAAYAAAAHAAAA
  #|CAAAAAkAAAAKAAAACwAAAAwAAAANAAAA/v////7/////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|/////1IAbwBvAHQAIABFAG4AdAByAHkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAWAAUA////////////////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|/v///wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAD///////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAD+////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP///////////////wAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAP7///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA////////////////AAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/v///wAAAAAAAAAAAQAAAAIAAAADAAAA/v//////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|//////////8DAAIAJAAAAIwAAAAkAAAAAAAAAA5mAAAEgAAAgAAAABgAAAAAAAAAAAAAAE0AaQBjAHIA
  #|bwBzAG8AZgB0ACAARQBuAGgAYQBuAGMAZQBkACAAUgBTAEEAIABhAG4AZAAgAEEARQBTACAAQwByAHkA
  #|cAB0AG8AZwByAGEAcABoAGkAYwAgAFAAcgBvAHYAaQBkAGUAcgAAABAAAAAo4CLFrKeTKjf5ZIUDZKhs
  #|9kAmMAo4s1aL5kf7JzTjiRQAAACzHs4Lxi8EGKGeGW8k5Viv38RyvBDXznGdpnFMBNfB3wAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACESAAAAAAAAbUJcpy+h0iUeSNh0
  #|/tUILIIqSptUp6a1IebgVi86XVUpG+f3J+sHlgy2bAyrSIQfHB2wKMvRLiUb1XXO+mIuAG2/kqO/Pmdo
  #|+LpQDRaxxgfZKfLnsdCUuMSgffqZce1FX6ooKNJuLbLnOgChhUxU7xPGReN8Wqk0k0cryLfMsK5gy/aC
  #|UudnwEa6yHhAhtO+5A/Q8JGt9alYL7vTwnZVpuB2vJI2u1Ja2EQBdjomBSLe3I4RWWBG+iAsZpedpXFj
  #|7vtFx35qGoUt6OKsy3ZBn+S7WMRhWk3eSis7T89LgAA6ElmN24QYlI7mg5sPD+yF1j1RCPr0SjMpjneT
  #|K6U1zEjya0j4wt+PubMrHuxcdSVdZBpI+xbC20wby2N3FmhroteGkFM1Dbx/dsdakawncIvs8TW+S7I+
  #|+4tvecZmxtl/FEkmzJy+Q0w2JIAr/IJRzngarUZdXzFO/cJ8kyld0l4k9OOQc61d8FPMtZsfr6a3pz4A
  #|EF+l1tdvNKDBZeLjJTVBuz1DsFW0w+kv+oRaCXPgm0hHOC5u8WwqkVeqc7WofDnP7zgX0OCSP1E4nkRV
  #|8pdBdOcR9uqXPuZ0NDpRGUq17D3m9SuUyfJhAnBdK2PqGJ4+OKNzwjigiF4zRTsll05KgcdV5yYf6fdl
  #|rmKgzzfMT38QPYck6PuZlosc7hVJZuPH0GM9rkVKVg0eLkZMJugzRknLEqqHiMXZZKpbML0Na1zSiS0u
  #|GdrlMLJw48Fj5TWdmg5BvfnHadF9nz8WLLqBcQEIcR38N0DRgAqF7wtgD5Py5Qh35bmWmiLV5IHO7bcn
  #|+OhBOxfJsHDEm53pT1JRdYGq9+tgULs0VLzCp7wReUFU9FC6UKhsGeoaiFBYO0PhiQpWJtpVM0Nh8goi
  #|aAK7VjW9qq/glfnA/F4rikCiVPh/dbBA61+GBxagk39A2SJ8e7hlDhsScZF468HiCwW4yzK6JajUCKGb
  #|z7yftlKcdwFjX3/32piwVxS/gs0wTap6pD/7wcjhtvyQMzrkrUM/fBILKJZjTW0odcGsWymPq1F+koqz
  #|z3+EE3DvLBt7di2qtHQBwjBN9Vc/QIkHkJOQkJk3U9c2x1xipG0FtCBPzl8njk0FXGVVTk1tPdhk4drz
  #|1fkEPKIR6Z5sJPnxjJYIQq1qjvyYPONzg4L+pNiVeqzQDvVcmKJOunQsbWtxj55AWmN1Q4t673/QHO1y
  #|Bov9oPRn3A+Hy9JQXKQTFBuw1u8jImUCirMb3HjS1d/y2xL7t6sfnA4UTLR6GWEGO94lR8PgZESbhv6v
  #|6wUl8vqWki9/+PvkC+n7GE+xUpF1iRKhYA35GqJHSVk4NSCGR4qaMoT3xgxAaj7JgF11Z/yJk+9kaxsS
  #|hcSphxxh70tgrKtFzWfxqgGbB2raDysCM3Z+Q7zijcZGrbANh6EKXBI/KyROBN1TCGlU9XopuHD5pxM3
  #|jgDfwEf+7vqxQYK0hx08LHghmAMLE8fRTz5Ya7T6VSQqMb5/apTbcfh7rJIX1kfhKP8LyF3OKiSrnZVa
  #|MtYuBnQ2QkfMzKZgbV/6i++UAoMUDJjP1JIdOLSpbu+niU8FgI/zb8frqV1+EiCclrtK7lcnMqL6HNjv
  #|V+nhW+M3EvwO3dbmzBk5kB4WBQM7uDvHFI/BFN6StRA6aMPDCukxRWwI1Y2tKpswq8l98anz/rWbamMJ
  #|9dcCIt6in21+aOeD4cYoWIvBlHhoezw9Q46WTeCoIrFKKAjsEZ2CePRX9/6+0HsEkfwTQ4Qt32Bpr6Fr
  #|Wwy/yVl87I6TrvOR1IJ2USyIBYsJe5LaEh3UqjfBH1MJQQCADMkwm5W6aMWAZs77nm1LwsVmjXP2nUbs
  #|pXoj2UgAAU7ItLlMoPctFK20Hk2uzZPBzH/6TDuPQdpNVTTrFTHEvCe8wg5ckUCRdCpo25zPUFe/3M8v
  #|tcbcBB1MDXW9RlE6RuzpdtkOFGmOPsUNU3ukcvAAGa8W9q+0FlIjzQ9zoJLcSzKekf+PiioYiZBCU4Gw
  #|ltPpjfm0vXu8Ei/TnO7xPTubo/z08ukB1zqtGjqE+1VpDPrZJ+um2xSqIYmWL1uEwC3OLX15SIgXFb7U
  #|LtmVTYB5OpCbqslzLIdoLGsDAOk0035Uzmp3vRhE7UYJVXXsYT8sAmunDEIkzxUsmtcUMEx5mwaIpTDO
  #|JhORySsr0xE2W9f4f54HIWJYb0IvzQtM2cJbiQsSQUm3Z7C6NtcOisRw7ZRpGm021XlQGkuPBSL6Cqvj
  #|E/vO3BP+n1qHb/6UAURpz+uJqSVqi6Hm/fNc9js6MmTwN2WEvx2I3e2mgptNfgNevrV9o3aQGqjP+haI
  #|iiwzm+N1UdA0MXapJGhWyWcPxW+sRg5utFZqzLN61cCG8i8+lECElRoDJcv143Fmws/CnGf+6B+1zY3K
  #|sb6ygXGyl8eqE7eAy9oCuO/+BP5sndhbvIdrFJOLL7OBqR+ZqSydZ+larO/CblUQbpfqVV6i9RtXy1zx
  #|nZHOnSOmj20GtcKRPLNsrfoaXPbYMP0aAbWU3KACWur7VRN/tgALplyLKnJDuhPAmG2ONDEqIK2ENxKg
  #|fIDW5MUSTmSZoLrdF6xiWsQZmhX4h2h1LPSAwmX+7p0Jaf9bKKAiUUkHcopufGNij2Ug33Gm663BpPJx
  #|8SO5GfOCt0cbV3pYAdCOGRuednyFqnIvOza5FZMZVYHlcUKRUqbevf13xGZBX/LoAiDsCfxAkdYAcwrp
  #|LqwoktSWifvWrmUIqWWdZkfqJBs6Psatu6HHWExQ76Qy+3vNPXkyP5vOqlIU9y3HD/9nkBaYcXBB9kbw
  #|4xyzIpKyvXIWb84uAjbwpEzBk2eINphYWath02oQOs7KH0vFgcZ7BDJYrzh2g4BqYFrHT1xT5sIG6j/f
  #|vBj/1gRZ60ZuNpqvCR8cvnN9dAvogDNxStb3n9FICy17warNFq+9P2aPyVO0/WbOH7Nys1aGTwUMhRDd
  #|2opfvfom6EeRdiyTkN9IPa48ifvJPJLULtsmzVBxoy8PFQC6vkjOyA3FYGpGClYfJWOWf2csiy0qU3i5
  #|d3eIdK2IEMSQqcymOFx8rapxo2XPoyqmcliDsw1WHOKamnFXYMqpVsPEs1tC4Nzp8FIML0QjnWuoG1Jh
  #|Yox72p4r60Rpd6vhB5Ne+JMDeJzpyH5nKZk4Ssz0o+tK++tjDcSAuhFeg9wV2hTq6L4sLqiSnlp8Uf1E
  #|+3vxGSt8b3VT7mQ8Qd9Ot5uYpZdjQDP+i7YM8ttl9mKX043hXOoxNRz06mkc+A2pMqV3SUsGY1QMtQdi
  #|Q8yxDMMoKJXP3QRdxlB5q/PNzkqB8USvO3QCUUZ+OKbomQ8ULv3Wa3YReI0HMqD7Bi04kTnCG+NQsB+V
  #|UIW44Mn1NUaXNvxX2cfPVxy3qdAiq7IuV0JSVoP95nPj7RdpDRU/6XCEzER5SiTYXvU/izLPZsYkzyyG
  #|aIjR15joiHTYaPj9ISqKR5VDch6gstWVboqOQFQ00XagQxlPonn/C+MBm0ZvGoK2r8semj6hyXaoLmkc
  #|R6lYwmG0x7vgFL5Bf896dhC8mb0bQJNrT+a3sUxTTAtZJxALZ2KGKxmjxj2uXq1j0Si01fcKDtLFvHQr
  #|h2gxVwgMCxhQyWYLbsCDi4669Mj2kj9fq+aGYKJGjG3a5lLi3URGFQhFTwChL0HT4hGuhlHyPWqtF+wf
  #|1nqN8BZafkS38mAMx3StowYU8FYjYolPS2EVoHVPoa07vZhwySLzxuWRzksDVk7BZ2QSi0QcMPIygZD+
  #|R4GAEthSI5u64VuyM2VnGU+QDx9cfB980fLLagOi4/upUZmF9bNk1bkATTOjX91drPWm2p7YeslVYouT
  #|IDll1EJUbhk9PJpJKbyT6rSF5HTPLqDxmnsH0ppvMdpsxgK0ndyuau2NlPjBGR+e9PNmQidoUPsLRpW+
  #|7n9ft0pyoNhJ5DdVz26gRlsVlwDq48vJoJ6Db7KfW2Rx9VN+650Ilq2xvOU73dAn7iWOL7Zqcig7h3MF
  #|Sw5VjeoTw9vRPXCt739cf4N1DIMJZ1mTC+9FJSA5s6ZdvlL9P9ZhHt3b4KuTksy5+sjsDpSqjI3zMdVJ
  #|JxiopBtm9Crbz5ZzikmBPEGyXl/ey1UJ2inKrEWlOJlI1bZmIftBWQ/jpDX9qOp/DbsI+2MIv56h3OCj
  #|VpLNfJwErT5wv4swqDTIMU7GllxKF4S3ouw1sNGTCM+HhnmqYd+aJH70eU28d2P3BR9w6GLYBJmXEWYs
  #|Cy0242Z8lVc/AnjPOw42mHhMH/5QHQU1XN9wmtF3rFuhafqK8ZHn8CS7H+9T66k07k/o+RKfFhnaKl6e
  #|B4ZDCT+8vCNn8lid4A9l2cyRy1zzx+Ve6TJ9NB+c/CN4P7AruB9k1g5RhmQ8lI0ejI+QeGXNIJo5P7SO
  #|8LFPGLIzL+t/9stp6pZ2EaBI5d2psFb6h5tToL9cf88DU8HM0a4aIJwC4tJOlEHHENE6VSy87gTQGY0g
  #|+XZ4UFFBrCzn4z7kFdtm8kLaPiFPY5T5oRCXK7iO7oPInN9S2UYOv2pho+PeczslWE4XkfO/gRZx3Oxc
  #|0lGfoGNtSbJ7QBau8QHdBvkecbcdtchhV/KitB5lDRgploThPJvdHUa3hejVZR4+u649WCnAavNr9rIc
  #|kmehOJzbZ56gusl40RB6InVW/fjWZO8AhGNSeyvkJfDLKqQZfrc3fKCmqFr2ErrVWylRfABulcok+zTj
  #|8+j9VlYmEOONbNi/IyoFDe4Y8kWQPjCfzSZcATg/rVteXqP4Pb3LikGQvSB8Lb/wu2hLPYpcoE7wHD4h
  #|/5G0RczTlbI1ciJkOBCo/XOqgRIZugs+vCU5Ci83DYCxzULO32Wc+XmDFMl5o8SVDt0ogFx9BVjsZhV/
  #|cLOeFIcC/JaKJv7wN2SjXMENVnc0AgRBx1lpbz0MFthCkr4jGR/c5isUZ8jYWMYU6PJGtXgjVS+xzo+C
  #|GWBde9ywcIR1dsmmPZRt1TWL/6KaRD30xAfETVpOZG0ciqjZLUuaL17snvJKMOOzvHGoEYci4Jqf9W66
  #|KgtybiZKUZzyMy6iSKpabPZu96figx3jNCPfWsvTvSxykr+7ejklEFBEdrTz9vVeOdBRVge2BbSSJF5E
  #|OzaJYVEwLg+MxTWQ0cWdzSsn2Lgd0SWhrjFPsBx18pPekPEBAFUGAMAdu3lFVtU3LI6kJoTsumK9UTg9
  #|X3PPQM5T23kYpN6WTC+JhhNousJyj16DgOJvQlsRJGCQONbBpYTnRqbqnHZFvh9URGcYfa6QUhdjE6mb
  #|4omx4ZX6lnQpXcVpiJ4EiVSg7w55hX6bNr9+4+ahVv1LSm74f7eAEYbitR6hPt08POxjfy5OMZdSJhp/
  #|x1zy9O049dWd9ouelXSI4xzoUYeA502uMNv2zVsV/I8CiIaEdMVpXY/w5DK3rKUY0GTU8/ckCEEskDuv
  #|TnoYBl9v6Is8Z7XeV8afs47d04uLjRp8TcoBRSuoKqKe1AQrCruiXay0WL8G9KqIVp7oFX1OR8Bgt82K
  #|EuarfyVEflWji+SMD5bYNYNGhnreEIK5FRWLjHRv3Iv+z758EVsK/wVa1AZtu1RIKWmfPX5veyQSa4U8
  #|5kcZ+Bx0ui+UU4+f1iQILAldcgQBnV7FsXOwuTOVZTE4fcz2fvamzD416IfKjDJI4hCQlKzNISxfqLZ4
  #|22nCIu16O4NSEFwvEB468l9v6Is8Z7XeV8afs47d04s7l9lFcJE84FDvlcfjQhRqoLMI09UvmKEDt6JR
  #|3HhpRJ8ZKHnPAz4y4Sle2nM0QXarXKcqvdtqfu/be1QMicCH21WHs9lZcKwT+ir+FfJRahUKhLcPtOtS
  #|/Tiw3dS7FMKTT5bU20uI4d0sDnyrPoDKFBlE31BfpD+Ayyeff2uVcgPcw4wsQFOyIXQxf4UbNcJs7Alq
  #|3tDv/iwJ4vQoKywCgOQjFwXwHupPsA5/Odx5EzWSii/N9bAsnkz/ixTyFHVU7CCrKtmly0YWy9RAI0LY
  #|j/zGG8wEsaVt3fwIAzI7u2rp+LaaBt/pJXzc1DqJBNW1aXqyqWA5kM3hzd+O9NEKIVkmvmJNBikbu/rc
  #|VwErDGcbYKiCW5Ox7PHmuviMaowd4YITk4eJEPMN067pxBIL1/SexonPPdugMo1Qy0KcPOLpZyg5l8l0
  #|isSVDuQEacWcNiJBjbC1bNLKfrDR2pTyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|UgBvAG8AdAAgAEUAbgB0AHIAeQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAABYABQD//////////wEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAAAA
  #|AAEAAAAAAABFAG4AYwByAHkAcAB0AGkAbwBuAEkAbgBmAG8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAHgACAP////8CAAAA/////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAADgAAAAAAAAAEUAbgBjAHIAeQBwAHQAZQBkAFAAYQBjAGsAYQBnAGUAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAiAAIA////////////////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAABAAAADgSAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD///////////////8AAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAD+////AAAAAAAAAAA=
  #|

///|
test "encryption info detection" {
  let bytes = decode_base64_multiline(encrypt_sha1_b64)
  inspect(bytes.length(), content="14336")
  let reader = cfb_read(bytes)
  let info = reader.read_stream("EncryptionInfo")
  let is_agile = match encryption_mechanism(info) {
    Agile => true
    Standard => false
  }
  inspect(is_agile, content="true")
  let xml = @encoding/utf8.decode(info[8:])
  inspect(xml.contains("<encryption"), content="true")
  inspect(
    xml.contains("saltValue=\"k2gR7PkjsYvJ4akxbSkZRw==\""),
    content="true",
  )
}

///|
test "agile verify password" {
  let bytes = decode_base64_multiline(encrypt_sha1_b64)
  let reader = cfb_read(bytes)
  let info = reader.read_stream("EncryptionInfo")
  let xml = @encoding/utf8.decode(info[8:])
  let encryption = parse_encryption_info(xml)
  validate_encryption_info(encryption)
  let password_hash = derive_password_hash("password", encryption)
  inspect(agile_verify_password(password_hash, encryption), content="true")
  let wrong_hash = derive_password_hash("wrong", encryption)
  inspect(agile_verify_password(wrong_hash, encryption), content="false")
}

///|
test "encryption info standard detection" {
  let bytes = decode_base64_multiline(encrypt_aes_b64)
  inspect(bytes.length(), content="8192")
  let reader = cfb_read(bytes)
  let info = reader.read_stream("EncryptionInfo")
  let is_standard = match encryption_mechanism(info) {
    Standard => true
    Agile => false
  }
  inspect(is_standard, content="true")
}

///|
test "read encrypted agile workbook" {
  let bytes = decode_base64_multiline(encrypt_sha1_b64)
  let workbook = read_with_password(bytes, "password")
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  debug_inspect(sheet.get_cell("A1"), content="Some(\"SECRET\")")
}

///|
test "read encrypted standard workbook" {
  let bytes = decode_base64_multiline(encrypt_aes_b64)
  let workbook = read_with_password(bytes, "password")
  inspect(workbook.sheets().length() > 0, content="true")
}

///|
test "decrypt agile zip read" {
  let bytes = decode_base64_multiline(encrypt_sha1_b64)
  let decrypted = decrypt_encrypted_package(bytes, "password")
  let result : Result[@zip.Archive, Error] = Ok(@zip.read(decrypted)) catch {
    e => Err(e)
  }
  inspect(result is Ok(_), content="true")
}

///|
test "decrypt standard zip read" {
  let bytes = decode_base64_multiline(encrypt_aes_b64)
  let decrypted = decrypt_encrypted_package(bytes, "password")
  let result : Result[@zip.Archive, Error] = Ok(@zip.read(decrypted)) catch {
    e => Err(e)
  }
  match result {
    Ok(archive) =>
      inspect(archive.get("xl/workbook.xml") is Some(_), content="true")
    Err(_) => inspect(false, content="true")
  }
}

///|
test "decrypt standard workbook parse" {
  let bytes = decode_base64_multiline(encrypt_aes_b64)
  let decrypted = decrypt_encrypted_package(bytes, "password")
  let result : Result[Workbook, Error] = Ok(read_zip_bytes(decrypted)) catch {
    e => Err(e)
  }
  inspect(result is Ok(_), content="true")
}

///|
test "read encrypted wrong password" {
  let bytes = decode_base64_multiline(encrypt_sha1_b64)
  let result : Result[Workbook, Error] = Ok(read_with_password(bytes, "wrong")) catch {
    e => Err(e)
  }
  inspect(result is Err(XlsxError::InvalidPassword), content="true")
}

///|
test "decrypt agile wrong password" {
  let bytes = decode_base64_multiline(encrypt_sha1_b64)
  let result : Result[Bytes, Error] = Ok(
    decrypt_encrypted_package(bytes, "wrong"),
  ) catch {
    e => Err(e)
  }
  inspect(result is Err(XlsxError::InvalidPassword), content="true")
}

///|
test "read encrypted without password" {
  let bytes = decode_base64_multiline(encrypt_sha1_b64)
  let result : Result[Workbook, Error] = Ok(read(bytes)) catch { e => Err(e) }
  inspect(result is Err(XlsxError::EncryptedPackage), content="true")
}

///|
test "read_with_password non-encrypted workbook accepts transcoder path" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "Plain")
  let bytes = write(workbook)
  let transcoder = (_name : String, data : Bytes) => {
    @encoding/utf8.decode(data) catch {
      _ => raise InvalidXml(msg="transcoder decode failed")
    }
  }
  let parsed = read_with_password(bytes, "ignored", transcoder~)
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  debug_inspect(parsed_sheet.get_cell("A1"), content="Some(\"Plain\")")
}

///|
test "read_with_password non-encrypted workbook without transcoder" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "PlainNoTranscoder")
  let bytes = write(workbook)
  let parsed = read_with_password(bytes, "ignored")
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  debug_inspect(
    parsed_sheet.get_cell("A1"),
    content="Some(\"PlainNoTranscoder\")",
  )
}

///|
test "write encrypted roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "SECRET")
  let encrypted = write_with_password(workbook, "passwd")
  let decoded = read_with_password(encrypted, "passwd")
  let decoded_sheet = match decoded.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  debug_inspect(decoded_sheet.get_cell("A1"), content="Some(\"SECRET\")")
}

///|
test "write encrypted invalid password length" {
  let workbook = Workbook::new()
  let long_password = "*".repeat(256)
  let result : Result[Bytes, Error] = Ok(
    write_with_password(workbook, long_password),
  ) catch {
    e => Err(e)
  }
  inspect(result is Err(InvalidPasswordLength(_)), content="true")
}

///|
test "standard decryption accepts RC4-style verifier layout" {
  // Excelize parses any non-AES AlgID as the RC4-style layout (20-byte
  // verifier hash) and still decrypts the package with AES-ECB.
  let password = "legacy-pass"
  let salt : Array[Byte] = []
  for i in 0..<16 {
    salt.push(i.to_byte())
  }
  let salt_bytes = Bytes::from_array(salt)
  // encryption info: version 3.2, flags, header size, 32-byte header
  let info = ByteWriter::new()
  info.write_u16_le(3) // version major
  info.write_u16_le(2) // version minor
  info.write_u32_le(0x0000_0024) // flags
  info.write_u32_le(32) // header size
  info.write_u32_le(0x0000_0024) // header flags
  info.write_u32_le(0) // size extra
  info.write_u32_le(0x0000_6801) // AlgID: RC4, not an AES id
  info.write_u32_le(0x0000_8004) // AlgIDHash: SHA-1
  info.write_u32_le(128) // key size bits
  info.write_u32_le(1) // provider type
  info.write_u32_le(0) // reserved1
  info.write_u32_le(0) // reserved2
  // RC4-style verifier: salt size + salt + verifier(16) + hash size + hash(20)
  info.write_u32_le(16)
  info.write_bytes(salt_bytes)
  for _i in 0..<16 {
    info.buf.push((0xaa).to_byte())
  }
  info.write_u32_le(20)
  for _i in 0..<20 {
    info.buf.push((0xbb).to_byte())
  }
  let info_buf = info.to_bytes()
  // package encrypted with the key derived exactly like the reader will
  let key = standard_convert_password_to_key(128, salt_bytes, password)
  let plaintext : Bytes = b"legacy standard payload!\x00\x00\x00\x00\x00\x00\x00\x00"
  let encrypted = aes_ecb_encrypt(key, plaintext)
  let package_writer = ByteWriter::new()
  package_writer.write_u64_le(24) // real payload length before padding
  package_writer.write_bytes(encrypted)
  let package_buf = package_writer.to_bytes()
  let decrypted = standard_decrypt(info_buf, package_buf, password)
  inspect(decrypted.length(), content="24")
  debug_inspect(
    @encoding/utf8.decode(decrypted[:24]),
    content=(
      #|"legacy standard payload!"
    ),
  )

  // truncated RC4-style verifier still raises
  let truncated = info_buf[:info_buf.length() - 4]
  try standard_decrypt(truncated, package_buf, password) catch {
    InvalidEncryptionInfo(msg~) =>
      inspect(msg, content="invalid verifier block")
    e => fail("unexpected error \{repr(e)}")
  } noraise {
    _ => fail("expected truncated verifier to fail")
  }
}
