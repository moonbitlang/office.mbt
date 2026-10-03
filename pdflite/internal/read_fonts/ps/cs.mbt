// Port of read-fonts 0.39.2 `src/ps/cs.rs`: parsing and evaluation of
// charstrings.

///|
/// Maximum nesting depth for subroutine calls.
pub const NESTING_DEPTH_LIMIT : Int = 10

///|
/// The type of a PostScript charstring.
pub(all) enum CharstringKind {
  /// Type1 charstring.
  Type1
  /// Type2 charstring.
  Type2
} derive(Eq, Debug)

///|
/// Trait that provides context for charstring evaluation.
pub(open) trait CharstringContext {
  /// Returns the type of the charstring.
  fn kind(Self) -> CharstringKind
  /// Returns the base and accent charstrings for the `seac` (standard
  /// encoded accented character) operator.
  fn seac_components(Self, Int, Int) -> (BytesView, BytesView) raise PsError
  /// Returns the charstring for the global subroutine at the given index as
  /// encoded in the calling charstring.
  fn global_subr(Self, Int) -> BytesView raise PsError
  /// Returns the charstring for the local subroutine at the given index as
  /// encoded in the calling charstring.
  fn subr(Self, Int) -> BytesView raise PsError
  /// Returns the current active weight vector for a multiple master font.
  fn weight_vector(Self) -> Array[Fixed]
}

///|
/// Context for evaluating CFF charstrings: (cff_blob, charstrings,
/// global_subrs, subrs).
pub struct CffContext {
  data : BytesView
  charstrings : Index
  global_subrs : Index
  subrs : Index
}

///|
pub fn CffContext::new(
  data : BytesView,
  charstrings : Index,
  global_subrs : Index,
  subrs : Index,
) -> CffContext {
  { data, charstrings, global_subrs, subrs, }
}

///|
pub impl CharstringContext for CffContext with fn kind(_self) {
  Type2
}

///|
pub impl CharstringContext for CffContext with fn seac_components(
  self,
  base_code,
  accent_code,
) {
  let cff = Cff::read(self.data)
  let charset = match cff.charset(0) {
    Some(c) => c
    None =>
      Charset::new(b""[:], 0, self.charstrings.count()) catch {
        _ => raise MissingCharset
      }
  }
  let seac_to_gid = fn(code : Int) -> GlyphId? {
    if code < 0 || code > 255 {
      return None
    }
    let sid = standard_encoding[code]
    try charset.glyph_id(Sid::new(sid)) catch {
      _ => None
    } noraise {
      g => Some(g)
    }
  }
  guard seac_to_gid(accent_code) is Some(accent_gid) else {
    raise InvalidSeacCode(accent_code)
  }
  guard seac_to_gid(base_code) is Some(base_gid) else {
    raise InvalidSeacCode(base_code)
  }
  let accent_charstring = self.charstrings.get(accent_gid.to_int())
  let base_charstring = self.charstrings.get(base_gid.to_int())
  (base_charstring, accent_charstring)
}

///|
pub impl CharstringContext for CffContext with fn global_subr(self, index) {
  self.global_subrs.get(index + self.global_subrs.subr_bias())
}

///|
pub impl CharstringContext for CffContext with fn subr(self, index) {
  self.subrs.get(index + self.subrs.subr_bias())
}

///|
pub impl CharstringContext for CffContext with fn weight_vector(_self) {
  []
}

///|
/// Trait for processing commands resulting from charstring evaluation.
///
/// During processing, the path construction operators are simplified into
/// the basic move, line, curve and close commands.
///
/// This also has callbacks for processing hint operators.
pub(open) trait CommandSink {
  // Path construction operators.
  fn move_to(Self, Fixed, Fixed) -> Unit
  fn line_to(Self, Fixed, Fixed) -> Unit
  fn curve_to(Self, Fixed, Fixed, Fixed, Fixed, Fixed, Fixed) -> Unit
  fn close(Self) -> Unit
  // Hint operators.
  /// Horizontal stem hint at `y` with height `dy`.
  fn hstem(Self, Fixed, Fixed) -> Unit
  /// Vertical stem hint at `x` with width `dx`.
  fn vstem(Self, Fixed, Fixed) -> Unit
  /// Bitmask defining the hints that should be made active for the
  /// commands that follow.
  fn hint_mask(Self, BytesView) -> Unit
  /// Bitmask defining the counter hints that should be made active for the
  /// commands that follow.
  fn counter_mask(Self, BytesView) -> Unit
  /// Clear accumulated stem hints and all data derived from them.
  fn clear_hints(Self) -> Unit
  /// Called when charstring evaluation is complete.
  fn finish(Self) -> Unit
}

///|
/// Evaluates the given charstring and emits the resulting commands to the
/// specified sink.
///
/// Returns the advance width if the charstring provides one.
pub fn evaluate(
  context : &CharstringContext,
  charstring_data : BytesView,
  sink : &CommandSink,
  blend_state? : BlendState? = None,
) -> Fixed? raise PsError {
  let evaluator = Evaluator::new(context, blend_state, sink)
  evaluator.evaluate(charstring_data)
  let width = if evaluator.have_read_width { Some(evaluator.wx) } else { None }
  sink.finish()
  width
}

