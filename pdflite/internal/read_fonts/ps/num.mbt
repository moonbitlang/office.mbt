// Port of read-fonts 0.39.2 `src/ps/num.rs`.

///|
fn parse_int(cursor : Cursor, b0 : Int) -> Int raise PsError {
  // Size   b0 range     Value range              Value calculation
  //--------------------------------------------------------------------------------
  // 1      32 to 246    -107 to +107             b0 - 139
  // 2      247 to 250   +108 to +1131            (b0 - 247) * 256 + b1 + 108
  // 2      251 to 254   -1131 to -108            -(b0 - 251) * 256 - b1 - 108
  // 3      28           -32768 to +32767         b1 << 8 | b2
  // 5      29           -(2^31) to +(2^31 - 1)   b1 << 24 | b2 << 16 | b3 << 8 | b4
  match b0 {
    32..=246 => b0 - 139
    247..=250 => (b0 - 247) * 256 + cursor.read_u8() + 108
    251..=254 => -(b0 - 251) * 256 - cursor.read_u8() - 108
    28 => cursor.read_i16()
    29 => cursor.read_i32()
    _ => raise InvalidNumber
  }
}

// Various unnamed constants inlined in FreeType's cff_parse_real function

///|
let bcd_overflow : @font_types.Fixed = @font_types.Fixed::from_bits(0x7FFFFFFF)

///|
let bcd_underflow : @font_types.Fixed = @font_types.Fixed::zero()

///|
const BCD_NUMBER_LIMIT : Int = 0xCCCCCCC

///|
const BCD_INTEGER_LIMIT : Int = 0x7FFF

///|
let bcd_power_tens : FixedArray[Int] = [
  1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000,
]

///|
/// Components for computing a fixed point value for a binary coded decimal
/// number.
pub(all) struct BcdComponents {
  /// If overflow or underflow is detected early, then this contains the
  /// resulting value and we skip further processing.
  error : @font_types.Fixed?
  number : Int
  sign : Int
  exponent : Int
  exponent_add : Int
  integer_len : Int
  fraction_len : Int
} derive(Eq, Debug)

///|
fn BcdComponents::from_error(value : @font_types.Fixed) -> BcdComponents {
  {
    error: Some(value),
    number: 0,
    sign: 0,
    exponent: 0,
    exponent_add: 0,
    integer_len: 0,
    fraction_len: 0,
  }
}

///|
/// Parse a binary coded decimal number.
fn BcdComponents::parse(cursor : Cursor) -> BcdComponents raise PsError {
  // phase: 0 = integer, 1 = fraction, 2 = exponent
  let mut phase = 0
  let mut sign = 1
  let mut exponent_sign = 1
  let mut number = 0
  let mut exponent = 0
  let mut exponent_add = 0
  let mut integer_len = 0
  let mut fraction_len = 0
  // Nibble value    Represents
  //----------------------------------
  // 0 to 9          0 to 9
  // a               . (decimal point)
  // b               E
  // c               E-
  // d               <reserved>
  // e               - (minus)
  // f               end of number
  let mut done = false
  while !done {
    let b = cursor.read_u8()
    for nibble in [(b >> 4) & 0xF, b & 0xF] {
      match phase {
        0 =>
          match nibble {
            0x0..=0x9 =>
              if number >= BCD_NUMBER_LIMIT {
                exponent_add += 1
              } else if nibble != 0 || number != 0 {
                number = number * 10 + nibble
                integer_len += 1
              }
            0xE => sign = -1
            0xA => phase = 1
            0xB => phase = 2
            0xC => {
              phase = 2
              exponent_sign = -1
            }
            _ => {
              done = true
              break
            }
          }
        1 =>
          match nibble {
            0x0..=0x9 =>
              if nibble == 0 && number == 0 {
                exponent_add -= 1
              } else if number < BCD_NUMBER_LIMIT && fraction_len < 9 {
                number = number * 10 + nibble
                fraction_len += 1
              }
            0xB => phase = 2
            0xC => {
              phase = 2
              exponent_sign = -1
            }
            _ => {
              done = true
              break
            }
          }
        _ =>
          match nibble {
            0x0..=0x9 =>
              // Arbitrarily limit exponent
              if exponent > 1000 {
                return if exponent_sign == -1 {
                  BcdComponents::from_error(bcd_underflow)
                } else {
                  BcdComponents::from_error(bcd_overflow)
                }
              } else {
                exponent = exponent * 10 + nibble
              }
            _ => {
              done = true
              break
            }
          }
      }
    }
  }
  exponent *= exponent_sign
  {
    error: None,
    number,
    sign,
    exponent,
    exponent_add,
    integer_len,
    fraction_len,
  }
}

