///|
/// A deferred stream-data slice read from an input cursor.
///
/// `position` and `length` identify the raw byte range in `input`; `crypt`
/// records the decryption operation to apply when the bytes are materialized.
/// This lets the reader keep large stream bodies lazy until a caller requests
/// their bytes.
pub(all) struct ToGet {
  input : @core.ByteCursor
  position : Int
  length : Int
  crypt : PdfStreamDataCrypt
} derive(Debug, Eq, ToJson)

///|
/// Storage state for a PDF stream body.
///
/// `StreamGot` stores already materialized bytes. `StreamToGet` stores a
/// deferred slice of an input buffer, optionally with stream decryption metadata
/// that is applied when the data is read.
pub(all) enum PdfStreamData {
  StreamGot(@core.PdfBytes)
  StreamToGet(ToGet)
} derive(Debug, Eq, ToJson)

///|
/// Decryption metadata associated with deferred stream data.
///
/// The variants correspond to the stream ciphers supported by the PDF security
/// handler. Object-specific ciphers store object number, generation, file key,
/// and key length; AES-V3 stores the already derived file key.
pub(all) enum PdfStreamDataCrypt {
  PdfStreamDataNoCrypt
  PdfStreamDataArc4Decrypt(Int, Int, @core.PdfBytes, Int)
  PdfStreamDataAesV2Decrypt(Int, Int, @core.PdfBytes, Int)
  PdfStreamDataAesV3Decrypt(@core.PdfBytes)
} derive(Debug, Eq, ToJson)

///|
/// A PDF stream object: dictionary metadata plus stream bytes.
///
/// The dictionary and data fields are mutable because helpers such as
/// `get_stream` and the dictionary update methods materialize stream data and
/// update stream dictionaries in place.
pub(all) struct PdfStream {
  mut dictionary : PdfObject
  mut data : PdfStreamData
} derive(Debug, Eq, ToJson)

///|
/// The core in-memory representation of a parsed PDF object.
///
/// Strings and names are byte-oriented PDF values, not MoonBit Unicode strings.
/// `PdfIndirect(number)` is an unresolved reference by object number; callers
/// that need the referenced object should resolve it through a `PdfDocument`.
pub(all) enum PdfObject {
  PdfNull
  PdfBoolean(Bool)
  PdfInteger(Int)
  PdfReal(Double)
  PdfString(@core.PdfBytes)
  PdfNameObject(@core.PdfName)
  PdfArray(Array[PdfObject])
  PdfDictionary(Array[(@core.PdfName, PdfObject)])
  PdfStreamObject(PdfStream)
  PdfIndirect(Int)
} derive(Debug, Eq, ToJson)
