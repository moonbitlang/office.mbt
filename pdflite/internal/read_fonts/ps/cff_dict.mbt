// Port of read-fonts 0.39.2 `src/ps/cff/dict.rs`.

///|
/// PostScript DICT operator.
pub(all) enum DictOperator {
  Version
  Notice
  FullName
  FamilyName
  Weight
  FontBbox
  CharstringsOffset
  PrivateDictRange
  VariationStoreOffset
  Copyright
  IsFixedPitch
  ItalicAngle
  UnderlinePosition
  UnderlineThickness
  PaintType
  CharstringType
  FontMatrix
  StrokeWidth
  FdArrayOffset
  FdSelectOffset
  BlueValues
  OtherBlues
  FamilyBlues
  FamilyOtherBlues
  SubrsOffset
  VariationStoreIndex
  BlueScale
  BlueShift
  BlueFuzz
  LanguageGroup
  ExpansionFactor
  Encoding
  Charset
  UniqueId
  Xuid
  SyntheticBase
  PostScript
  BaseFontName
  BaseFontBlend
  Ros
  CidFontVersion
  CidFontRevision
  CidFontType
  CidCount
  UidBase
  FontName
  StdHw
  StdVw
  DefaultWidthX
  NominalWidthX
  Blend
  StemSnapH
  StemSnapV
  ForceBold
  InitialRandomSeed
} derive(Eq, Debug)

///|
fn DictOperator::from_opcode(opcode : Int) -> DictOperator? {
  Some(
    match opcode {
      // Top DICT operators
      0 => Version
      1 => Notice
      2 => FullName
      3 => FamilyName
      4 => Weight
      5 => FontBbox
      13 => UniqueId
      14 => Xuid
      15 => Charset
      16 => Encoding
      17 => CharstringsOffset
      18 => PrivateDictRange
      24 => VariationStoreOffset
      // Private DICT operators
      6 => BlueValues
      7 => OtherBlues
      8 => FamilyBlues
      9 => FamilyOtherBlues
      10 => StdHw
      11 => StdVw
      19 => SubrsOffset
      20 => DefaultWidthX
      21 => NominalWidthX
      22 => VariationStoreIndex
      23 => Blend
      // Font DICT only uses PrivateDictRange
      _ => return None
    },
  )
}

///|
fn DictOperator::from_extended_opcode(opcode : Int) -> DictOperator? {
  Some(
    match opcode {
      // Top DICT operators
      0 => Copyright
      1 => IsFixedPitch
      2 => ItalicAngle
      3 => UnderlinePosition
      4 => UnderlineThickness
      5 => PaintType
      6 => CharstringType
      7 => FontMatrix
      8 => StrokeWidth
      20 => SyntheticBase
      21 => PostScript
      22 => BaseFontName
      23 => BaseFontBlend
      30 => Ros
      31 => CidFontVersion
      32 => CidFontRevision
      33 => CidFontType
      34 => CidCount
      35 => UidBase
      36 => FdArrayOffset
      37 => FdSelectOffset
      38 => FontName
      // Private DICT operators
      9 => BlueScale
      10 => BlueShift
      11 => BlueFuzz
      12 => StemSnapH
      13 => StemSnapV
      14 => ForceBold
      17 => LanguageGroup
      18 => ExpansionFactor
      19 => InitialRandomSeed
      _ => return None
    },
  )
}

///|
/// Either a PostScript DICT operator or a (numeric) operand.
priv enum Token {
  Operator(DictOperator)
  Operand(Number, BcdComponents?)
}

///|
fn parse_token(cursor : Cursor) -> Token raise PsError {
  // Escape opcode for accessing extensions.
  let b0 = cursor.read_u8()
  if b0 == 12 {
    let b1 = cursor.read_u8()
    match DictOperator::from_extended_opcode(b1) {
      Some(op) => Operator(op)
      None => raise InvalidDictOperator(b1)
    }
  } else {
    match b0 {
      28 | 29 | 32..=254 => Operand(I32(parse_int(cursor, b0)), None)
      30 => {
        let components = BcdComponents::parse(cursor)
        Operand(Fixed(components.value(false)), Some(components))
      }
      _ =>
        match DictOperator::from_opcode(b0) {
          Some(op) => Operator(op)
          None => raise InvalidDictOperator(b0)
        }
    }
  }
}