///|
/// Specifies how the seac operation was invoked.
priv enum SeacMode {
  /// Through the `seac` operator.
  Explicit
  /// Implicitly with extra arguments on the stack through the
  /// `endchar` operator.
  Implicit
} derive(Eq)

///|
/// Transient state for evaluating a charstring and handling recursive
/// subroutine calls.
priv struct Evaluator {
  context : &CharstringContext
  is_type1 : Bool
  blend_state : BlendState?
  sink : &CommandSink
  mut is_open : Bool
  /// When the flex state is active, moveto commands simply
  /// accumulate vectors on the stack which will be used
  /// to emit curves when the flex is finalized
  mut is_flexing : Bool
  /// True if we've seen a command that might read width
  mut seen_width_command : Bool
  /// True if we've actually read a width
  mut have_read_width : Bool
  mut stem_count : Int
  mut x : Fixed
  mut y : Fixed
  /// X side-bearing
  mut sbx : Fixed
  /// X width
  mut wx : Fixed
  stack : Stack
  mut stack_ix : Int
  mut in_seac : Bool
}

///|
fn Evaluator::new(
  context : &CharstringContext,
  blend_state : BlendState?,
  sink : &CommandSink,
) -> Evaluator {
  let is_type1 = context.kind() == Type1
  {
    context,
    is_type1,
    blend_state,
    sink,
    is_open: false,
    is_flexing: false,
    seen_width_command: false,
    have_read_width: false,
    stem_count: 0,
    stack: Stack::new(),
    x: Fixed::zero(),
    y: Fixed::zero(),
    sbx: Fixed::zero(),
    wx: Fixed::zero(),
    stack_ix: 0,
    in_seac: false,
  }
}

///|
fn Evaluator::evaluate(
  self : Evaluator,
  charstring_data : BytesView,
) -> Unit raise PsError {
  let seen_endchar = self.evaluate_impl(charstring_data, 0)
  if !self.is_type1 && !seen_endchar {
    // FreeType simulates an endchar operator for CFF and CFF2
    ignore(self.evaluate_operator(EndChar, Cursor::new(b""[:]), 0))
  }
  if self.is_open {
    self.sink.close()
  }
}

///|
fn Evaluator::evaluate_impl(
  self : Evaluator,
  charstring_data : BytesView,
  nesting_depth : Int,
) -> Bool raise PsError {
  if nesting_depth > NESTING_DEPTH_LIMIT {
    raise CharstringNestingDepthLimitExceeded
  }
  let cursor = Cursor::new(charstring_data)
  let mut seen_endchar = false
  while cursor.remaining_bytes() != 0 {
    let b0 = cursor.read_u8()
    match b0 {
      // Push an integer to the stack
      28 | 32..=254 => self.stack.push_i32(parse_int(cursor, b0))
      // Push a fixed point value to the stack
      255 => {
        let val = cursor.read_i32()
        if self.is_type1 {
          // Type1 interprets this as an integer
          self.stack.push_i32(val)
        } else {
          // Type2 interprets this as a raw 16.16 fixed point value
          self.stack.push_fixed(Fixed::from_bits(val))
        }
      }
      _ => {
        // FreeType ignores reserved (unknown) operators.
        let operator = CsOperator::read(cursor, b0) catch {
          _ => {
            // Clear the stack for unknown operators
            self.reset_stack()
            continue
          }
        }
        if operator == EndChar {
          seen_endchar = true
        }
        if !self.evaluate_operator(operator, cursor, nesting_depth) {
          break
        }
      }
    }
  }
  seen_endchar
}

