// Rust `f32` formatting and parsing as subsetter relies on them for CFF real
// numbers: `impl Display for f32` (shortest round-trip digits, never in
// exponent notation; Dragon4 as in typst.mbt's `library/rust_fmt.mbt`) and
// `str::parse::<f32>` (correctly rounded).

///|
/// Rust's `impl Display for f32` (`{}`).
fn rust_display_f32(x : Float) -> String {
  if x.is_nan() {
    return "NaN"
  }
  let neg = x.reinterpret_as_uint() >> 31 == 1
  let sign = if neg { "-" } else { "" }
  if x.is_inf() {
    return sign + "inf"
  }
  if x == 0.0 {
    return sign + "0"
  }
  let (digits, point) = shortest_digits_f32(x)
  sign + place_point(digits, point)
}

///|
/// The shortest round-trip decimal digits and exponent of a finite, non-zero
/// `f32`: `x = 0.d1d2d3... * 10^exp`.
fn shortest_digits_f32(x : Float) -> (String, Int) {
  // `flt2dec::decode` for `f32`.
  let bits = x.abs().reinterpret_as_uint()
  let biased = ((bits >> 23) & 0xFF).reinterpret_as_int()
  let frac = (bits & 0x7FFFFF).to_uint64()
  let (raw_mant, raw_exp) = if biased == 0 {
    (frac << 1, -150)
  } else {
    (frac | 0x800000UL, biased - 150)
  }
  shortest_digits_decoded(
    raw_mant,
    raw_exp,
    biased == 0,
    raw_mant == 0x800000UL,
    x.abs().to_double(),
  )
}

///|
/// Dragon4 shortest digits of `raw_mant * 2^raw_exp` (Rust's
/// `format_shortest` after `decode`), including how it picks between two
/// equally short candidates: when the remaining digits are exactly half way,
/// it rounds up. `approx` is used for the initial exponent estimate only.
fn shortest_digits_decoded(
  raw_mant : UInt64,
  raw_exp : Int,
  subnormal : Bool,
  boundary : Bool,
  approx : Double,
) -> (String, Int) {
  let inclusive = (raw_mant & 1UL) == 0UL
  let (mant, minus, plus, exp) = if subnormal {
    (raw_mant, 1, 1, raw_exp)
  } else if boundary {
    (raw_mant << 2, 1, 2, raw_exp - 2)
  } else {
    (raw_mant << 1, 1, 1, raw_exp - 1)
  }
  let mut r = @bigint.BigInt::from_uint64(mant)
  let mut m_minus = @bigint.BigInt::from_int(minus)
  let mut m_plus = @bigint.BigInt::from_int(plus)
  let mut s = @bigint.BigInt::from_int(1)
  if exp < 0 {
    s = s << -exp
  } else {
    r = r << exp
    m_minus = m_minus << exp
    m_plus = m_plus << exp
  }
  let below = (a : @bigint.BigInt, b : @bigint.BigInt) => {
    if inclusive {
      a <= b
    } else {
      a < b
    }
  }
  let ten = @bigint.BigInt::from_int(10)
  let upper = r + m_plus
  let scaled_below = (k : Int) => {
    if k >= 0 {
      below(s * ten.pow(@bigint.BigInt::from_int(k)), upper)
    } else {
      below(s, upper * ten.pow(@bigint.BigInt::from_int(-k)))
    }
  }
  let mut k = @math.log10(approx).floor().to_int()
  while scaled_below(k) {
    k += 1
  }
  while !scaled_below(k - 1) {
    k -= 1
  }
  let (r0, mm0, mp0, s0) = if k - 1 >= 0 {
    (r, m_minus, m_plus, s * ten.pow(@bigint.BigInt::from_int(k - 1)))
  } else {
    let f = ten.pow(@bigint.BigInt::from_int(1 - k))
    (r * f, m_minus * f, m_plus * f, s)
  }
  let mut r = r0
  let mut m_minus = mm0
  let mut m_plus = mp0
  let scale = s0
  let digits = []
  let mut down = false
  let mut up = false
  for ;; {
    let d = r / scale
    r = r % scale
    digits.push(d.to_int())
    down = below(r, m_minus)
    up = below(scale, r + m_plus)
    if down || up {
      break
    }
    r = r * ten
    m_minus = m_minus * ten
    m_plus = m_plus * ten
  }
  if up && (!down || r + r >= scale) {
    let mut i = digits.length() - 1
    while i >= 0 && digits[i] == 9 {
      digits[i] = 0
      i -= 1
    }
    if i < 0 {
      digits[0] = 1
      digits.push(0)
      k += 1
    } else {
      digits[i] += 1
    }
  }
  while digits.length() > 1 && digits[digits.length() - 1] == 0 {
    digits.pop() |> ignore
  }
  let buf = StringBuilder()
  for d in digits {
    buf.write_char((48 + d).unsafe_to_char())
  }
  (buf.to_string(), k)
}

