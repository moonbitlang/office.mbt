///|
/// Read and parse a PDF document from a file.
///
/// File bytes are loaded asynchronously and then passed to the byte reader.
pub async fn pdf_read_document_from_file(
  path : StringView,
) -> @pdflite.PdfDocument {
  @pdflite.pdf_read_document_from_bytes(@fs.read_file(path).binary())
}

///|
/// Read a specific PDF revision from a file.
///
/// Revision numbering follows the core reader: revision `1` is the newest
/// revision and larger numbers walk backward through `/Prev`.
pub async fn pdf_read_document_revision_from_file(
  path : StringView,
  revision : Int,
) -> @pdflite.PdfDocument {
  @pdflite.pdf_read_document_revision_from_bytes(
    @fs.read_file(path).binary(),
    revision,
  )
}

///|
/// Count revisions in a PDF file.
pub async fn pdf_revisions_from_file(path : StringView) -> Int {
  @pdflite.pdf_revisions_from_bytes(@fs.read_file(path).binary())
}

///|
/// Read only the PDF header version from a file.
///
/// The same header-probe rules as `pdf_read_header_from_bytes` apply.
pub async fn pdf_read_header_from_file(
  path : StringView,
) -> @pdflite.PdfVersion {
  @pdflite.pdf_read_header_from_bytes(@fs.read_file(path).binary())
}

///|
/// Return true if a file appears to be linearized.
pub async fn pdf_is_linearized_file(path : StringView) -> Bool {
  @pdflite.pdf_is_linearized(@fs.read_file(path).binary())
}

///|
fn pdf_async_io_join_directory_file(
  directory : StringView,
  filename : String,
) -> String {
  let text = directory.to_owned()
  if text.length() == 0 {
    filename
  } else {
    let last = text.at(text.length() - 1).to_int()
    if last == 47 || last == 92 {
      text + filename
    } else {
      text + "/" + filename
    }
  }
}

///|
/// Load cpdf's Standard 14 substitute font file from a directory.
///
/// This mirrors `cpdfembed.ml`'s `load_substitute`: choose the URW substitute
/// filename for `font`, read it from `directory`, and return the file bytes
/// together with the extension-stripped font name.
pub async fn pdf_load_standard_font_substitute_file(
  directory : StringView,
  font : @pdflite.PdfStandardFont,
) -> (@pdflite.PdfBytes, String) {
  let filename = @pdflite.pdf_standard_font_substitute_filenames(font)[0]
  (
    @fs.read_file(pdf_async_io_join_directory_file(directory, filename)).binary(),
    @pdflite.pdf_standard_font_substitute_font_name(font),
  )
}

///|
/// Compatibility wrapper matching cpdfembed's `load_substitute`.
pub async fn pdf_load_substitute(
  directory : StringView,
  font : @pdflite.PdfStandardFont,
) -> (@pdflite.PdfBytes, String) {
  pdf_load_standard_font_substitute_file(directory, font)
}

///|
/// Extract an embedded font file and write it to disk.
///
/// This is the native filesystem counterpart of cpdffont's `extract_fontfile`.
/// Font lookup and stream decoding are delegated to the core
/// `PdfDocument::extract_fontfile_bytes` API.
pub async fn pdf_extract_fontfile_to_file(
  document : @pdflite.PdfDocument,
  page_number : Int,
  font_name : String,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  match document.extract_fontfile_bytes(page_number, font_name) {
    Some(data) => @fs.write_file(path, data, create=permission)
    None => @pdflite.pdf_error("extract_fontfile: unsupported or unfound font")
  }
}

///|
/// Compatibility wrapper matching cpdffont's `extract_fontfile` argument order.
pub async fn pdf_extract_fontfile(
  page_number : Int,
  font_name : String,
  path : StringView,
  document : @pdflite.PdfDocument,
  permission? : Int = 0o644,
) -> Unit {
  pdf_extract_fontfile_to_file(
    document,
    page_number,
    font_name,
    path,
    permission~,
  )
}

