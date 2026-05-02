///|
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
pub type PdfBytes = Bytes

///|
pub(all) struct PdfName(Bytes) derive(Debug, Eq, ToJson)

///|
pub fn pdf_byte_of_int(value : Int) -> Byte raise PdfError {
  if value < 0 || value > 255 {
    raise InvalidByte(value)
  }
  value.to_byte()
}

///|
pub fn pdf_bytes_of_array_view(values : ArrayView[Byte]) -> PdfBytes {
  Bytes::from_array(values)
}

///|
pub fn pdf_bytes_of_view(values : BytesView) -> PdfBytes {
  values.to_owned()
}

///|
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
pub fn pdf_bytes_of_int_array(
  values : ArrayView[Int],
) -> PdfBytes raise PdfError {
  Bytes::makei(values.length(), i => pdf_byte_of_int(values[i]))
}

///|
pub fn pdf_bytes_length(bytes : PdfBytes) -> Int {
  bytes.length()
}

///|
pub fn pdf_bytes_get(bytes : PdfBytes, index : Int) -> Byte? {
  bytes.get(index)
}

///|
pub fn pdf_bytes_to_array(bytes : PdfBytes) -> Array[Byte] {
  bytes.to_array()
}

///|
pub fn pdf_bytes_to_fixed_array(bytes : PdfBytes) -> FixedArray[Byte] {
  bytes.to_fixedarray()
}

///|
pub fn pdf_name_of_bytes(bytes : PdfBytes) -> PdfName {
  PdfName(bytes)
}

///|
pub fn pdf_name_of_view(bytes : BytesView) -> PdfName {
  PdfName(bytes.to_owned())
}

///|
pub fn PdfName::bytes(self : PdfName) -> PdfBytes {
  self.0
}

///|
pub fn PdfName::view(self : PdfName) -> BytesView {
  self.0[:]
}

///|
pub fn PdfName::byte_length(self : PdfName) -> Int {
  self.0.length()
}
