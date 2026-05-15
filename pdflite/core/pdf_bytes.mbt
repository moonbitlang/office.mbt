///|
/// Object encryption algorithm used by the PDF security handlers.
///
/// ARC4 carries key length in bits and security-handler revision. AESV3 carries
/// whether the ISO/PDF 2.0 hash variant is in use.
pub(all) enum PdfCryptType {
  PdfCryptARC4(Int, Int)
  PdfCryptAESV2
  PdfCryptAESV3(Bool)
} derive(Debug, Eq, ToJson)

///|
/// Error variants raised by pdflite parsing, writing, filtering, text, and
/// encryption APIs.
///
/// The variants intentionally stay specific enough for tests and callers to
/// distinguish malformed input classes, while most public APIs expose them
/// through the ordinary `raise PdfError` flow.
pub(all) suberror PdfError {
  InvalidByte(Int)
  InvalidCursorPosition(Int)
  InvalidReadLength(Int)
  InvalidBit(Int)
  InvalidBitCount(Int)
  MatrixNotInvertable
  DictionaryExpected
  DictionaryKeyNotFound(PdfName)
  NumberExpected
  RectangleExpected
  BadRectangle
  MatrixMalformed
  InvalidHexEscape
  InvalidASCII85Data
  FilterNotSupported(PdfName)
  FilterExpected
  CCITTDecodeParmsExpected
  CCITTNotSupported(String)
  InvalidCCITTData
  PredictorExpected
  PredictorNotSupported(Int)
  InvalidLZWData
  InvalidFlateData
  ParseObjectExpected
  ParseArrayMalformed
  ParseSingleObjectExpected
  ParseIndirectObjectExpected
  ParseEndObjectExpected
  ParseStreamExpected
  ParseEndStreamExpected
  StreamLengthExpected
  StreamDataExpected
  ParsedObjectExpected
  PageTreeExpected
  PageRotationExpected(Int)
  ContentOperatorExpected
  ContentOperandExpected
  FunctionExpected
  FunctionNotSupported(Int)
  BadFunctionEvaluation(String)
  StartXRefExpected
  XRefExpected
  XRefEntryExpected
  TrailerExpected
  RootExpected
  BadRevision
  InvalidObjectNumber(Int)
  BadDate
  InvalidUnicodeCodepoint(Int)
  InvalidUTF16BE
  InvalidUTF8
  InvalidPDFDocEncoding(Int)
  CryptoKeyExpected
  InvalidCryptoDataLength(Int)
  EncryptionExpected
  EncryptionMethodExpected
  EncryptionDictionaryEntryExpected(PdfName)
  EncryptionDictionaryEntryTooShort(PdfName)
  EncryptionIDExpected
  EncryptionAuthenticationUnsupported(PdfCryptType)
  EncryptionObjectCryptUnsupported(PdfCryptType)
  EncryptionSavedStateExpected
  EncryptionRecryptUnsupported(PdfCryptType)
  EncryptionRecryptFailed
  EncryptionPermissionsCorrupt
  EncryptionPermissionsMismatch(Int, Int)
  RandomBytesUnavailable
  EncodingExpected
  EncodingDifferencesMalformed
  EncodingWriteUnsupported
  FontSubtypeExpected
  FontFlagsExpected
  StandardFontExpected
  BaseFontExpected
  FontFirstCharExpected
  FontLastCharExpected
  FontWidthsExpected
  FontWidthExpected
  FontCharProcsExpected
  FontTypeExpected
  FontWriteUnsupported
  AfmExpected
  ColourSpaceExpected
  BadText
  CIDSystemInfoExpected
  CIDRegistryExpected
  CIDOrderingExpected
  CIDSupplementExpected
  CIDBaseFontExpected
  CIDFontDescriptorExpected
  CIDWidthsExpected
  CIDWidths2Expected
  DescendantFontExpected
  CMapEncodingExpected
  PageLabelStyleExpected(String)
  EndOfInput
} derive(Debug, Eq, ToJson)

///|
/// PDF byte strings and byte streams.
///
/// This is an alias for MoonBit `Bytes` because PDF strings and streams are
/// byte sequences, not Unicode text. Use `String` only after an explicit PDF
/// text decoding step.
pub type PdfBytes = Bytes

///|
/// A PDF name token stored as its raw bytes without the leading slash.
///
/// Names are byte-oriented in the PDF file format. Keeping the original bytes
/// avoids accidental UTF-16 or UTF-8 interpretation while still allowing
/// explicit views and owned-byte access.
pub(all) struct PdfName(Bytes) derive(Debug, Eq, ToJson)

///|
/// Converts an integer to a byte.
///
/// Raises `PdfError::InvalidByte` when `value` is outside `0..=255`.
pub fn pdf_byte_of_int(value : Int) -> Byte raise PdfError {
  if value < 0 || value > 255 {
    raise InvalidByte(value)
  }
  value.to_byte()
}

///|
/// Copies an array view of bytes into owned PDF bytes.
pub fn pdf_bytes_of_array_view(values : ArrayView[Byte]) -> PdfBytes {
  Bytes::from_array(values)
}

