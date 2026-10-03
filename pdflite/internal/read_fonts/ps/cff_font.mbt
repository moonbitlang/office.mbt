// Port of read-fonts 0.39.2 `src/ps/cff/font.rs` (CFF version 1 only; CFF2
// fonts and variations are not supported by this port).

///|
/// An SID or CID font.
priv enum CffFontKind {
  /// A CFF font.
  Sid(
    strings~ : Index,
    private_dict_start~ : UInt64,
    private_dict_end~ : UInt64
  )
  /// A CFF font with an externally defined encoding.
  Cid(fd_select~ : FdSelect?, fd_array~ : Index)
}

///|
/// A CFF font.
///
/// The source data may be a raw CFF blob as embedded in a PDF or the content
/// of a CFF table in an OpenType font.
pub struct CffFontRef {
  data : BytesView
  is_cff2 : Bool
  upem : Int
  global_subrs : Index
  priv top_dict : TopDict
  top_dict_index : Int
}

///|
/// Creates a new font for the given CFF data.
///
/// Tries to determine the CFF version by reading the first byte of the
/// header.
///
/// For CFF blobs embedded in an OpenType font, the upem should be taken
/// from the `head` table. Otherwise, 1000 will be assumed.
pub fn CffFontRef::new(
  data : BytesView,
  top_dict_index : Int,
  upem : Int?,
) -> CffFontRef raise PsError {
  let version = read_u8_at(data, 0)
  match version {
    1 => CffFontRef::new_cff(data, top_dict_index, upem)
    // CFF2 is not supported by this port.
    _ => raise InvalidFontFormat
  }
}

///|
/// Creates a new font for the given CFF data.
pub fn CffFontRef::new_cff(
  data : BytesView,
  top_dict_index : Int,
  upem : Int?,
) -> CffFontRef raise PsError {
  let cff = Cff::read(data)
  let top_dict_data = cff.top_dicts().get(top_dict_index)
  if top_dict_index < 0 || top_dict_index > 0xFFFF {
    raise oob()
  }
  let top_dict = TopDict::new(
    data,
    top_dict_data,
    Format1(cff.strings()),
    false,
  )
  let top_upem = match top_dict.matrix {
    Some(mat) => mat.scale
    None => 1000
  }
  {
    data,
    is_cff2: false,
    upem: upem.unwrap_or(top_upem),
    global_subrs: Format1(cff.global_subrs()),
    top_dict,
    top_dict_index,
  }
}

///|
/// Returns the raw CFF blob.
pub fn CffFontRef::data(self : CffFontRef) -> BytesView {
  self.data
}

///|
/// Returns the CFF version (either 1 or 2).
pub fn CffFontRef::version(self : CffFontRef) -> Int {
  if self.is_cff2 {
    2
  } else {
    1
  }
}

///|
/// Returns true if this is a CID-keyed font.
pub fn CffFontRef::is_cid(self : CffFontRef) -> Bool {
  self.top_dict.kind is Cid(..)
}

///|
/// Returns the global subroutine index.
pub fn CffFontRef::global_subrs(self : CffFontRef) -> Index {
  self.global_subrs
}

///|
/// Returns the number of glyphs in the CFF font.
pub fn CffFontRef::num_glyphs(self : CffFontRef) -> Int {
  self.top_dict.charstrings.count()
}

///|
/// Returns the charstring index.
pub fn CffFontRef::charstrings(self : CffFontRef) -> Index {
  self.top_dict.charstrings
}

///|
/// Returns the string index.
pub fn CffFontRef::strings(self : CffFontRef) -> Index? {
  match self.top_dict.kind {
    Sid(strings~, ..) => Some(strings)
    _ => None
  }
}

///|
/// Returns the string for the given identifier.
pub fn CffFontRef::string(self : CffFontRef, sid : Sid) -> BytesView? {
  match sid.resolve_standard() {
    Ok(s) => Some(ascii_bytes(s))
    Err(idx) => {
      guard self.strings() is Some(strings) else { return None }
      try strings.get(idx) catch {
        _ => None
      } noraise {
        v => Some(v)
      }
    }
  }
}