///|
/// PostScript DICT Operator with its associated operands.
///
/// Offsets are kept as the raw (possibly negative) 32-bit operand values;
/// Rust converts them with `as usize`.
pub(all) enum Entry {
  Version(Sid)
  Notice(Sid)
  FullName(Sid)
  FamilyName(Sid)
  Weight(Sid)
  FontBbox(FixedArray[@font_types.Fixed])
  CharstringsOffset(Int)
  /// Private DICT byte range `start..end` (as `usize`, i.e. `UInt64`).
  PrivateDictRange(UInt64, UInt64)
  VariationStoreOffset(Int)
  Copyright(Sid)
  IsFixedPitch(Bool)
  ItalicAngle(@font_types.Fixed)
  UnderlinePosition(@font_types.Fixed)
  UnderlineThickness(@font_types.Fixed)
  PaintType(Int)
  CharstringType(Int)
  FontMatrix(ScaledFontMatrix)
  StrokeWidth(@font_types.Fixed)
  FdArrayOffset(Int)
  FdSelectOffset(Int)
  BlueValues(Blues)
  OtherBlues(Blues)
  FamilyBlues(Blues)
  FamilyOtherBlues(Blues)
  SubrsOffset(Int)
  VariationStoreIndex(Int)
  BlueScale(@font_types.Fixed)
  BlueShift(@font_types.Fixed)
  BlueFuzz(@font_types.Fixed)
  LanguageGroup(Int)
  ExpansionFactor(@font_types.Fixed)
  Encoding(Int)
  Charset(Int)
  UniqueId(Int)
  Xuid
  SyntheticBase(Int)
  PostScript(Sid)
  BaseFontName(Sid)
  BaseFontBlend
  Ros(registry~ : Sid, ordering~ : Sid, supplement~ : @font_types.Fixed)
  CidFontVersion(@font_types.Fixed)
  CidFontRevision(@font_types.Fixed)
  CidFontType(Int)
  CidCount(Int)
  UidBase(Int)
  FontName(Sid)
  StdHw(@font_types.Fixed)
  StdVw(@font_types.Fixed)
  DefaultWidthX(@font_types.Fixed)
  NominalWidthX(@font_types.Fixed)
  StemSnapH(StemSnaps)
  StemSnapV(StemSnaps)
  ForceBold(Bool)
  InitialRandomSeed(Int)
} derive(Eq, Debug)

///|
/// Given a byte slice containing DICT data, returns all operators with their
/// associated operands (each either `Ok` or `Err`, like the upstream
/// iterator).
///
/// This performs appropriate type conversions and decodes deltas.
pub fn entries(
  dict_data : BytesView,
  blend_state? : BlendState? = None,
) -> Array[Result[Entry, PsError]] {
  let result = []
  let stack = Stack::new()
  let mut last_bcd_components : BcdComponents? = None
  let cursor = Cursor::new(dict_data)
  let mut cursor_pos = 0
  while cursor.remaining_bytes() != 0 {
    let token = parse_token(cursor) catch {
      InvalidDictOperator(_) => {
        // Some buggy fonts have invalid dict operators. Clear
        // the stack and attempt to continue.
        stack.clear()
        continue
      }
      e => {
        result.push(Err(e))
        continue
      }
    }
    match token {
      Operand(number, bcd_components) => {
        last_bcd_components = bcd_components
        stack.push(number) catch {
          e => result.push(Err(e))
        }
      }
      Operator(op) => {
        if op == Blend || op == VariationStoreIndex {
          guard blend_state is Some(state) else {
            result.push(Err(MissingBlendState))
            continue
          }
          if op == VariationStoreIndex {
            try {
              let ix = stack.get_i32(0)
              state.set_store_index(ix & 0xFFFF)
            } catch {
              e => {
                result.push(Err(e))
                continue
              }
            }
          }
          if op == Blend {
            stack.apply_blend(state) catch {
              e => result.push(Err(e))
            }
            continue
          }
        }
        if op == BlueScale {
          // FreeType parses BlueScale using a scaling factor of
          // 1000, presumably to capture more precision in the
          // fractional part. We do the same.
          if last_bcd_components is Some(bcd_components) {
            last_bcd_components = None
            // If the most recent numeric value was parsed as a
            // binary coded decimal then recompute the value using
            // the desired scaling and replace it on the stack
            ignore(stack.pop_fixed())
            stack.push_fixed(bcd_components.value(true)) catch {
              _ => return result
            }
          }
        }
        if op == FontMatrix {
          // FontMatrix is also parsed specially... *sigh*
          // Redo the entire thing with special scaling factors
          // Dump the current values
          stack.clear()
          last_bcd_components = None
          // Now reparse with dynamic scaling
          let cursor = Cursor::new(dict_data)
          cursor.advance_by(cursor_pos)
          if ScaledFontMatrix::parse(cursor) is Some(matrix) {
            result.push(Ok(FontMatrix(matrix)))
          }
          continue
        }
        last_bcd_components = None
        let entry = Result::Ok(parse_entry(op, stack)) catch { e => Err(e) }
        stack.clear()
        cursor_pos = cursor.position() catch { _ => 0 }
        result.push(entry)
      }
    }
  }
  result
}

///|
/// Returns only the successfully parsed entries
/// (`entries(..).filter_map(|e| e.ok())`).
pub fn ok_entries(dict_data : BytesView) -> Array[Entry] {
  let res = []
  for e in entries(dict_data) {
    if e is Ok(entry) {
      res.push(entry)
    }
  }
  res
}

