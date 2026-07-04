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
  FlateOutputLimitExceeded(Int)
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
  PageRotationExpected(Int)
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
} derive(Debug, Eq, ToJson)