///|
/// Returns the mapping for glyph identifiers.
///
/// For a CID font, this maps between CIDs and glyph identifiers.
/// Otherwise maps between SIDs and glyph identifiers.
pub fn CffFontRef::charset(self : CffFontRef) -> Charset? {
  guard self.top_dict.charset_offset is Some(offset) else { return None }
  try Charset::new(self.data, offset, self.top_dict.charstrings.count()) catch {
    _ => None
  } noraise {
    c => Some(c)
  }
}

///|
/// Returns the mapping from character codes to glyph identifiers.
pub fn CffFontRef::encoding(self : CffFontRef) -> Encoding? {
  guard self.charset() is Some(charset) else { return None }
  guard self.top_dict.encoding_offset is Some(offset) else { return None }
  let encoding = RawEncoding::new(self.data, offset) catch { _ => return None }
  Some({ encoding, charset, })
}

///|
/// Returns the top level font matrix.
pub fn CffFontRef::matrix(self : CffFontRef) -> ScaledFontMatrix? {
  self.top_dict.matrix
}

///|
/// Returns the units per em.
pub fn CffFontRef::upem(self : CffFontRef) -> Int {
  self.upem
}

///|
/// Returns the number of available subfonts.
pub fn CffFontRef::num_subfonts(self : CffFontRef) -> Int {
  match self.top_dict.kind {
    Sid(..) => 1
    Cid(fd_array~, ..) => fd_array.count() & 0xFFFF
  }
}

///|
/// Returns the subfont index for the given glyph.
pub fn CffFontRef::subfont_index(self : CffFontRef, gid : GlyphId) -> Int? {
  match self.top_dict.kind {
    Sid(..) => Some(0)
    Cid(fd_select~, ..) =>
      match fd_select {
        None => Some(0)
        Some(fds) => fds.font_index(gid)
      }
  }
}

///|
/// Returns the subfont with the given index and normalized variation
/// coordinates (which are ignored by this port).
pub fn CffFontRef::subfont(
  self : CffFontRef,
  index : Int,
  _coords : Array[@font_types.F2Dot14],
) -> Subfont raise PsError {
  match self.top_dict.kind {
    Sid(private_dict_start~, private_dict_end~, ..) =>
      Subfont::new(
        self.data,
        // `Range<u32>` converted back to `usize`
        private_dict_start & 0xFFFFFFFFUL,
        private_dict_end & 0xFFFFFFFFUL,
        None,
      )
    Cid(fd_array~, ..) => {
      let font_dict = FontDict::new(fd_array.get(index))
      Subfont::new(
        self.data,
        font_dict.private_dict_start,
        font_dict.private_dict_end,
        font_dict.matrix,
      )
    }
  }
}

///|
/// Returns the subfont and hinting parameters for the given index.
pub fn CffFontRef::subfont_hinted(
  self : CffFontRef,
  index : Int,
  _coords : Array[@font_types.F2Dot14],
) -> (Subfont, HintingParams) raise PsError {
  match self.top_dict.kind {
    Sid(private_dict_start~, private_dict_end~, ..) =>
      Subfont::new_hinted(
        self.data,
        private_dict_start & 0xFFFFFFFFUL,
        private_dict_end & 0xFFFFFFFFUL,
        None,
      )
    Cid(fd_array~, ..) => {
      let font_dict = FontDict::new(fd_array.get(index))
      Subfont::new_hinted(
        self.data,
        font_dict.private_dict_start,
        font_dict.private_dict_end,
        font_dict.matrix,
      )
    }
  }
}