///|
/// Evaluates a single charstring operator.
///
/// Returns `true` if evaluation should continue.
fn Evaluator::evaluate_operator(
  self : Evaluator,
  operator : CsOperator,
  cursor : Cursor,
  nesting_depth : Int,
) -> Bool raise PsError {
  match operator {
    // The following "flex" operators are intended to emit
    // either two curves or a straight line depending on
    // a "flex depth" parameter and the distance from the
    // joining point to the chord connecting the two
    // end points. In practice, we just emit the two curves,
    // following FreeType.
    Flex => {
      self.emit_curves([DxDy, DxDy, DxDy, DxDy, DxDy, DxDy])
      self.reset_stack()
    }
    HFlex => {
      self.emit_curves([DxY, DxDy, DxY, DxY, DxInitialY, DxY])
      self.reset_stack()
    }
    HFlex1 => {
      self.emit_curves([DxDy, DxDy, DxY, DxY, DxDy, DxInitialY])
      self.reset_stack()
    }
    Flex1 => {
      self.emit_curves([DxDy, DxDy, DxDy, DxDy, DxDy, DLargerCoordDist])
      self.reset_stack()
    }
    // Set the variation store index
    VariationStoreIndex =>
      if !self.is_type1 {
        guard self.blend_state is Some(blend_state) else {
          raise MissingBlendState
        }
        let store_index = self.stack.pop_i32() & 0xFFFF
        blend_state.set_store_index(store_index)
      }
    // Apply blending to the current operand stack
    Blend =>
      if !self.is_type1 {
        guard self.blend_state is Some(blend_state) else {
          raise MissingBlendState
        }
        self.stack.apply_blend(blend_state)
      }
    // Return from the current subroutine
    Return => return false
    // End the current charstring
    EndChar => {
      let stack_len = self.stack.len()
      if (stack_len == 1 || stack_len == 5) && !self.seen_width_command {
        self.read_width()
      }
      self.seen_width_command = true
      if stack_len > 1 {
        self.handle_seac(Implicit, nesting_depth)
      }
      return false
    }
    // Emits a sequence of stem hints
    HStem | VStem | HStemHm | VStemHm => {
      let mut i = 0
      let len = if self.stack.len_is_odd() && !self.seen_width_command {
        self.read_width()
        i = 1
        self.stack.len() - 1
      } else {
        self.stack.len()
      }
      self.seen_width_command = true
      let is_horizontal = operator is (HStem | HStemHm)
      let mut u = Fixed::zero()
      while i < self.stack.len() {
        let args = self.stack.fixed_array(i, 2)
        u = u + args[0]
        let w = args[1]
        let v = u.wrapping_add(w)
        if is_horizontal {
          self.sink.hstem(u, v)
        } else {
          self.sink.vstem(u, v)
        }
        u = v
        i += 2
      }
      self.stem_count += len / 2
      self.reset_stack()
    }
    // Applies a hint or counter mask.
    // If there are arguments on the stack, this is also an
    // implied series of VSTEMHM operators.
    HintMask | CntrMask => {
      let mut i = 0
      let len = if self.stack.len_is_odd() && !self.seen_width_command {
        self.read_width()
        i = 1
        self.stack.len() - 1
      } else {
        self.stack.len()
      }
      self.seen_width_command = true
      let mut u = Fixed::zero()
      while i < self.stack.len() {
        let args = self.stack.fixed_array(i, 2)
        u = u + args[0]
        let w = args[1]
        let v = u + w
        self.sink.vstem(u, v)
        u = v
        i += 2
      }
      self.stem_count += len / 2
      let count = (self.stem_count + 7) / 8
      let mask = cursor.read_array(count, 1)
      if operator == HintMask {
        self.sink.hint_mask(mask)
      } else {
        self.sink.counter_mask(mask)
      }
      self.reset_stack()
    }
    // Starts a new subpath
    RMoveTo => {
      if self.stack.len() > 2 && !self.seen_width_command {
        self.read_width()
      }
      self.seen_width_command = true
      if !self.is_flexing {
        let dy = self.stack.pop_fixed()
        let dx = self.stack.pop_fixed()
        self.x = self.x + dx
        self.y = self.y + dy
        if !self.is_open {
          self.is_open = true
        } else {
          self.sink.close()
        }
        self.sink.move_to(self.x, self.y)
        self.reset_stack()
      }
    }
    // Starts a new subpath by moving the current point in the
    // horizontal or vertical direction
    HMoveTo | VMoveTo => {
      if self.stack.len() > 1 && !self.seen_width_command {
        self.read_width()
      }
      self.seen_width_command = true
      if self.is_flexing {
        // We need to add the other coordinate to the stack so we
        // have a full flex vector
        self.stack.push_i32(0)
        if operator == VMoveTo {
          // For vertical move, the coordinates are in the wrong
          // order so swap them
          self.stack.exch()
        }
      } else {
        let delta = self.stack.pop_fixed()
        if operator == HMoveTo {
          self.x = self.x + delta
        } else {
          self.y = self.y + delta
        }
        if !self.is_open {
          self.is_open = true
        } else {
          self.sink.close()
        }
        self.sink.move_to(self.x, self.y)
        self.reset_stack()
      }
    }
    // Emits a sequence of lines
    RLineTo => {
      let mut i = 0
      while i < self.stack.len() {
        let a = self.stack.fixed_array(i, 2)
        self.x = self.x + a[0]
        self.y = self.y + a[1]
        self.emit_line(self.x, self.y)
        i += 2
      }
      self.reset_stack()
    }
    // Emits a sequence of alternating horizontal and vertical lines
    HLineTo | VLineTo => {
      let mut is_x = operator == HLineTo
      for i in 0..<self.stack.len() {
        let delta = self.stack.get_fixed(i)
        if is_x {
          self.x = self.x + delta
        } else {
          self.y = self.y + delta
        }
        is_x = !is_x
        self.emit_line(self.x, self.y)
      }
      self.reset_stack()
    }
    // Emits curves that start and end horizontal, unless
    // the stack count is odd, in which case the first
    // curve may start with a vertical tangent
    HhCurveTo => {
      let count1 = self.stack.len()
      let count = count1 & -3
      self.stack_ix = count1 - count
      while self.stack_ix < count {
        if ((count - self.stack_ix) & 1) != 0 {
          self.y = self.y + self.stack.get_fixed(self.stack_ix)
          self.stack_ix += 1
        }
        self.emit_curves([DxY, DxDy, DxY])
      }
      self.reset_stack()
    }
    // Alternates between curves with horizontal and vertical tangents
    HvCurveTo | VhCurveTo => {
      let count1 = self.stack.len()
      let count = count1 & -3
      let mut is_horizontal = operator == HvCurveTo
      self.stack_ix = count1 - count
      while self.stack_ix < count {
        let do_last_delta = count - self.stack_ix == 5
        if is_horizontal {
          self.emit_curves([DxY, DxDy, MaybeDxDy(do_last_delta)])
        } else {
          self.emit_curves([XDy, DxDy, DxMaybeDy(do_last_delta)])
        }
        is_horizontal = !is_horizontal
      }
      self.reset_stack()
    }
    // Emits a sequence of curves possibly followed by a line
    RrCurveTo | RCurveLine => {
      while self.coords_remaining() >= 6 {
        self.emit_curves([DxDy, DxDy, DxDy])
      }
      if operator == RCurveLine {
        let a = self.stack.fixed_array(self.stack_ix, 2)
        self.x = self.x + a[0]
        self.y = self.y + a[1]
        self.emit_line(self.x, self.y)
      }
      self.reset_stack()
    }
    // Emits a sequence of lines followed by a curve
    RLineCurve => {
      while self.coords_remaining() > 6 {
        let a = self.stack.fixed_array(self.stack_ix, 2)
        self.x = self.x + a[0]
        self.y = self.y + a[1]
        self.emit_line(self.x, self.y)
        self.stack_ix += 2
      }
      while self.coords_remaining() >= 6 {
        self.emit_curves([DxDy, DxDy, DxDy])
      }
      self.reset_stack()
    }
    // Emits curves that start and end vertical, unless
    // the stack count is odd, in which case the first
    // curve may start with a horizontal tangent
    VvCurveTo => {
      let count1 = self.stack.len()
      let count = count1 & -3
      self.stack_ix = count1 - count
      while self.stack_ix < count {
        if ((count - self.stack_ix) & 1) != 0 {
          self.x = self.x + self.stack.get_fixed(self.stack_ix)
          self.stack_ix += 1
        }
        self.emit_curves([XDy, DxDy, XDy])
      }
      self.reset_stack()
    }
    // Call local or global subroutine
    CallSubr | CallGsubr => {
      let index = self.stack.pop_i32()
      let subr_charstring = if operator == CallSubr {
        self.context.subr(index)
      } else {
        self.context.global_subr(index)
      }
      ignore(self.evaluate_impl(subr_charstring, nesting_depth + 1))
    }
    // Sets the left sidebearing point to (sbx, 0) and the character
    // width vector to (wx, 0) in character space. Also sets current
    // point to (sbx, 0).
    Hsbw =>
      if self.is_type1 {
        let a = self.stack.fixed_array(0, 2)
        let sbx = a[0]
        let wx = a[1]
        self.sbx = self.sbx + sbx
        self.x = self.x + sbx
        self.wx = wx
        self.seen_width_command = true
        self.have_read_width = true
        self.reset_stack()
      }
    // Standard Encoding Accented Character.
    Seac => self.handle_seac(Explicit, nesting_depth)
    // Sets the left sidebearing point to (sbx, sby) and the character
    // width vector to (wx, wy) in character space. Also sets current
    // point to (sbx, sby).
    Sbw =>
      if self.is_type1 {
        let a = self.stack.fixed_array(0, 4)
        self.x = self.x + a[0]
        self.y = self.y + a[1]
        self.sbx = self.sbx + a[0]
        self.wx = a[2]
        self.seen_width_command = true
        self.have_read_width = true
        self.reset_stack()
      }
    // Brackets an outline section for dots in letters such as 'i',
    // 'j' and '!'. Purely metadata that a hinter can use.
    DotSection => ()
    // Declares ranges for three horizontal or vertical stem zones.
    HStem3 | VStem3 =>
      // Currently unimplemented.
      self.reset_stack()
    // Division operator.
    Div => self.stack.div(self.is_type1)
    // Mechanism for making calls into the PostScript interpreter.
    CallOtherSubr => {
      let subr_idx = self.stack.pop_i32()
      let num_args = self.stack.pop_i32()
      let weight_vector = self.context.weight_vector()
      match (subr_idx, num_args) {
        // End flex. Emit curves from accumulated vectors on the stack.
        (0, 3) => {
          self.is_flexing = false
          self.ensure_open()
          self.handle_flex()
        }
        // Begin flex. Accumulate vectors from moveto operators.
        (1, 0) => self.is_flexing = true
        // Counter control hints.
        (12 | 13, _) => self.reset_stack()
        // Handle blends for multiple masters.
        (14..=18, _) if weight_vector.length() > 1 =>
          self.handle_mm_blend(subr_idx, num_args)
        _ =>
          // Unknown othersubr, so simply drop the arguments
          // from the stack and hopefully we can keep going
          self.stack.drop(num_args)
      }
    }
    // Removes a number from the PostScript interpreter stack and
    // pushes that number to the BuildChar stack. Only used to
    // retrieve results from OtherSubrs procedures and those are
    // handled explicitly so this is a nop.
    Pop => ()
    // Sets the current point without performing a move command.
    SetCurrentPoint =>
      if self.is_type1 {
        let a = self.stack.fixed_array(0, 2)
        self.x = a[0]
        self.y = a[1]
        self.reset_stack()
      }
  }
  true
}

