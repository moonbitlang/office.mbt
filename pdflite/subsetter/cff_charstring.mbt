// Port of subsetter 0.2.6 `src/cff/charstring.rs` and
// `src/cff/subroutines.rs`: a charstring decompiler (adapted from
// fonttools) that inlines all subroutine calls.

///|
/// Wrapper over a list of subroutines to allow for convenient access to
/// subroutines given a biased index.
priv struct SubroutineHandler {
  subroutines : Array[BytesView]
  bias : Int
}

///|
fn SubroutineHandler::new(char_strings : Array[BytesView]) -> SubroutineHandler {
  {
    subroutines: char_strings,
    bias: calc_subroutine_bias(char_strings.length()),
  }
}

///|
fn SubroutineHandler::get_with_biased(
  self : SubroutineHandler,
  index : Int,
) -> BytesView? {
  // `unapply_bias`: `index.checked_add(bias)` and `u32::try_from`.
  let unbiased = index.to_int64() + self.bias.to_int64()
  if unbiased < 0L || unbiased > 0x7FFFFFFFL {
    return None
  }
  let unbiased = unbiased.to_int()
  if unbiased < self.subroutines.length() {
    Some(self.subroutines[unbiased])
  } else {
    None
  }
}

///|
fn calc_subroutine_bias(len : Int) -> Int {
  if len < 1240 {
    107
  } else if len < 33900 {
    1131
  } else {
    32768
  }
}

///|
let op_horizontal_stem : Operator = Operator::from_one_byte(1)

///|
let op_vertical_stem : Operator = Operator::from_one_byte(3)

///|
let op_vertical_move_to : Operator = Operator::from_one_byte(4)

///|
let op_line_to : Operator = Operator::from_one_byte(5)

///|
let op_horizontal_line_to : Operator = Operator::from_one_byte(6)

///|
let op_vertical_line_to : Operator = Operator::from_one_byte(7)

///|
let op_curve_to : Operator = Operator::from_one_byte(8)

///|
let op_call_local_subroutine : Operator = Operator::from_one_byte(10)

///|
let op_return : Operator = Operator::from_one_byte(11)

///|
let op_endchar : Operator = Operator::from_one_byte(14)

///|
let op_horizontal_stem_hint_mask : Operator = Operator::from_one_byte(18)

///|
let op_hint_mask : Operator = Operator::from_one_byte(19)

///|
let op_counter_mask : Operator = Operator::from_one_byte(20)

///|
let op_move_to : Operator = Operator::from_one_byte(21)

///|
let op_horizontal_move_to : Operator = Operator::from_one_byte(22)

///|
let op_vertical_stem_hint_mask : Operator = Operator::from_one_byte(23)

///|
let op_curve_line : Operator = Operator::from_one_byte(24)

///|
let op_line_curve : Operator = Operator::from_one_byte(25)

///|
let op_vv_curve_to : Operator = Operator::from_one_byte(26)

///|
let op_hh_curve_to : Operator = Operator::from_one_byte(27)

///|
let op_call_global_subroutine : Operator = Operator::from_one_byte(29)

///|
let op_vh_curve_to : Operator = Operator::from_one_byte(30)

///|
let op_hv_curve_to : Operator = Operator::from_one_byte(31)

///|
let op_hflex : Operator = Operator::from_two_byte(34)

///|
let op_flex : Operator = Operator::from_two_byte(35)

///|
let op_hflex1 : Operator = Operator::from_two_byte(36)

///|
let op_flex1 : Operator = Operator::from_two_byte(37)

///|
/// A type of instruction in a charstring program.
priv enum Instruction {
  Operand(Number)
  Op(Operator)
  HintMask(BytesView)
}

///|
/// A charstring decompiler.
priv struct Decompiler {
  gsubr_handler : SubroutineHandler
  lsubr_handler : SubroutineHandler
  stack : ArgumentsStack
  mut hint_count : Int
  mut hint_mask_bytes : Int
}

///|
fn Decompiler::new(
  gsubr_handler : SubroutineHandler,
  lsubr_handler : SubroutineHandler,
) -> Decompiler {
  {
    gsubr_handler,
    lsubr_handler,
    stack: ArgumentsStack::new(),
    hint_count: 0,
    hint_mask_bytes: 0,
  }
}