///|
/// Returns the fixed point value for the precomputed components,
/// optionally using an internal scale factor of 1000 to increase fractional
/// precision.
pub fn BcdComponents::value(
  self : BcdComponents,
  scale_by_1000 : Bool,
) -> @font_types.Fixed {
  if self.error is Some(error) {
    return error
  }
  let mut number = self.number
  if number == 0 {
    return @font_types.Fixed::zero()
  }
  let mut exponent = self.exponent
  let mut integer_len = self.integer_len
  let mut fraction_len = self.fraction_len
  if scale_by_1000 {
    exponent += 3 + self.exponent_add
  } else {
    exponent += self.exponent_add
  }
  integer_len += exponent
  fraction_len -= exponent
  if integer_len > 5 {
    return bcd_overflow
  }
  if integer_len < -5 {
    return bcd_underflow
  }
  // Remove non-significant digits
  if integer_len < 0 {
    number /= bcd_power_tens[-integer_len]
    fraction_len += integer_len
  }
  // Can only happen if exponent was non-zero
  if fraction_len == 10 {
    number /= 10
    fraction_len -= 1
  }
  // Convert to fixed
  let mut result = if fraction_len > 0 {
    let b = bcd_power_tens[fraction_len]
    if number / b > BCD_INTEGER_LIMIT {
      0
    } else {
      (@font_types.Fixed::from_bits(number) / @font_types.Fixed::from_bits(b)).to_bits()
    }
  } else {
    number = number * bcd_power_tens[-fraction_len]
    if number > BCD_INTEGER_LIMIT {
      return bcd_overflow
    } else {
      number << 16
    }
  }
  if scale_by_1000 {
    // FreeType stores the scaled value and does a fixed division by
    // 1000 when the blue metrics are requested. We just do it here
    result = (@font_types.Fixed::from_bits(result) /
    @font_types.Fixed::from_i32(1000)).to_bits()
  }
  @font_types.Fixed::from_bits(result * self.sign)
}

///|
/// Returns the fixed point value for the components along with a
/// dynamically determined scale factor.
///
/// Use for processing FontMatrix components.
fn BcdComponents::dynamically_scaled_value(
  self : BcdComponents,
) -> (@font_types.Fixed, Int) {
  if self.error is Some(error) {
    return (error, 0)
  }
  let mut number = self.number
  if number == 0 {
    return (@font_types.Fixed::zero(), 0)
  }
  let mut exponent = self.exponent
  let integer_len = self.integer_len
  let mut fraction_len = self.fraction_len
  exponent += self.exponent_add
  fraction_len += integer_len
  exponent += integer_len
  let mut result = @font_types.Fixed::zero()
  let mut scaling = 0
  if fraction_len <= 5 {
    if number > BCD_INTEGER_LIMIT {
      result = @font_types.Fixed::from_bits(number) /
        @font_types.Fixed::from_bits(10)
      scaling = exponent - fraction_len + 1
    } else {
      if exponent > 0 {
        // Make scaling as small as possible
        let new_fraction_len = if exponent < 5 { exponent } else { 5 }
        let shift = new_fraction_len - fraction_len
        if shift > 0 {
          exponent -= new_fraction_len
          number *= bcd_power_tens[shift]
          if number > BCD_INTEGER_LIMIT {
            number /= 10
            exponent += 1
          }
        } else {
          exponent -= fraction_len
        }
      } else {
        exponent -= fraction_len
      }
      result = @font_types.Fixed::from_bits(number << 16)
      scaling = exponent
    }
  } else if number / bcd_power_tens[fraction_len - 5] > BCD_INTEGER_LIMIT {
    result = @font_types.Fixed::from_bits(number) /
      @font_types.Fixed::from_bits(bcd_power_tens[fraction_len - 4])
    scaling = exponent - 4
  } else {
    result = @font_types.Fixed::from_bits(number) /
      @font_types.Fixed::from_bits(bcd_power_tens[fraction_len - 5])
    scaling = exponent - 5
  }
  (@font_types.Fixed::from_bits(result.to_bits() * self.sign), scaling)
}

///|
/// Parse a fixed point value with a dynamic scaling factor.
fn parse_fixed_dynamic(
  cursor : Cursor,
) -> (@font_types.Fixed, Int) raise PsError {
  let b0 = cursor.read_u8()
  match b0 {
    30 => BcdComponents::parse(cursor).dynamically_scaled_value()
    28 | 29 | 32..=254 => {
      let num = parse_int(cursor, b0)
      let mut int_len = 10
      if num > BCD_INTEGER_LIMIT {
        for i in 5..<10 {
          if num < bcd_power_tens[i] {
            int_len = i
            break
          }
        }
        let scaling = if num - bcd_power_tens[int_len - 5] > BCD_INTEGER_LIMIT {
          int_len - 4
        } else {
          int_len - 5
        }
        (
          @font_types.Fixed::from_bits(num) /
          @font_types.Fixed::from_bits(bcd_power_tens[scaling]),
          scaling,
        )
      } else {
        (@font_types.Fixed::from_bits(num << 16), 0)
      }
    }
    _ => raise InvalidNumber
  }
}