///|
fn Evaluator::read_width(self : Evaluator) -> Unit {
  self.wx = self.stack.get_fixed(0)
  self.seen_width_command = true
  self.have_read_width = true
}

///|
priv struct SeacComponent {
  charstring : BytesView
  x : Fixed
  y : Fixed
  /// True if we want to use metrics from this component
  /// if the original charstring does not provide any
  maybe_use_metrics : Bool
}

///|
fn Evaluator::handle_seac(
  self : Evaluator,
  mode : SeacMode,
  nesting_depth : Int,
) -> Unit raise PsError {
  // handle seac operator
  if self.in_seac {
    raise CharstringNestingDepthLimitExceeded
  }
  self.in_seac = true
  let accent_code = self.stack.pop_i32()
  let base_code = self.stack.pop_i32()
  let (base_charstring, accent_charstring) = self.context.seac_components(
    base_code, accent_code,
  )
  let dy = self.stack.pop_fixed()
  let dx = self.stack.pop_fixed()
  let sb = if self.is_type1 {
    // Type1 has an additional side bearing argument
    self.stack.pop_fixed()
  } else if !self.stack.is_empty() && !self.seen_width_command {
    self.wx = self.stack.pop_fixed()
    self.seen_width_command = true
    Fixed::zero()
  } else {
    Fixed::zero()
  }
  // Save metrics to potentially restore later.
  let mut sbx = self.sbx
  let mut wx = self.wx
  let seen_width = self.seen_width_command
  let read_width = self.have_read_width
  let x = self.x
  let y = self.y
  // Base components for explicit seac are always 0 in FreeType
  let (bx, by) = if mode == Explicit {
    (Fixed::zero(), Fixed::zero())
  } else {
    (x, y)
  }
  let base : SeacComponent = {
    charstring: base_charstring,
    x: bx,
    y: by,
    // In explicit seac mode, use the metrics of the base component
    // if the original charstring didn't provide any
    maybe_use_metrics: mode == Explicit,
  }
  let accent : SeacComponent = {
    charstring: accent_charstring,
    // Adjustments only for type1 but these will be 0 for type2 anyway
    x: dx + self.sbx - sb,
    y: dy,
    maybe_use_metrics: false,
  }
  // FreeType evaluates accent first for implicit seac but base first
  // for explicit so swap if necessary.
  let components = if mode == Implicit {
    [accent, base]
  } else {
    [base, accent]
  }
  // FreeType calls cf2_interpT2CharString for each component
  // which uses a fresh set of stem hints. We signal this through the sink.
  // Also reset our own stem count so we read the correct number of
  // bytes for each hint mask instruction.
  for component in components {
    self.reset_stack()
    self.seen_width_command = false
    self.sink.clear_hints()
    self.stem_count = 0
    self.x = component.x
    self.y = component.y
    ignore(self.evaluate_impl(component.charstring, nesting_depth + 1))
    if component.maybe_use_metrics && !seen_width {
      sbx = self.sbx
      wx = self.wx
    }
  }
  self.seen_width_command = seen_width
  self.have_read_width = read_width
  self.sbx = sbx
  self.wx = wx
  self.in_seac = false
}