///|
/// Returns the effective transform for the given subfont and optional size
/// in pixels per em.
pub fn CffFontRef::transform(
  self : CffFontRef,
  subfont : Subfont,
  ppem : Float?,
) -> Transform {
  let mut scale = match ppem {
    Some(ppem) => Some(Transform::compute_scale(ppem, self.upem))
    None => None
  }
  // Compute our font matrix and adjusted UPEM
  let scaled_matrix = match self.top_dict.matrix {
    Some(top_matrix) =>
      // We have a top dict matrix. Now check for a font dict matrix.
      match subfont.matrix {
        Some(sub_matrix) => {
          let scaling = if top_matrix.scale > 1 && sub_matrix.scale > 1 {
            if top_matrix.scale < sub_matrix.scale {
              top_matrix.scale
            } else {
              sub_matrix.scale
            }
          } else {
            1
          }
          // Concatenate and scale
          let matrix = combine_scaled(
            top_matrix.matrix,
            sub_matrix.matrix,
            scaling,
          )
          let scaled_upem = Fixed::from_bits(sub_matrix.scale).mul_div(
            Fixed::from_bits(top_matrix.scale),
            Fixed::from_bits(scaling),
          )
          // Then normalize
          Some(
            ScaledFontMatrix::{ matrix, scale: scaled_upem.to_bits(), }.normalize(),
          )
        }
        // Top matrix was already normalized on load
        None => Some(top_matrix)
      }
    // Just normalize if we have a subfont matrix
    None =>
      match subfont.matrix {
        Some(m) => Some(m.normalize())
        None => None
      }
  }
  // Now adjust our scale factor if necessary
  if scaled_matrix is Some(matrix) {
    // If the scaling factor from our matrix does not equal the nominal
    // UPEM of the font then adjust the scale.
    if matrix.scale != self.upem {
      // In this case, we need to force a scale for "unscaled"
      // requests in order to apply the adjusted UPEM from the
      // font matrix.
      let original_scale = scale.unwrap_or(Fixed::from_i32(64))
      scale = Some(
        original_scale.mul_div(
          Fixed::from_bits(self.upem),
          Fixed::from_bits(matrix.scale),
        ),
      )
    }
  }
  {
    matrix: match scaled_matrix {
      Some(m) => m.matrix
      None => FontMatrix::identity()
    },
    scale,
  }
}

///|
/// Evaluates the charstring for the requested glyph and sends the results
/// to the given sink.
///
/// Returns the advance with of the glyph in font units if the charstring
/// provides one.
pub fn CffFontRef::evaluate_charstring(
  self : CffFontRef,
  subfont : Subfont,
  gid : GlyphId,
  _coords : Array[@font_types.F2Dot14],
  sink : &CommandSink,
) -> Fixed? raise PsError {
  let charstrings = self.top_dict.charstrings
  let subrs = if subfont.subrs_offset != 0U {
    let off = subfont.subrs_offset.to_uint64()
    if off > self.data.length().to_uint64() {
      raise oob()
    }
    Index::new(self.data[off.to_int():], self.is_cff2)
  } else {
    Empty
  }
  let charstring_data = charstrings.get(gid.to_int())
  let ctx = CffContext::new(self.data, charstrings, self.global_subrs, subrs)
  match evaluate(ctx, charstring_data, sink) {
    Some(width) => Some(width + subfont.nominal_width)
    None => subfont.default_width
  }
}

///|
/// Draws the glyph with an optional size in ppem to the given pen.
///
/// Returns the advance width of the glyph if the charstring provides
/// one.
pub fn CffFontRef::draw(
  self : CffFontRef,
  subfont : Subfont,
  gid : GlyphId,
  coords : Array[@font_types.F2Dot14],
  ppem : Float?,
  pen : &@read_fonts.OutlinePen,
) -> Float? raise PsError {
  let pen_sink = PenSink::new(pen)
  let nop_filter = NopFilterSink::new(pen_sink)
  let transform = self.transform(subfont, ppem)
  let transformer = TransformSink::new(nop_filter, transform)
  let width = self.evaluate_charstring(subfont, gid, coords, transformer)
  match width {
    Some(w) => {
      let v = transform.transform_h_metric(w).to_f32()
      Some(if v > 0.0 { v } else { 0.0 })
    }
    None => None
  }
}

///|
/// Mapping from character codes to glyph identifiers.
pub struct Encoding {
  encoding : RawEncoding
  charset : Charset
}

///|
/// Returns the predefined encoding, if any. Otherwise this is a custom
/// encoding.
pub fn Encoding::predefined(self : Encoding) -> PredefinedEncoding? {
  match self.encoding {
    Predefined(pre) => Some(pre)
    _ => None
  }
}