///|
/// Copies a byte view into owned PDF bytes.
pub fn pdf_bytes_of_view(values : BytesView) -> PdfBytes {
  values.to_owned()
}

///|
/// Copies a byte view into owned PDF bytes using indexed construction.
///
/// This is useful when the input may alias data that will be mutated elsewhere.
pub fn pdf_bytes_copy(values : BytesView) -> PdfBytes {
  Bytes::makei(values.length(), i => values[i])
}

///|
/// Creates owned PDF bytes of `length` filled with `value`.
///
/// The default value is zero. Raises `PdfError::InvalidReadLength` for negative
/// lengths and `PdfError::InvalidByte` for values outside `0..=255`.
pub fn pdf_bytes_make(
  length : Int,
  value? : Int = 0,
) -> PdfBytes raise PdfError {
  if length < 0 {
    raise InvalidReadLength(length)
  }
  let byte = pdf_byte_of_int(value)
  Bytes::makei(length, _ => byte)
}

///|
/// Concatenates byte views into one owned PDF byte sequence.
pub fn pdf_bytes_concat_views(parts : ArrayView[BytesView]) -> PdfBytes {
  let output : Array[Byte] = []
  for part in parts {
    for byte in part {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
/// Converts integer byte values to owned PDF bytes.
///
/// Raises `PdfError::InvalidByte` if any value is outside `0..=255`.
pub fn pdf_bytes_of_int_array(
  values : ArrayView[Int],
) -> PdfBytes raise PdfError {
  Bytes::makei(values.length(), i => pdf_byte_of_int(values[i]))
}

///|
/// Flattens arrays of integer byte values into owned PDF bytes.
///
/// Raises `PdfError::InvalidByte` if any value is outside `0..=255`.
pub fn pdf_bytes_of_int_arrays(
  values : ArrayView[ArrayView[Int]],
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  for array in values {
    for value in array {
      output.push(pdf_byte_of_int(value))
    }
  }
  Bytes::from_array(output)
}

///|
/// Maps every byte through an integer transformation and returns owned bytes.
///
/// The callback receives each input byte as an `Int`. Raises
/// `PdfError::InvalidByte` if a mapped value is outside `0..=255`.
pub fn pdf_bytes_map_int(
  bytes : BytesView,
  f : (Int) -> Int,
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(pdf_byte_of_int(f(byte.to_int())))
  }
  Bytes::from_array(output)
}

///|
/// Converts bytes to an array of integer byte values.
pub fn pdf_int_array_of_bytes(bytes : BytesView) -> Array[Int] {
  [
    for byte in bytes => byte.to_int()
  ]
}

///|
/// Compatibility alias for `pdf_bytes_of_int_arrays`.
///
/// CamlPDF models many byte strings as integer lists; this helper preserves
/// that shape for callers ported from OCaml.
pub fn pdf_string_of_int_arrays(
  values : ArrayView[ArrayView[Int]],
) -> PdfBytes raise PdfError {
  pdf_bytes_of_int_arrays(values)
}

///|
/// Compatibility alias for converting one integer byte array to PDF bytes.
pub fn pdf_string_of_int_array(
  values : ArrayView[Int],
) -> PdfBytes raise PdfError {
  pdf_bytes_of_int_arrays([values])
}

///|
/// Returns the length of a PDF byte sequence.
pub fn pdf_bytes_length(bytes : PdfBytes) -> Int {
  bytes.length()
}

///|
/// Returns the byte at `index`, or `None` when the index is out of bounds.
pub fn pdf_bytes_get(bytes : PdfBytes, index : Int) -> Byte? {
  bytes.get(index)
}

///|
/// Copies PDF bytes into a resizable `Array[Byte]`.
pub fn pdf_bytes_to_array(bytes : PdfBytes) -> Array[Byte] {
  bytes.to_array()
}

///|
/// Copies PDF bytes into a fixed-size byte array.
pub fn pdf_bytes_to_fixed_array(bytes : PdfBytes) -> FixedArray[Byte] {
  bytes.to_fixedarray()
}

///|
/// Wraps owned bytes as a PDF name without copying.
///
/// The bytes are expected to be the name payload without the leading slash.
pub fn pdf_name_of_bytes(bytes : PdfBytes) -> PdfName {
  PdfName(bytes)
}

///|
/// Copies a byte view and wraps it as a PDF name.
///
/// The bytes are expected to be the name payload without the leading slash.
pub fn pdf_name_of_view(bytes : BytesView) -> PdfName {
  PdfName(bytes.to_owned())
}

///|
/// Returns the owned bytes backing this PDF name.
pub fn PdfName::bytes(self : PdfName) -> PdfBytes {
  self.0
}

///|
/// Returns a read-only view of the bytes backing this PDF name.
pub fn PdfName::view(self : PdfName) -> BytesView {
  self.0
}

///|
/// Returns the byte length of this PDF name.
pub fn PdfName::byte_length(self : PdfName) -> Int {
  self.0.length()
}