///|
/// Emit two curves for the accumulated flex vectors.
fn Evaluator::handle_flex(self : Evaluator) -> Unit raise PsError {
  // FreeType does weird accounting for flex vectors
  // that we don't wish to copy so do the equivalent
  // thing from fonttools instead.
  let final_y = self.stack.pop_fixed()
  let final_x = self.stack.pop_fixed()
  // Flex height is unused
  ignore(self.stack.pop_fixed())
  let p3y = self.stack.pop_fixed()
  let p3x = self.stack.pop_fixed()
  let bcp4y = self.stack.pop_fixed()
  let bcp4x = self.stack.pop_fixed()
  let bcp3y = self.stack.pop_fixed()
  let bcp3x = self.stack.pop_fixed()
  let p2y = self.stack.pop_fixed()
  let p2x = self.stack.pop_fixed()
  let bcp2y = self.stack.pop_fixed()
  let bcp2x = self.stack.pop_fixed()
  let bcp1y = self.stack.pop_fixed()
  let bcp1x = self.stack.pop_fixed()
  let rpy = self.stack.pop_fixed()
  let rpx = self.stack.pop_fixed()
  self.reset_stack()
  self.stack.push_fixed(bcp1x + rpx)
  self.stack.push_fixed(bcp1y + rpy)
  self.stack.push_fixed(bcp2x)
  self.stack.push_fixed(bcp2y)
  self.stack.push_fixed(p2x)
  self.stack.push_fixed(p2y)
  self.emit_curves([DxDy, DxDy, DxDy])
  self.reset_stack()
  self.stack.push_fixed(bcp3x)
  self.stack.push_fixed(bcp3y)
  self.stack.push_fixed(bcp4x)
  self.stack.push_fixed(bcp4y)
  self.stack.push_fixed(p3x)
  self.stack.push_fixed(p3y)
  self.emit_curves([DxDy, DxDy, DxDy])
  self.reset_stack()
  // Push final position back on the stack
  self.stack.push_fixed(final_x)
  self.stack.push_fixed(final_y)
}

///|
/// Handle point blending for multiple master fonts.
fn Evaluator::handle_mm_blend(
  self : Evaluator,
  subr_idx : Int,
  num_args : Int,
) -> Unit raise PsError {
  let weight_vector = self.context.weight_vector()
  let num_points = subr_idx - 13 + (if subr_idx == 18 { 1 } else { 0 })
  if num_args.to_int64() !=
    num_points.to_int64() * weight_vector.length().to_int64() {
    raise Read(
      @read_fonts.ReadError::MalformedData(
        "incorrect number of multiple masters arguments",
      ),
    )
  }
  // The stack is setup to contain `num_points` values followed
  // by `num_points * (num_weights - 1)` deltas for each point.
  //
  // The blend algorithm is p[0] + d[0]*w[1] + d[1]*w[2]...
  // where p = points, d = deltas and w = weights
  //
  // The first weight is always ignored per FT.
  if self.stack.len() < num_args {
    raise StackUnderflow
  }
  let stack_base = self.stack.len() - num_args
  let mut delta_idx = stack_base + num_points
  for i in 0..<num_points {
    let mut val = self.stack.get_fixed(stack_base + i)
    for w in 1..<weight_vector.length() {
      val = val + self.stack.get_fixed(delta_idx) * weight_vector[w]
      delta_idx += 1
    }
    self.stack.set_fixed(stack_base + i, val)
  }
  self.stack.drop(if num_args > num_points { num_args - num_points } else { 0 })
}

