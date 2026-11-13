///|
/// Object encryption algorithm used by the PDF security handlers.
///
/// ARC4 carries key length in bits and security-handler revision. AESV3 carries
/// whether the ISO/PDF 2.0 hash variant is in use.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfCryptType {
  PdfCryptARC4(Int32, Int32)
  PdfCryptAESV2
  PdfCryptAESV3(Bool)
}

///|
/// Error variants raised by pdflite parsing, writing, filtering, text, and
/// encryption APIs.
///
/// The variants intentionally stay specific enough for tests and callers to
/// distinguish malformed input classes, while most public APIs expose them
/// through the ordinary `raise PdfError` flow.
#derive(Debug, Eq, ToJson)
pub(all) suberror PdfError {
  InvalidByte(Int32)
  InvalidCursorPosition(Int32)
  InvalidReadLength(Int32)
  InvalidBit(Int32)
  InvalidBitCount(Int32)
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
  PredictorNotSupported(Int32)
  InvalidLZWData
  InvalidFlateData
  FlateOutputLimitExceeded(Int32)
  BadJPEGHeader
  BadJPEGString
  InvalidJPEGBlock
  JPEGDimensionsExpected
  BadPNG(String)
  BadJPEG2000Header
  JPEG2000DimensionsExpected
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
  PageRotationExpected(Int32)
  BadPageSpecification(String)
  BadCoordinateSpecification(String)
  BadRectangleSpecification(String)
  BadNumberArgument(String)
  BadPresentationEffect(String)
  SoftError(String)
  HardError(String)
  InsecurePathName(String)
  ContentOperatorExpected
  ContentOperandExpected
  FunctionExpected
  FunctionNotSupported(Int32)
  BadFunctionEvaluation(String)
  StartXRefExpected
  XRefExpected
  XRefEntryExpected
  TrailerExpected
  RootExpected
  BadRevision
  InvalidObjectNumber(Int32)
  BadDate
  InvalidUnicodeCodepoint(Int32)
  InvalidUTF16BE
  InvalidUTF8
  InvalidPDFDocEncoding(Int32)
  CryptoKeyExpected
  InvalidCryptoDataLength(Int32)
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
  EncryptionPermissionsMismatch(Int32, Int32)
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
  TitleExpected
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
}