///|
/// Decompile a charstring with the given decompiler.
fn Decompiler::decompile(
  self : Decompiler,
  charstring : BytesView,
) -> Array[Instruction] raise SubsetError {
  let program = []
  self.decompile_inner(charstring, program, 1) |> ignore
  program
}

///|
/// Returns whether the charstring ended with `endchar` (else `return` or
/// the end of the data).
fn Decompiler::decompile_inner(
  self : Decompiler,
  charstring : BytesView,
  program : Array[Instruction],
  depth : Int,
) -> Bool raise SubsetError {
  if depth > 64 {
    raise CFFError
  }
  let r = Reader::new(charstring)
  while !r.at_end() {
    // We need to peak instead of read because parsing a number requires
    // access to the whole buffer.
    guard r.peak_u8() is Some(op) else { raise CFFError }

    // Numbers
    if op == 28 || op >= 32 {
      guard Number::parse_char_string_number(r) is Some(number) else {
        raise CFFError
      }
      self.stack.push(number)
      program.push(Operand(number))
      continue
    }

    // No numbers can appear now, so now we can actually read it.
    guard r.read_u8() is Some(op) else { raise CFFError }
    let operator = if op == 12 {
      guard r.read_u8() is Some(b) else { raise CFFError }
      Operator::from_two_byte(b)
    } else {
      Operator::from_one_byte(op)
    }
    if operator == op_hflex ||
      operator == op_flex ||
      operator == op_hflex1 ||
      operator == op_flex1 {
      self.stack.pop_all() |> ignore
      program.push(Op(operator))
    } else if operator == op_horizontal_stem ||
      operator == op_vertical_stem ||
      operator == op_horizontal_stem_hint_mask ||
      operator == op_vertical_stem_hint_mask {
      self.count_hints()
      program.push(Op(operator))
    } else if operator == op_vertical_move_to ||
      operator == op_horizontal_move_to ||
      operator == op_line_to ||
      operator == op_vertical_line_to ||
      operator == op_horizontal_line_to ||
      operator == op_move_to ||
      operator == op_curve_line ||
      operator == op_line_curve ||
      operator == op_vv_curve_to ||
      operator == op_vh_curve_to ||
      operator == op_hh_curve_to ||
      operator == op_hv_curve_to ||
      operator == op_curve_to {
      self.stack.pop_all() |> ignore
      program.push(Op(operator))
    } else if operator == op_return {
      return false
    } else if operator == op_call_global_subroutine ||
      operator == op_call_local_subroutine {
      // Pop the subroutine index from the program.
      program.pop() |> ignore
      guard self.stack.pop() is Some(n) && n.as_i32() is Some(biased_index) else {
        raise CFFError
      }
      let handler = if operator == op_call_global_subroutine {
        self.gsubr_handler
      } else {
        self.lsubr_handler
      }
      guard handler.get_with_biased(biased_index) is Some(subr) else {
        raise CFFError
      }
      if self.decompile_inner(subr, program, depth + 1) {
        return true
      }
    } else if operator == op_hint_mask || operator == op_counter_mask {
      program.push(Op(operator))
      if self.hint_mask_bytes == 0 {
        // Hintmask can contain implicit stems.
        self.count_hints()
        self.hint_mask_bytes = (self.hint_count + 7) / 8
      }
      guard r.read_bytes(self.hint_mask_bytes) is Some(hint_bytes) else {
        raise CFFError
      }
      program.push(HintMask(hint_bytes))
    } else if operator == op_endchar {
      // We don't support seac for now. It's a deprecated feature and Typst
      // for some reason does not support it anyway.
      if self.stack.len() >= 4 {
        raise Unimplemented
      }
      program.push(Op(operator))
      return true
    } else {
      raise CFFError
    }
  }
  false
}

///|
fn Decompiler::count_hints(self : Decompiler) -> Unit {
  let elements = self.stack.pop_all()
  self.hint_count = (self.hint_count + elements / 2) & 0xFFFF
}

///|
/// Compile the program.
fn compile_program(program : Array[Instruction]) -> Bytes {
  let w = Writer::new()
  for instr in program {
    match instr {
      Operand(num) => num.write(w)
      Op(op) => op.write(w)
      HintMask(hm) => w.extend(hm)
    }
  }
  w.finish()
}