///|
/// Returns the associated character set.
pub fn Encoding::charset(self : Encoding) -> Charset {
  self.charset
}

///|
/// Maps a character code to a glyph identifier.
pub fn Encoding::map(self : Encoding, code : Byte) -> GlyphId? {
  self.encoding.map(self.charset, code.to_int())
}

///|
/// Metadata for a CFF subfont.
///
/// A subfont is the collection of data read from both the Font DICT and
/// Private DICT structures. These determine the set of subroutines, metrics
/// and hinting parameters for some group of glyphs.
pub struct Subfont {
  mut subrs_offset : UInt
  mut default_width : Fixed?
  mut nominal_width : Fixed
  matrix : ScaledFontMatrix?
  mut vs_index : Int
}

///|
fn Subfont::new(
  data : BytesView,
  start : UInt64,
  end : UInt64,
  matrix : ScaledFontMatrix?,
) -> Subfont raise PsError {
  let subfont : Subfont = {
    subrs_offset: 0,
    default_width: None,
    nominal_width: Fixed::zero(),
    matrix,
    vs_index: 0,
  }
  let dict_data = get_range_u64(data, start, end)
  for entry in ok_entries(dict_data) {
    match entry {
      SubrsOffset(offset) => subfont.subrs_offset = subrs_offset(start, offset)
      VariationStoreIndex(index) => subfont.vs_index = index
      // FreeType truncates the width values to int on read
      DefaultWidthX(width) => subfont.default_width = Some(width.floor())
      NominalWidthX(width) => subfont.nominal_width = width.floor()
      _ => ()
    }
  }
  subfont
}

///|
fn Subfont::new_hinted(
  data : BytesView,
  start : UInt64,
  end : UInt64,
  matrix : ScaledFontMatrix?,
) -> (Subfont, HintingParams) raise PsError {
  let subfont : Subfont = {
    subrs_offset: 0,
    default_width: None,
    nominal_width: Fixed::zero(),
    matrix,
    vs_index: 0,
  }
  let params = HintingParams::default()
  let dict_data = get_range_u64(data, start, end)
  for entry in ok_entries(dict_data) {
    match entry {
      SubrsOffset(offset) => subfont.subrs_offset = subrs_offset(start, offset)
      VariationStoreIndex(index) => subfont.vs_index = index
      // FreeType truncates the width values to int on read
      DefaultWidthX(width) => subfont.default_width = Some(width.floor())
      NominalWidthX(width) => subfont.nominal_width = width.floor()
      BlueValues(values) => params.blues = values
      FamilyBlues(values) => params.family_blues = values
      OtherBlues(values) => params.other_blues = values
      FamilyOtherBlues(values) => params.family_other_blues = values
      BlueScale(value) => params.blue_scale = value
      BlueShift(value) => params.blue_shift = value
      BlueFuzz(value) => params.blue_fuzz = value
      LanguageGroup(group) => params.language_group = group
      _ => ()
    }
  }
  (subfont, params)
}

///|
/// `range.start.checked_add(offset as usize).ok_or(OutOfBounds)? as u32`
fn subrs_offset(start : UInt64, offset : Int) -> UInt raise PsError {
  let off = offset.to_uint64()
  let sum = start + off
  if sum < start {
    raise oob()
  }
  sum.to_uint()
}

///|
fn get_range_u64(
  data : BytesView,
  start : UInt64,
  end : UInt64,
) -> BytesView raise PsError {
  let len = data.length().to_uint64()
  if start > end || end > len {
    raise oob()
  }
  data[start.to_int():end.to_int()]
}

///|
/// Returns the offset to the local subroutine index from the start of the
/// CFF blob.
pub fn Subfont::subrs_offset(self : Subfont) -> UInt {
  self.subrs_offset
}

///|
/// Returns the default advance width.
pub fn Subfont::default_width(self : Subfont) -> Fixed? {
  self.default_width
}

///|
/// Returns the nominal advance width.
pub fn Subfont::nominal_width(self : Subfont) -> Fixed {
  self.nominal_width
}