///|
fn Evaluator::coords_remaining(self : Evaluator) -> Int {
  // This is overly defensive to avoid overflow but in the case of
  // broken fonts, just return 0 when stack_ix > stack_len to prevent
  // potential runaway while loops in the evaluator if this wraps
  let r = self.stack.len() - self.stack_ix
  if r < 0 {
    0
  } else {
    r
  }
}

///|
fn Evaluator::ensure_open(self : Evaluator) -> Unit {
  if !self.is_open {
    self.sink.move_to(Fixed::zero(), Fixed::zero())
    self.is_open = true
  }
}

///|
fn Evaluator::emit_line(self : Evaluator, x : Fixed, y : Fixed) -> Unit {
  self.ensure_open()
  self.sink.line_to(x, y)
}

///|
fn Evaluator::emit_curves(self : Evaluator, modes : Array[PointMode]) -> Unit {
  let initial_x = self.x
  let initial_y = self.y
  let mut count = 0
  let px = [Fixed::zero(), Fixed::zero()]
  let py = [Fixed::zero(), Fixed::zero()]
  self.ensure_open()
  for mode in modes {
    let stack_used = match mode {
      DxDy => {
        self.x = self.x + self.stack.get_fixed(self.stack_ix)
        self.y = self.y + self.stack.get_fixed(self.stack_ix + 1)
        2
      }
      XDy => {
        self.y = self.y + self.stack.get_fixed(self.stack_ix)
        1
      }
      DxY => {
        self.x = self.x + self.stack.get_fixed(self.stack_ix)
        1
      }
      DxInitialY => {
        self.x = self.x + self.stack.get_fixed(self.stack_ix)
        self.y = initial_y
        1
      }
      // Emits a delta for the coordinate with the larger distance
      // from the original value. Sets the other coordinate to the
      // original value.
      DLargerCoordDist => {
        let delta = self.stack.get_fixed(self.stack_ix)
        if (self.x - initial_x).abs() > (self.y - initial_y).abs() {
          self.x = self.x + delta
          self.y = initial_y
        } else {
          self.y = self.y + delta
          self.x = initial_x
        }
        1
      }
      // Apply delta to y if `do_dy` is true.
      DxMaybeDy(do_dy) => {
        self.x = self.x + self.stack.get_fixed(self.stack_ix)
        if do_dy {
          self.y = self.y + self.stack.get_fixed(self.stack_ix + 1)
          2
        } else {
          1
        }
      }
      // Apply delta to x if `do_dx` is true.
      MaybeDxDy(do_dx) => {
        self.y = self.y + self.stack.get_fixed(self.stack_ix)
        if do_dx {
          self.x = self.x + self.stack.get_fixed(self.stack_ix + 1)
          2
        } else {
          1
        }
      }
    }
    self.stack_ix += stack_used
    if count == 2 {
      self.sink.curve_to(px[0], py[0], px[1], py[1], self.x, self.y)
      count = 0
    } else {
      px[count] = self.x
      py[count] = self.y
      count += 1
    }
  }
}

///|
fn Evaluator::reset_stack(self : Evaluator) -> Unit {
  self.stack.clear()
  self.stack_ix = 0
}

///|
/// Specifies how point coordinates for a curve are computed.
priv enum PointMode {
  DxDy
  XDy
  DxY
  DxInitialY
  DLargerCoordDist
  DxMaybeDy(Bool)
  MaybeDxDy(Bool)
}

///|
/// PostScript charstring operator.
priv enum CsOperator {
  HStem
  VStem
  VMoveTo
  RLineTo
  HLineTo
  VLineTo
  RrCurveTo
  CallSubr
  Return
  Hsbw
  EndChar
  VariationStoreIndex
  Blend
  HStemHm
  HintMask
  CntrMask
  RMoveTo
  HMoveTo
  VStemHm
  RCurveLine
  RLineCurve
  VvCurveTo
  HhCurveTo
  CallGsubr
  VhCurveTo
  HvCurveTo
  DotSection
  VStem3
  HStem3
  Seac
  Sbw
  Div
  CallOtherSubr
  Pop
  SetCurrentPoint
  HFlex
  Flex
  HFlex1
  Flex1
} derive(Eq)

///|
fn CsOperator::read(cursor : Cursor, b0 : Int) -> CsOperator raise PsError {
  // Escape opcode for accessing two byte operators
  let (opcode, operator) = if b0 == 12 {
    let b1 = cursor.read_u8()
    (b1, CsOperator::from_two_byte_opcode(b1))
  } else {
    (b0, CsOperator::from_opcode(b0))
  }
  match operator {
    Some(op) => op
    None => raise InvalidCharstringOperator(opcode)
  }
}