///|
fn pdf_async_io_extracted_image_has_smask(
  stem : String,
  files : ArrayView[@pdflite.PdfExtractedImageFile],
) -> Bool {
  let mask_prefix = stem + "-smask."
  for file in files {
    if file.path.has_prefix(mask_prefix) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_async_io_extracted_image_has_any_smask(
  files : ArrayView[@pdflite.PdfExtractedImageFile],
) -> Bool {
  for file in files {
    if file.path.contains("-smask") {
      break true
    }
  } nobreak {
    false
  }
}

///|
/// Extract one image object and write cpdf-style image files to disk.
///
/// This is the native filesystem counterpart of cpdfimage's
/// `extract_single_image`. The core extraction path emits raw PNM for decoded
/// image data; external PNM-to-PNG conversion remains outside this wrapper.
pub async fn pdf_extract_single_image_to_files(
  document : @pdflite.PdfDocument,
  object_number : Int,
  stem : StringView,
  raw? : Bool = false,
  path_to_p2p? : String = "",
  path_to_im? : String = "",
  merge_masks? : Bool = false,
  permission? : Int = 0o644,
) -> Array[String] {
  ignore(raw)
  ignore(path_to_p2p)
  ignore(path_to_im)
  let stem_text = stem.to_owned()
  let files = document.extract_single_image_files(object_number, stem_text)
  let paths : Array[String] = []
  for file in files {
    @fs.write_file(file.path, file.data, create=permission)
    paths.push(file.path)
  }
  if merge_masks && pdf_async_io_extracted_image_has_smask(stem_text, files) {
    @pdflite.pdf_error("combine_image_and_mask: imagemagick not found")
  }
  paths
}

///|
/// Compatibility wrapper matching cpdfimage's `extract_single_image`.
pub async fn pdf_extract_single_image(
  merge_masks : Bool,
  encoding : @pdflite.PdfMetadataEncoding,
  document : @pdflite.PdfDocument,
  object_number : Int,
  stem : StringView,
  raw? : Bool = false,
  path_to_p2p? : String = "",
  path_to_im? : String = "",
  permission? : Int = 0o644,
) -> Unit {
  ignore(encoding)
  ignore(
    pdf_extract_single_image_to_files(
      document,
      object_number,
      stem,
      raw~,
      path_to_p2p~,
      path_to_im~,
      merge_masks~,
      permission~,
    ),
  )
}

///|
/// Extract page images and write cpdf-style image files to disk.
///
/// This is the native filesystem counterpart of cpdfimage's `extract_images`.
/// The core extraction path emits raw PNM for decoded image data; external
/// PNM-to-PNG conversion remains outside this wrapper.
pub async fn pdf_extract_images_to_files(
  document : @pdflite.PdfDocument,
  page_numbers : ArrayView[Int],
  stem : StringView,
  encoding? : @pdflite.PdfMetadataEncoding = PdfMetadataUTF8,
  inline? : Bool = false,
  dedup? : Bool = false,
  dedup_per_page? : Bool = false,
  raw? : Bool = false,
  path_to_p2p? : String = "",
  path_to_im? : String = "",
  merge_masks? : Bool = false,
  permission? : Int = 0o644,
) -> Array[String] {
  ignore(raw)
  ignore(path_to_p2p)
  ignore(path_to_im)
  let files = document.extract_images_files(
    page_numbers,
    stem.to_owned(),
    encoding~,
    inline~,
    dedup~,
    dedup_per_page~,
  )
  let paths : Array[String] = []
  for file in files {
    @fs.write_file(file.path, file.data, create=permission)
    paths.push(file.path)
  }
  if merge_masks && pdf_async_io_extracted_image_has_any_smask(files) {
    @pdflite.pdf_error("combine_image_and_mask: imagemagick not found")
  }
  paths
}

///|
/// Compatibility wrapper matching cpdfimage's `extract_images`.
pub async fn pdf_extract_images(
  merge_masks : Bool,
  inline : Bool,
  encoding : @pdflite.PdfMetadataEncoding,
  dedup : Bool,
  dedup_per_page : Bool,
  document : @pdflite.PdfDocument,
  page_numbers : ArrayView[Int],
  stem : StringView,
  raw? : Bool = false,
  path_to_p2p? : String = "",
  path_to_im? : String = "",
  permission? : Int = 0o644,
) -> Unit {
  ignore(
    pdf_extract_images_to_files(
      document,
      page_numbers,
      stem,
      encoding~,
      inline~,
      dedup~,
      dedup_per_page~,
      raw~,
      path_to_p2p~,
      path_to_im~,
      merge_masks~,
      permission~,
    ),
  )
}

///|
fn pdf_draw_control_image_file_spec_for_async_io(
  spec : StringView,
  command : String,
) -> (String, String) raise @pdflite.PdfError {
  let text = spec.to_owned()
  let mut separator = -1
  for index in 0..<text.length() {
    if text.at(index).to_int() == 61 {
      if separator >= 0 {
        @pdflite.pdf_error(command + ": bad file specification")
      }
      separator = index
    }
  }
  if separator < 0 {
    @pdflite.pdf_error(command + ": bad file specification")
  }
  (text[:separator].to_owned(), text[separator + 1:].to_owned())
}

///|
/// Read a JPEG file and append it as a draw-control image XObject.
///
/// `spec` follows cpdf's `addjpeg` file form: `Name=/path/to/image.jpg`.
pub async fn pdf_draw_control_add_jpeg_file(
  control : @pdflite.PdfDrawControl,
  spec : StringView,
) -> Unit {
  let (name, path) = pdf_draw_control_image_file_spec_for_async_io(
    spec, "addjpeg",
  )
  control.add_jpeg_data(name, @fs.read_file(path).binary())
}

///|
/// Compatibility wrapper matching cpdfjpeg's `backup_jpeg_dimensions`.
///
/// The original cpdf implementation shells out to ImageMagick. This native
/// wrapper keeps the same file boundary but uses pdflite's SOF-marker scanner,
/// so `path_to_im` is accepted for API parity and otherwise ignored.
pub async fn pdf_backup_jpeg_dimensions(
  filename : StringView,
  path_to_im? : String = "",
) -> (Int, Int) {
  ignore(path_to_im)
  @pdflite.pdf_jpeg_backup_dimensions_view(@fs.read_file(filename).binary())
}

///|
/// Read a PNG file and append it as a draw-control image XObject.
///
/// `spec` follows cpdf's `addpng` file form: `Name=/path/to/image.png`.
pub async fn pdf_draw_control_add_png_file(
  control : @pdflite.PdfDrawControl,
  document : @pdflite.PdfDocument,
  spec : StringView,
) -> Unit {
  let (name, path) = pdf_draw_control_image_file_spec_for_async_io(
    spec, "addpng",
  )
  control.add_png_data(document, name, @fs.read_file(path).binary())
}

///|
/// Read a JPEG2000 file and append it as a draw-control image XObject.
///
/// `spec` follows cpdf's `addjpeg2000` file form:
/// `Name=/path/to/image.jp2`.
pub async fn pdf_draw_control_add_jpeg2000_file(
  control : @pdflite.PdfDrawControl,
  spec : StringView,
) -> Unit {
  let (name, path) = pdf_draw_control_image_file_spec_for_async_io(
    spec, "addjpeg2000",
  )
  control.add_jpeg2000_data(name, @fs.read_file(path).binary())
}

///|
/// Read a file and decrypt it with optional user and owner passwords.
///
/// Returns `None` when the file is encrypted and no supplied password
/// authenticates. Unencrypted files return a successful decryption result with
/// empty denied permissions.
pub async fn pdf_read_document_from_file_with_passwords(
  path : StringView,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> @pdflite.PdfDecryptionResult? {
  @pdflite.pdf_read_document_from_bytes_with_passwords(
    @fs.read_file(path).binary(),
    user_password~,
    owner_password~,
  )
}

///|
/// Read a specific revision from a file and decrypt it with optional passwords.
///
/// Returns `None` when the revision is encrypted and no supplied password
/// authenticates.
pub async fn pdf_read_document_revision_from_file_with_passwords(
  path : StringView,
  revision : Int,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> @pdflite.PdfDecryptionResult? {
  @pdflite.pdf_read_document_revision_from_bytes_with_passwords(
    @fs.read_file(path).binary(),
    revision,
    user_password~,
    owner_password~,
  )
}

///|
/// Serialize a document with a classic xref table and write it to a file.
///
/// `permission` is passed as the creation mode when the file is created.
pub async fn pdf_write_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(path, @pdflite.pdf_write_document(document), create=permission)
}

///|
/// Serialize a document with an uncompressed xref stream and write it to a file.
pub async fn pdf_write_document_to_file_with_xref_stream(
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_with_xref_stream(document),
    create=permission,
  )
}

///|
/// Serialize a document with a Flate-compressed xref stream and write it to a file.
pub async fn pdf_write_document_to_file_with_compressed_xref_stream(
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_with_compressed_xref_stream(document),
    create=permission,
  )
}

///|
/// Serialize a document using the selected write mode and write it to a file.
pub async fn pdf_write_document_to_file_with_mode(
  document : @pdflite.PdfDocument,
  path : StringView,
  mode : @pdflite.PdfWriteMode,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_with_mode(document, mode),
    create=permission,
  )
}