///|
/// Returns the font matrix.
pub fn Subfont::matrix(self : Subfont) -> ScaledFontMatrix? {
  self.matrix
}

///|
/// Returns the default variation store index.
pub fn Subfont::vs_index(self : Subfont) -> Int {
  self.vs_index
}

///|
priv struct TopDict {
  charstrings : Index
  /// `None` represents the in-band "missing" offset (`u32::MAX`).
  charset_offset : Int?
  encoding_offset : Int?
  matrix : ScaledFontMatrix?
  kind : CffFontKind
}

///|
/// `MaybeOffset(offset as u32)`
fn maybe_offset(offset : Int) -> Int? {
  if offset == -1 {
    None
  } else {
    Some(offset)
  }
}

///|
fn TopDict::new(
  cff_data : BytesView,
  top_dict_data : BytesView,
  strings : Index,
  is_cff2 : Bool,
) -> TopDict raise PsError {
  let mut has_ros = false
  let mut charstrings : Index? = None
  // CFF fonts have a default charset and encoding offset of 0
  // which selects the standard Adobe encoding
  let mut charset_offset : Int? = if is_cff2 { None } else { Some(0) }
  let mut encoding_offset : Int? = if is_cff2 { None } else { Some(0) }
  let mut fd_array : Index? = None
  let mut fd_select : FdSelect? = None
  let mut private_dict_start = 0UL
  let mut private_dict_end = 0UL
  let mut matrix : ScaledFontMatrix? = None
  for entry in ok_entries(top_dict_data) {
    match entry {
      Ros(..) => has_ros = true
      CharstringsOffset(offset) =>
        charstrings = match get_from(cff_data, offset) {
          Some(data) =>
            try Index::new(data, is_cff2) catch {
              _ => None
            } noraise {
              ix => Some(ix)
            }
          None => None
        }
      Charset(offset) => charset_offset = maybe_offset(offset)
      Encoding(offset) => encoding_offset = maybe_offset(offset)
      FdArrayOffset(offset) =>
        fd_array = match get_from(cff_data, offset) {
          Some(data) =>
            try Index::new(data, is_cff2) catch {
              _ => None
            } noraise {
              ix => Some(ix)
            }
          None => None
        }
      FdSelectOffset(offset) =>
        fd_select = match get_from(cff_data, offset) {
          Some(data) =>
            try FdSelect::read(data) catch {
              _ => None
            } noraise {
              f => Some(f)
            }
          None => None
        }
      PrivateDictRange(start, end) => {
        // Fail early if our private dictionary is out of bounds
        ignore(get_range_u64(cff_data, start, end))
        private_dict_start = start
        private_dict_end = end
      }
      FontMatrix(font_matrix) =>
        // FreeType always normalizes this and the scaling factor
        // is dynamic so it won't make a difference to our users
        matrix = Some(font_matrix.normalize())
      _ => ()
    }
  }
  guard charstrings is Some(charstrings) else { raise MissingCharstrings }
  let kind = match fd_array {
    Some(fd_array) => Cid(fd_array~, fd_select~)
    None => {
      if has_ros || is_cff2 {
        // The font dict array is required for CID-keyed and CFF2 fonts
        raise MissingFdArray
      }
      Sid(strings~, private_dict_start~, private_dict_end~)
    }
  }
  { charset_offset, encoding_offset, charstrings, matrix, kind, }
}

///|
priv struct FontDict {
  private_dict_start : UInt64
  private_dict_end : UInt64
  matrix : ScaledFontMatrix?
}

///|
fn FontDict::new(dict_data : BytesView) -> FontDict raise PsError {
  let mut range : (UInt64, UInt64)? = None
  let mut matrix : ScaledFontMatrix? = None
  for entry in entries(dict_data) {
    match entry {
      Err(e) => raise e
      Ok(PrivateDictRange(start, end)) => range = Some((start, end))
      Ok(FontMatrix(font_matrix)) => matrix = Some(font_matrix)
      _ => ()
    }
  }
  guard range is Some((start, end)) else { raise MissingPrivateDict }
  { private_dict_start: start, private_dict_end: end, matrix, }
}
