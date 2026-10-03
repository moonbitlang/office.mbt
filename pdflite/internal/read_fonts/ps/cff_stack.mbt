// Port of read-fonts 0.39.2 `src/ps/cff/stack.rs` (without CFF2 blending).

///|
/// Maximum size of the operand stack.
const MAX_STACK : Int = 513

///|
/// Operand stack for DICTs and charstrings.
///
/// The operand stack can contain either 32-bit integers or 16.16 fixed point
/// values. Entries are stored in parallel arrays holding the raw 32-bit value
/// and a flag that tracks which values are fixed point.
pub struct Stack {
  values : FixedArray[Int]
  value_is_fixed : FixedArray[Bool]
  mut top : Int
}

///|
/// Either a signed 32-bit integer or a 16.16 fixed point number.
pub(all) enum Number {
  I32(Int)
  Fixed(@font_types.Fixed)
} derive(Eq, Debug)

///|
pub fn Stack::new() -> Stack {
  {
    values: FixedArray::make(MAX_STACK, 0),
    value_is_fixed: FixedArray::make(MAX_STACK, false),
    top: 0,
  }
}

///|
pub fn Stack::is_empty(self : Stack) -> Bool {
  self.top == 0
}

///|
pub fn Stack::len(self : Stack) -> Int {
  self.top
}

///|
/// Returns true if the number of elements on the stack is odd.
pub fn Stack::len_is_odd(self : Stack) -> Bool {
  (self.top & 1) != 0
}

///|
pub fn Stack::clear(self : Stack) -> Unit {
  self.top = 0
}

///|
/// Swaps the top two elements.
fn Stack::exch(self : Stack) -> Unit raise PsError {
  if self.top < 2 {
    raise StackUnderflow
  }
  let a = self.top - 1
  let b = a - 1
  let v = self.values[a]
  self.values[a] = self.values[b]
  self.values[b] = v
  let f = self.value_is_fixed[a]
  self.value_is_fixed[a] = self.value_is_fixed[b]
  self.value_is_fixed[b] = f
}

///|
pub fn Stack::push_i32(self : Stack, value : Int) -> Unit raise PsError {
  self.push_impl(value, false)
}

///|
pub fn Stack::push_fixed(
  self : Stack,
  value : @font_types.Fixed,
) -> Unit raise PsError {
  self.push_impl(value.to_bits(), true)
}

///|
pub fn Stack::push(self : Stack, number : Number) -> Unit raise PsError {
  match number {
    I32(v) => self.push_impl(v, false)
    Fixed(v) => self.push_impl(v.to_bits(), true)
  }
}

///|
/// Sets the element at `index` to the given fixed point value.
fn Stack::set_fixed(
  self : Stack,
  index : Int,
  value : @font_types.Fixed,
) -> Unit raise PsError {
  if index >= self.top {
    raise StackOverflow
  }
  self.value_is_fixed[index] = true
  self.values[index] = value.to_bits()
}

///|
/// Drops `n` elements from the top of the stack.
///
/// If `n` is greater than the length of the stack, this simply acts as
/// a clear operation.
pub fn Stack::drop(self : Stack, n : Int) -> Unit {
  let t = self.top - n
  self.top = if n < 0 || t < 0 { 0 } else { t }
}

///|
/// Returns the 32-bit integer at the given index on the stack.
///
/// Will return an error if the value at that index was not pushed as an
/// integer.
pub fn Stack::get_i32(self : Stack, index : Int) -> Int raise PsError {
  // FreeType just returns 0 for OOB access
  if index < 0 || index >= MAX_STACK {
    return 0
  }
  if self.value_is_fixed[index] {
    // FreeType returns an error here rather than converting
    raise ExpectedI32StackEntry(index)
  } else {
    self.values[index]
  }
}