///|
fn sid_of(v : Int) -> Sid {
  Sid::new(v)
}

///|
fn parse_entry(op : DictOperator, stack : Stack) -> Entry raise PsError {
  match op {
    Version => Version(sid_of(stack.pop_i32()))
    Notice => Notice(sid_of(stack.pop_i32()))
    FullName => FullName(sid_of(stack.pop_i32()))
    FamilyName => FamilyName(sid_of(stack.pop_i32()))
    Weight => Weight(sid_of(stack.pop_i32()))
    FontBbox =>
      FontBbox([
        stack.get_fixed(0),
        stack.get_fixed(1),
        stack.get_fixed(2),
        stack.get_fixed(3),
      ])
    CharstringsOffset => CharstringsOffset(stack.pop_i32())
    PrivateDictRange => {
      let len = stack.get_i32(0).to_uint64()
      let start = stack.get_i32(1).to_uint64()
      let end = start + len
      if end < start {
        raise oob()
      }
      PrivateDictRange(start, end)
    }
    VariationStoreOffset => VariationStoreOffset(stack.pop_i32())
    Copyright => Copyright(sid_of(stack.pop_i32()))
    IsFixedPitch => IsFixedPitch(stack.pop_i32() != 0)
    ItalicAngle => ItalicAngle(stack.pop_fixed())
    UnderlinePosition => UnderlinePosition(stack.pop_fixed())
    UnderlineThickness => UnderlineThickness(stack.pop_fixed())
    PaintType => PaintType(stack.pop_i32())
    CharstringType => CharstringType(stack.pop_i32())
    FontMatrix => abort("unreachable")
    StrokeWidth => StrokeWidth(stack.pop_fixed())
    FdArrayOffset => FdArrayOffset(stack.pop_i32())
    FdSelectOffset => FdSelectOffset(stack.pop_i32())
    BlueValues => {
      stack.apply_delta_prefix_sum()
      BlueValues(Blues::new(stack.fixed_values()))
    }
    OtherBlues => {
      stack.apply_delta_prefix_sum()
      OtherBlues(Blues::new(stack.fixed_values()))
    }
    FamilyBlues => {
      stack.apply_delta_prefix_sum()
      FamilyBlues(Blues::new(stack.fixed_values()))
    }
    FamilyOtherBlues => {
      stack.apply_delta_prefix_sum()
      FamilyOtherBlues(Blues::new(stack.fixed_values()))
    }
    SubrsOffset => SubrsOffset(stack.pop_i32())
    VariationStoreIndex => VariationStoreIndex(stack.pop_i32() & 0xFFFF)
    BlueScale => BlueScale(stack.pop_fixed())
    BlueShift => BlueShift(stack.pop_fixed())
    BlueFuzz => BlueFuzz(stack.pop_fixed())
    LanguageGroup => LanguageGroup(stack.pop_i32())
    ExpansionFactor => ExpansionFactor(stack.pop_fixed())
    Encoding => Encoding(stack.pop_i32())
    Charset => Charset(stack.pop_i32())
    UniqueId => UniqueId(stack.pop_i32())
    Xuid => Xuid
    SyntheticBase => SyntheticBase(stack.pop_i32())
    PostScript => PostScript(sid_of(stack.pop_i32()))
    BaseFontName => BaseFontName(sid_of(stack.pop_i32()))
    BaseFontBlend => BaseFontBlend
    Ros =>
      Ros(
        registry=sid_of(stack.get_i32(0)),
        ordering=sid_of(stack.get_i32(1)),
        supplement=stack.get_fixed(2),
      )
    CidFontVersion => CidFontVersion(stack.pop_fixed())
    CidFontRevision => CidFontRevision(stack.pop_fixed())
    CidFontType => CidFontType(stack.pop_i32())
    CidCount => CidCount(stack.pop_i32())
    UidBase => UidBase(stack.pop_i32())
    FontName => FontName(sid_of(stack.pop_i32()))
    StdHw => StdHw(stack.pop_fixed())
    StdVw => StdVw(stack.pop_fixed())
    DefaultWidthX => DefaultWidthX(stack.pop_fixed())
    NominalWidthX => NominalWidthX(stack.pop_fixed())
    StemSnapH => {
      stack.apply_delta_prefix_sum()
      StemSnapH(StemSnaps::new(stack.fixed_values()))
    }
    StemSnapV => {
      stack.apply_delta_prefix_sum()
      StemSnapV(StemSnaps::new(stack.fixed_values()))
    }
    ForceBold => ForceBold(stack.pop_i32() != 0)
    InitialRandomSeed => InitialRandomSeed(stack.pop_i32())
    // Blend is handled at the layer above
    Blend => abort("unreachable")
  }
}