///|
/// Generate a current trailer ID, serialize, and write the document to a file.
///
/// The output path is used as the ID-generation path input.
pub async fn pdf_write_document_to_file_with_generated_id(
  document : @pdflite.PdfDocument,
  path : StringView,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_with_generated_id(
      document,
      path.to_owned(),
      mode~,
    ),
    create=permission,
  )
}

///|
/// Encrypt with 40-bit ARC4, serialize, and write to a file.
pub async fn pdf_write_encrypted_40bit_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_40bit_document(
      document,
      user_password,
      owner_password,
      denied_permissions,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
/// One filesystem path to embed in a PDF portfolio.
///
/// `filename` is both the path read from disk and the source name used for the
/// generated portfolio entry.
pub(all) struct PdfPortfolioFileEntry {
  filename : String
  relationship : String?
  description : String?
} derive(Debug, Eq, ToJson)

///|
/// Construct a filesystem-backed portfolio entry.
pub fn pdf_portfolio_file_entry(
  filename : String,
  relationship? : String? = None,
  description? : String? = None,
) -> PdfPortfolioFileEntry {
  { filename, relationship, description }
}

///|
/// Read files from disk and build a PDF portfolio.
///
/// PDF object construction is delegated to the core `PdfDocument::portfolio`
/// API; this package only owns the native filesystem reads.
pub async fn pdf_portfolio_from_files(
  document : @pdflite.PdfDocument,
  entries : ArrayView[PdfPortfolioFileEntry],
  mod_date? : @pdflite.PdfBytes? = None,
) -> @pdflite.PdfDocument {
  let loaded : Array[@pdflite.PdfPortfolioEntry] = []
  for entry in entries {
    loaded.push(
      @pdflite.pdf_portfolio_entry(
        entry.filename,
        @fs.read_file(entry.filename).binary(),
        relationship=entry.relationship,
        description=entry.description,
      ),
    )
  }
  @pdflite.pdf_portfolio(document, loaded, mod_date~)
}

///|
fn pdf_async_io_name(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_async_io_join_path(directory : StringView, filename : String) -> String {
  let dir = directory.to_owned()
  if dir == "" {
    filename
  } else {
    dir + "/" + filename
  }
}

///|
fn pdf_async_io_attachment_data(
  attachment : @pdflite.PdfAttachment,
) -> @pdflite.PdfBytes raise @pdflite.PdfError {
  match attachment.data {
    Some(data) => data
    None => raise DictionaryKeyNotFound(pdf_async_io_name("/EF"))
  }
}

///|
/// Read a filesystem path and attach its bytes to the document.
///
/// PDF object construction is delegated to the core in-memory attachment API;
/// this wrapper only owns the native filesystem read. `path` is also used as
/// the source filename, so the core API stores its basename in the file spec.
pub async fn pdf_attach_file_from_path(
  document : @pdflite.PdfDocument,
  path : StringView,
  keep_version? : Bool = false,
  page_number? : Int? = None,
  relationship? : String? = None,
  description? : String? = None,
) -> @pdflite.PdfDocument {
  @pdflite.pdf_attach_file(
    document,
    path.to_owned(),
    @fs.read_file(path).binary(),
    keep_version~,
    page_number~,
    relationship~,
    description~,
  )
}

///|
fn pdf_async_io_catalog_metadata_number(
  document : @pdflite.PdfDocument,
) -> Int? raise @pdflite.PdfError {
  let root = match
    document.lookup_direct(pdf_async_io_name("/Root"), document.trailer_dict()) {
    Some(root) => root
    None => raise SoftError("malformed file")
  }
  root.find_indirect(pdf_async_io_name("/Metadata"))
}

///|
fn pdf_async_io_is_metadata_object(
  document : @pdflite.PdfDocument,
  object : @pdflite.PdfObject,
) -> Bool {
  match document.lookup_direct(pdf_async_io_name("/Type"), object) {
    Some(PdfNameObject(name)) => name == pdf_async_io_name("/Metadata")
    _ => false
  }
}

///|
fn pdf_async_io_metadata_stream_bytes(
  document : @pdflite.PdfDocument,
  object : @pdflite.PdfObject,
) -> @pdflite.PdfBytes raise @pdflite.PdfError {
  document.pdf_decode_stream(object).stream_bytes()
}

///|
/// Set the catalog metadata XML stream from a file.
///
/// This is the native filesystem counterpart of cpdfmetadata's
/// `set_metadata`: the file is read as bytes and delegated to the portable
/// in-memory metadata setter.
pub async fn pdf_set_metadata_from_file(
  keep_version : Bool,
  path : StringView,
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument {
  document.set_metadata_from_bytes(@fs.read_file(path).binary(), keep_version~)
}

///|
/// Write the catalog metadata XML stream to a file when one is present.
///
/// A document without catalog metadata is a no-op, matching cpdfmetadata's
/// `print_metadata` behavior of emitting nothing when metadata is absent.
pub async fn pdf_write_metadata_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  match document.metadata() {
    Some(metadata) => @fs.write_file(path, metadata, create=permission)
    None => ()
  }
}

///|
/// Extract every metadata stream to `directory`.
///
/// The catalog metadata object is written as `main.xml`, and other parsed
/// `/Type /Metadata` stream objects are written as `obj<num>.xml`, matching
/// cpdfmetadata's `extract_all_metadata` naming scheme.
pub async fn pdf_extract_all_metadata_to_directory(
  document : @pdflite.PdfDocument,
  directory : StringView,
  permission? : Int = 0o644,
) -> Unit {
  let main_number = pdf_async_io_catalog_metadata_number(document)
  match main_number {
    Some(number) =>
      @fs.write_file(
        pdf_async_io_join_path(directory, "main.xml"),
        pdf_async_io_metadata_stream_bytes(
          document,
          document.lookup_object_or_null(number),
        ),
        create=permission,
      )
    None => ()
  }
  for entry in document.parsed_object_entries() {
    if Some(entry.0) != main_number &&
      pdf_async_io_is_metadata_object(document, entry.2) {
      @fs.write_file(
        pdf_async_io_join_path(directory, "obj" + entry.0.to_string() + ".xml"),
        pdf_async_io_metadata_stream_bytes(document, entry.2),
        create=permission,
      )
    }
  }
}

///|
/// Dump all listed attachments into `directory`.
///
/// Attachment names are sanitized with the core cpdf-compatible filename
/// filter. Existing files with the same sanitized name are overwritten by
/// `@fs.write_file`, matching cpdf's simple filename-based dump behavior.
pub async fn pdf_dump_attached_files_to_directory(
  document : @pdflite.PdfDocument,
  directory : StringView,
  permission? : Int = 0o644,
) -> Unit {
  for attachment in document.list_attached_files() {
    let filename = @pdflite.pdf_attachment_remove_unsafe_characters(
      attachment.name,
    )
    @fs.write_file(
      pdf_async_io_join_path(directory, filename),
      pdf_async_io_attachment_data(attachment),
      create=permission,
    )
  }
}

///|
/// Encrypt with 128-bit ARC4 revision 3, serialize, and write to a file.
pub async fn pdf_write_encrypted_128bit_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_128bit_document(
      document,
      user_password,
      owner_password,
      denied_permissions,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
/// Encrypt with revision-4 ARC4 crypt filters, serialize, and write to a file.
///
/// `encrypt_metadata=false` preserves the PDF no-metadata encryption behavior.
pub async fn pdf_write_encrypted_128bit_r4_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  encrypt_metadata? : Bool = true,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_128bit_r4_document(
      document,
      user_password,
      owner_password,
      denied_permissions,
      encrypt_metadata~,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
/// Encrypt with AESV2 using caller-supplied IVs, serialize, and write to a file.
pub async fn pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  iv_provider : (Int, Int, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
  encrypt_metadata? : Bool = true,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_aesv2_document_with_iv_provider(
      document,
      user_password,
      owner_password,
      denied_permissions,
      iv_provider,
      encrypt_metadata~,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
/// Encrypt with AESV2 using the native random IV provider and write to a file.
///
/// This convenience helper is intended for the native async target.
pub async fn pdf_write_encrypted_aesv2_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  encrypt_metadata? : Bool = true,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_aesv2_document(
      document,
      user_password,
      owner_password,
      denied_permissions,
      encrypt_metadata~,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
/// Encrypt with AESV3/AES-256 using caller-supplied providers and write to a file.
///
/// `random_provider` supplies file key and salts; `iv_provider` supplies object
/// IVs. `iso=true` selects the ISO/PDF 2.0 hash variant.
pub async fn pdf_write_encrypted_aesv3_document_to_file_with_providers(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  random_provider : (@pdflite.PdfAesV3RandomField, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
  iv_provider : (Int, Int, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
  iso? : Bool = false,
  encrypt_metadata? : Bool = true,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_aesv3_document_with_providers(
      document,
      user_password,
      owner_password,
      denied_permissions,
      random_provider,
      iv_provider,
      iso~,
      encrypt_metadata~,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
/// Encrypt with AESV3/AES-256 using native random providers and write to a file.
///
/// `iso=true` selects the ISO/PDF 2.0 hash variant.
pub async fn pdf_write_encrypted_aesv3_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  iso? : Bool = false,
  encrypt_metadata? : Bool = true,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_aesv3_document(
      document,
      user_password,
      owner_password,
      denied_permissions,
      iso~,
      encrypt_metadata~,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
/// Encrypt with the ISO AESV3/AES-256 variant using supplied providers.
pub async fn pdf_write_encrypted_aesv3_iso_document_to_file_with_providers(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  random_provider : (@pdflite.PdfAesV3RandomField, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
  iv_provider : (Int, Int, Int) -> @pdflite.PdfBytes raise @pdflite.PdfError,
  encrypt_metadata? : Bool = true,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_aesv3_iso_document_with_providers(
      document,
      user_password,
      owner_password,
      denied_permissions,
      random_provider,
      iv_provider,
      encrypt_metadata~,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
/// Encrypt with the ISO AESV3/AES-256 variant using native random providers.
pub async fn pdf_write_encrypted_aesv3_iso_document_to_file(
  document : @pdflite.PdfDocument,
  path : StringView,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
  encrypt_metadata? : Bool = true,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_encrypted_aesv3_iso_document(
      document,
      user_password,
      owner_password,
      denied_permissions,
      encrypt_metadata~,
      mode~,
      file_id~,
    ),
    create=permission,
  )
}

///|
/// Append a classic incremental update to `original_path` and write `path`.
pub async fn pdf_write_document_incremental_update_to_file(
  original_path : StringView,
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_incremental_update(
      @fs.read_file(original_path).binary(),
      document,
    ),
    create=permission,
  )
}

///|
/// Append an incremental update with an uncompressed xref stream.
pub async fn pdf_write_document_incremental_update_with_xref_stream_to_file(
  original_path : StringView,
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_incremental_update_with_xref_stream(
      @fs.read_file(original_path).binary(),
      document,
    ),
    create=permission,
  )
}

///|
/// Append an incremental update with a Flate-compressed xref stream.
pub async fn pdf_write_document_incremental_update_with_compressed_xref_stream_to_file(
  original_path : StringView,
  document : @pdflite.PdfDocument,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_incremental_update_with_compressed_xref_stream(
      @fs.read_file(original_path).binary(),
      document,
    ),
    create=permission,
  )
}

///|
/// Append an incremental update using the selected write mode.
pub async fn pdf_write_document_incremental_update_to_file_with_mode(
  original_path : StringView,
  document : @pdflite.PdfDocument,
  path : StringView,
  mode : @pdflite.PdfWriteMode,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_incremental_update_with_mode(
      @fs.read_file(original_path).binary(),
      document,
      mode,
    ),
    create=permission,
  )
}

///|
/// Generate a current trailer ID and append an incremental update to a file.
///
/// The output path is used as the ID-generation path input.
pub async fn pdf_write_document_incremental_update_to_file_with_generated_id(
  original_path : StringView,
  document : @pdflite.PdfDocument,
  path : StringView,
  mode? : @pdflite.PdfWriteMode = PdfWriteClassic,
  permission? : Int = 0o644,
) -> Unit {
  @fs.write_file(
    path,
    @pdflite.pdf_write_document_incremental_update_with_generated_id(
      @fs.read_file(original_path).binary(),
      document,
      path.to_owned(),
      mode~,
    ),
    create=permission,
  )
}