///|
/// Creates an operator from the given opcode.
fn CsOperator::from_opcode(opcode : Int) -> CsOperator? {
  Some(
    match opcode {
      1 => HStem
      3 => VStem
      4 => VMoveTo
      5 => RLineTo
      6 => HLineTo
      7 => VLineTo
      8 => RrCurveTo
      10 => CallSubr
      11 => Return
      13 => Hsbw
      14 => EndChar
      15 => VariationStoreIndex
      16 => Blend
      18 => HStemHm
      19 => HintMask
      20 => CntrMask
      21 => RMoveTo
      22 => HMoveTo
      23 => VStemHm
      24 => RCurveLine
      25 => RLineCurve
      26 => VvCurveTo
      27 => HhCurveTo
      29 => CallGsubr
      30 => VhCurveTo
      31 => HvCurveTo
      _ => return None
    },
  )
}

///|
/// Creates an operator from the given extended opcode.
///
/// These are preceded by a byte containing the escape value of 12.
fn CsOperator::from_two_byte_opcode(opcode : Int) -> CsOperator? {
  Some(
    match opcode {
      0 => DotSection
      1 => VStem3
      2 => HStem3
      6 => Seac
      7 => Sbw
      12 => Div
      16 => CallOtherSubr
      17 => Pop
      33 => SetCurrentPoint
      34 => HFlex
      35 => Flex
      36 => HFlex1
      37 => Flex1
      _ => return None
    },
  )
}

// ---------------------------------------------------------------------------
// Sinks

///|
// Used for scaling sink below
let one_over_64 : Fixed = Fixed::from_bits(0x400)

///|
/// Command sink adapter that applies a matrix and optional scale.
pub struct TransformSink {
  inner : &CommandSink
  matrix : FontMatrix?
  scale : Fixed?
}

///|
/// Creates a new sink for the given transform.
pub fn TransformSink::new(
  sink : &CommandSink,
  transform : Transform,
) -> TransformSink {
  TransformSink::from_matrix_scale(sink, transform.matrix, transform.scale)
}

///|
/// Creates a new sink for the given matrix and optional scale.
pub fn TransformSink::from_matrix_scale(
  sink : &CommandSink,
  matrix : FontMatrix,
  scale : Fixed?,
) -> TransformSink {
  {
    inner: sink,
    matrix: if matrix != FontMatrix::identity() {
      Some(matrix)
    } else {
      None
    },
    scale,
  }
}

///|
fn TransformSink::transform(
  self : TransformSink,
  x : Fixed,
  y : Fixed,
) -> (Fixed, Fixed) {
  // The following dance is necessary to exactly match FreeType's
  // application of scaling factors.
  //
  // 1. Multiply by 1/64
  let ax = x * one_over_64
  let ay = y * one_over_64
  // 2. Truncate the bottom 10 bits. Combined with the division by 64,
  // converts to font units.
  let bx = Fixed::from_bits(ax.to_bits() >> 10)
  let by = Fixed::from_bits(ay.to_bits() >> 10)
  // 3. Apply the transform. It must be done here to match FreeType.
  let (cx, cy) = match self.matrix {
    Some(mat) => mat.transform(bx, by)
    None => (bx, by)
  }
  match self.scale {
    Some(scale) => {
      // Scaled case:
      // 4. Multiply by the original scale factor (to 26.6)
      let dx = cx * scale
      let dy = cy * scale
      // 5. Convert from 26.6 to 16.16
      (
        Fixed::from_bits(dx.to_bits() << 10),
        Fixed::from_bits(dy.to_bits() << 10),
      )
    }
    None =>
      // Unscaled case:
      // 4. Convert from integer to 16.16
      (
        Fixed::from_bits(cx.to_bits() << 16),
        Fixed::from_bits(cy.to_bits() << 16),
      )
  }
}

///|
pub impl CommandSink for TransformSink with fn hstem(self, y, dy) {
  self.inner.hstem(y, dy)
}

///|
pub impl CommandSink for TransformSink with fn vstem(self, x, dx) {
  self.inner.vstem(x, dx)
}

///|
pub impl CommandSink for TransformSink with fn hint_mask(self, mask) {
  self.inner.hint_mask(mask)
}

///|
pub impl CommandSink for TransformSink with fn counter_mask(self, mask) {
  self.inner.counter_mask(mask)
}

///|
pub impl CommandSink for TransformSink with fn clear_hints(self) {
  self.inner.clear_hints()
}

///|
pub impl CommandSink for TransformSink with fn move_to(self, x, y) {
  let (x, y) = self.transform(x, y)
  self.inner.move_to(x, y)
}

///|
pub impl CommandSink for TransformSink with fn line_to(self, x, y) {
  let (x, y) = self.transform(x, y)
  self.inner.line_to(x, y)
}

///|
pub impl CommandSink for TransformSink with fn curve_to(
  self,
  cx1,
  cy1,
  cx2,
  cy2,
  x,
  y,
) {
  let (cx1, cy1) = self.transform(cx1, cy1)
  let (cx2, cy2) = self.transform(cx2, cy2)
  let (x, y) = self.transform(x, y)
  self.inner.curve_to(cx1, cy1, cx2, cy2, x, y)
}

///|
pub impl CommandSink for TransformSink with fn close(self) {
  self.inner.close()
}