///|
/// Returns the 16.16 fixed point value at the given index on the stack.
///
/// If the value was pushed as an integer, it will be automatically
/// converted to 16.16 fixed point.
pub fn Stack::get_fixed(self : Stack, index : Int) -> @font_types.Fixed {
  // FreeType just returns 0 for OOB access
  if index < 0 || index >= MAX_STACK {
    return @font_types.Fixed::zero()
  }
  let value = self.values[index]
  if self.value_is_fixed[index] {
    @font_types.Fixed::from_bits(value)
  } else {
    @font_types.Fixed::from_i32(value)
  }
}

///|
/// Pops a 32-bit integer from the top of stack.
pub fn Stack::pop_i32(self : Stack) -> Int raise PsError {
  let i = self.pop()
  self.get_i32(i)
}

///|
/// Pops a 16.16 fixed point value from the top of the stack.
pub fn Stack::pop_fixed(self : Stack) -> @font_types.Fixed {
  let i = self.pop()
  self.get_fixed(i)
}

///|
/// Returns all elements on the stack as 16.16 fixed point values.
pub fn Stack::fixed_values(self : Stack) -> Array[@font_types.Fixed] {
  [
    for i in 0..<self.top => self.get_fixed(i)
  ]
}

///|
/// Returns an array of `n` 16.16 fixed point values starting at
/// `first_index`.
pub fn Stack::fixed_array(
  self : Stack,
  first_index : Int,
  n : Int,
) -> FixedArray[@font_types.Fixed] {
  let result = FixedArray::make(n, @font_types.Fixed::zero())
  // FreeType doesn't have an equivalent to this function but always
  // returns 0 on failure so we take the maximum valid range and
  // pad the remainder with zeros
  let end = first_index + n
  let start = if first_index < self.top { first_index } else { self.top }
  let end = if end < self.top { end } else { self.top }
  for i in start..<end {
    result[i - start] = self.get_fixed(i)
  }
  result
}

///|
/// Apply a prefix sum to decode delta-encoded numbers.
pub fn Stack::apply_delta_prefix_sum(self : Stack) -> Unit {
  if self.top > 1 {
    let mut sum = @font_types.Fixed::zero()
    for i in 0..<self.top {
      let fixed_value = self.get_fixed(i)
      // FreeType does not use checked arithmetic so we need to explicitly
      // use wrapping behavior to produce matching outlines.
      sum = sum.wrapping_add(fixed_value)
      self.values[i] = sum.to_bits()
      self.value_is_fixed[i] = true
    }
  }
}

///|
/// Pops the top two elements from the stack and pushes the quotient.
///
/// Implements special behavior for Type1 fonts to handle the case of
/// integers greater than 32k per FreeType.
fn Stack::div(self : Stack, is_type1 : Bool) -> Unit raise PsError {
  let b_idx = self.pop()
  let a_idx = self.pop()
  let (a, b) = if self.value_is_fixed[a_idx] {
    (self.get_fixed(a_idx), self.get_fixed(b_idx))
  } else {
    // In type1 fonts, we can end up with an integer greater than
    // 32k. In this case, FT just reinterprets both as fixed point
    // and divides.
    let a = self.get_i32(a_idx)
    if is_type1 && !(a >= -32000 && a <= 32000) {
      (
        @font_types.Fixed::from_bits(a),
        @font_types.Fixed::from_bits(self.get_i32(b_idx)),
      )
    } else {
      (self.get_fixed(a_idx), self.get_fixed(b_idx))
    }
  }
  self.push_fixed(a / b)
}

///|
fn Stack::push_impl(
  self : Stack,
  value : Int,
  is_fixed : Bool,
) -> Unit raise PsError {
  if self.top == MAX_STACK {
    raise StackOverflow
  }
  self.values[self.top] = value
  self.value_is_fixed[self.top] = is_fixed
  self.top += 1
}

///|
fn Stack::pop(self : Stack) -> Int {
  if self.top > 0 {
    self.top -= 1
    self.top
  } else {
    0
  }
}