///|
/// Place the decimal point into `digits` (`0.digits * 10^point`).
fn place_point(digits : String, point : Int) -> String {
  let buf = StringBuilder()
  let n = digits.length()
  if point <= 0 {
    buf.write_string("0.")
    for _ in 0..<-point {
      buf.write_char('0')
    }
    buf.write_string(digits)
  } else if point >= n {
    buf.write_string(digits)
    for _ in 0..<(point - n) {
      buf.write_char('0')
    }
  } else {
    buf.write_string(digits.unsafe_substring(start=0, end=point))
    buf.write_char('.')
    buf.write_string(digits.unsafe_substring(start=point, end=n))
  }
  buf.to_string()
}

///|
/// Rust's `str::parse::<f32>` for the strings CFF real numbers produce
/// (digits, `.`, `E` and `-`): `None` if the syntax is invalid, else the
/// correctly rounded value (overflowing to infinity).
fn parse_f32(s : String) -> Float? {
  let chars = s.to_array()
  let n = chars.length()
  let mut i = 0
  let mut neg = false
  if i < n && (chars[i] == '-' || chars[i] == '+') {
    neg = chars[i] == '-'
    i += 1
  }
  // The mantissa digits (without the point) and the number of fractional
  // digits.
  let mant = StringBuilder()
  let mut num_digits = 0
  let mut frac_digits = 0
  while i < n && chars[i] >= '0' && chars[i] <= '9' {
    mant.write_char(chars[i])
    num_digits += 1
    i += 1
  }
  if i < n && chars[i] == '.' {
    i += 1
    while i < n && chars[i] >= '0' && chars[i] <= '9' {
      mant.write_char(chars[i])
      num_digits += 1
      frac_digits += 1
      i += 1
    }
  }
  if num_digits == 0 {
    return None
  }
  let mut exp = 0
  if i < n && (chars[i] == 'E' || chars[i] == 'e') {
    i += 1
    let mut exp_neg = false
    if i < n && (chars[i] == '-' || chars[i] == '+') {
      exp_neg = chars[i] == '-'
      i += 1
    }
    let start = i
    while i < n && chars[i] >= '0' && chars[i] <= '9' {
      // (Clamped: the value is zero or infinite long before.)
      if exp < 100000 {
        exp = exp * 10 + (chars[i].to_int() - 48)
      }
      i += 1
    }
    if i == start {
      return None
    }
    if exp_neg {
      exp = -exp
    }
  }
  if i != n {
    return None
  }
  let m = @bigint.BigInt::from_string(mant.to_string())
  let sign = if neg { -1.0 } else { 1.0 }
  if m.is_zero() {
    return Some(Float::from_double(sign * 0.0))
  }
  let e10 = exp - frac_digits
  // The decimal exponent of the leading digit.
  let lead = e10 + m.to_string().length() - 1
  if lead > 39 {
    return Some(Float::from_double(sign * @double.infinity))
  }
  if lead < -47 {
    return Some(Float::from_double(sign * 0.0))
  }
  let ten = @bigint.BigInt::from_int(10)
  let (num, den) = if e10 >= 0 {
    (m * ten.pow(@bigint.BigInt::from_int(e10)), @bigint.BigInt::from_int(1))
  } else {
    (m, ten.pow(@bigint.BigInt::from_int(-e10)))
  }
  // floor(log2(num / den)).
  let mut e2 = num.bit_length() - den.bit_length()
  let ge = if e2 >= 0 { num >= den << e2 } else { num << -e2 >= den }
  if !ge {
    e2 -= 1
  }
  // Round `num / den * 2^shift` to an integer, half to even.
  let round_scaled = (shift : Int) => {
    let (a, b) = if shift >= 0 {
      (num << shift, den)
    } else {
      (num, den << -shift)
    }
    let q = a / b
    let r = a % b
    let twice = r << 1
    let c = twice.compare(b)
    if c > 0 || (c == 0 && !(q % @bigint.BigInt::from_int(2)).is_zero()) {
      q + @bigint.BigInt::from_int(1)
    } else {
      q
    }
  }
  let bits = if e2 >= -126 {
    let mut mant = round_scaled(23 - e2).to_int()
    let mut e2 = e2
    if mant == 1 << 24 {
      mant = mant >> 1
      e2 += 1
    }
    if e2 > 127 {
      0x7F800000U
    } else {
      (((e2 + 127) << 23) | (mant - (1 << 23))).reinterpret_as_uint()
    }
  } else {
    // Subnormal (a mantissa of 2^23 is the smallest normal number).
    round_scaled(149).to_int().reinterpret_as_uint()
  }
  let f = Float::reinterpret_from_uint(bits)
  Some(if neg { -f } else { f })
}