///|
pub impl CommandSink for TransformSink with fn finish(self) {
  self.inner.finish()
}

///|
priv enum PendingElement {
  Move(Fixed, Fixed)
  Line(Fixed, Fixed)
  Curve(Fixed, Fixed, Fixed, Fixed, Fixed, Fixed)
}

///|
fn PendingElement::target_point(self : PendingElement) -> (Fixed, Fixed) {
  match self {
    Move(x, y) | Line(x, y) => (x, y)
    Curve(_, _, _, _, x, y) => (x, y)
  }
}

///|
/// Command sink adapter that suppresses degenerate move and line commands.
///
/// FreeType avoids emitting empty contours and zero length lines to prevent
/// artifacts when stem darkening is enabled. We remove the degenerate
/// elements regardless to match the output.
pub struct NopFilterSink {
  mut is_open : Bool
  mut start : (Fixed, Fixed)?
  priv mut pending_element : PendingElement?
  inner : &CommandSink
}

///|
/// Creates a new sink that suppresses degenerate move and line commands
/// before forwarding the result to the given inner sink.
pub fn NopFilterSink::new(inner : &CommandSink) -> NopFilterSink {
  { is_open: false, start: None, pending_element: None, inner, }
}

///|
fn NopFilterSink::flush_pending(self : NopFilterSink, for_close : Bool) -> Unit {
  if self.pending_element is Some(pending) {
    self.pending_element = None
    match pending {
      Move(x, y) =>
        if !for_close {
          self.is_open = true
          self.inner.move_to(x, y)
          self.start = Some((x, y))
        }
      Line(x, y) => {
        let same = match self.start {
          Some((sx, sy)) => sx == x && sy == y
          None => false
        }
        if !for_close || !same {
          self.inner.line_to(x, y)
        }
      }
      Curve(cx0, cy0, cx1, cy1, x, y) =>
        self.inner.curve_to(cx0, cy0, cx1, cy1, x, y)
    }
  }
}

///|
pub impl CommandSink for NopFilterSink with fn hstem(self, y, dy) {
  self.inner.hstem(y, dy)
}

///|
pub impl CommandSink for NopFilterSink with fn vstem(self, x, dx) {
  self.inner.vstem(x, dx)
}

///|
pub impl CommandSink for NopFilterSink with fn hint_mask(self, mask) {
  self.inner.hint_mask(mask)
}

///|
pub impl CommandSink for NopFilterSink with fn counter_mask(self, mask) {
  self.inner.counter_mask(mask)
}

///|
pub impl CommandSink for NopFilterSink with fn clear_hints(self) {
  self.inner.clear_hints()
}

///|
pub impl CommandSink for NopFilterSink with fn move_to(self, x, y) {
  self.pending_element = Some(Move(x, y))
}

///|
pub impl CommandSink for NopFilterSink with fn line_to(self, x, y) {
  // Omit the line if we're already at the given position
  if self.pending_element is Some(element) {
    let (px, py) = element.target_point()
    if px == x && py == y {
      return
    }
  }
  self.flush_pending(false)
  self.pending_element = Some(Line(x, y))
}

///|
pub impl CommandSink for NopFilterSink with fn curve_to(
  self,
  cx1,
  cy1,
  cx2,
  cy2,
  x,
  y,
) {
  self.flush_pending(false)
  self.pending_element = Some(Curve(cx1, cy1, cx2, cy2, x, y))
}

///|
pub impl CommandSink for NopFilterSink with fn close(self) {
  self.flush_pending(true)
  if self.is_open {
    self.inner.close()
    self.is_open = false
  }
}

///|
pub impl CommandSink for NopFilterSink with fn finish(self) {
  CommandSink::close(self)
  self.inner.finish()
}

///|
/// Adapter that forwards charstring commands to an [OutlinePen].
pub struct PenSink {
  pen : &@read_fonts.OutlinePen
}

///|
pub fn PenSink::new(pen : &@read_fonts.OutlinePen) -> PenSink {
  { pen, }
}

///|
pub impl CommandSink for PenSink with fn move_to(self, x, y) {
  self.pen.move_to(x.to_f32(), y.to_f32())
}

///|
pub impl CommandSink for PenSink with fn line_to(self, x, y) {
  self.pen.line_to(x.to_f32(), y.to_f32())
}

///|
pub impl CommandSink for PenSink with fn curve_to(
  self,
  cx0,
  cy0,
  cx1,
  cy1,
  x,
  y,
) {
  self.pen.curve_to(
    cx0.to_f32(),
    cy0.to_f32(),
    cx1.to_f32(),
    cy1.to_f32(),
    x.to_f32(),
    y.to_f32(),
  )
}

///|
pub impl CommandSink for PenSink with fn close(self) {
  self.pen.close()
}

///|
pub impl CommandSink for PenSink with fn hstem(_self, _y, _dy) {
  ()
}

///|
pub impl CommandSink for PenSink with fn vstem(_self, _x, _dx) {
  ()
}

///|
pub impl CommandSink for PenSink with fn hint_mask(_self, _mask) {
  ()
}

///|
pub impl CommandSink for PenSink with fn counter_mask(_self, _mask) {
  ()
}

///|
pub impl CommandSink for PenSink with fn clear_hints(_self) {
  ()
}

///|
pub impl CommandSink for PenSink with fn finish(_self) {
  ()
}
