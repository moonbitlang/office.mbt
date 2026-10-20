// SPDX-License-Identifier: MPL-2.0
// Adapted from mtx-decompressor 1.8.0, ChristopherVR; see NOTICE.

///|
/// A malformed compressed font or a decompression limit violation.
pub suberror DecodeError {
  InvalidMtx(String)
}

///|
pub extend DecodeError with Show::{to_string, output}

///|
pub impl Show for DecodeError with fn output(self, logger) {
  let InvalidMtx(message) = self
  logger.write_string("invalid MTX font: " + message)
}

///|
fn bad(message : String) -> Unit raise {
  raise InvalidMtx(message)
}

///|
let budget : Int32 = 64 * 1024 * 1024

///|
priv struct Stream {
  data : Array[Byte]
  mut pos : Int32
  mut bit : Int32
}

///|
fn Stream::new(data~ : Bytes = b"") -> Stream {
  { data: data.to_array(), pos: 0, bit: 0, }
}

///|
fn Stream::seek(self : Stream, pos : Int32) -> Unit raise {
  guard self.bit == 0 && pos >= 0 && pos <= self.data.length() else {
    bad("MTX seek outside stream")
    return
  }
  self.pos = pos
}

///|
fn Stream::u8(self : Stream) -> Int32 raise {
  guard self.bit == 0 && self.pos < self.data.length() else {
    bad("truncated MTX byte stream")
    return 0
  }
  let value = self.data[self.pos].to_int()
  self.pos += 1
  value
}

///|
fn Stream::uint(self : Stream, count : Int32) -> Int32 raise {
  let mut value = 0
  for _ in 0..<count {
    value = (value << 8) | self.u8()
  }
  value
}

///|
fn signed16(value : Int32) -> Int32 {
  let value = value & 65535
  if value >= 32768 {
    value - 65536
  } else {
    value
  }
}

///|
fn Stream::s16(self : Stream) -> Int32 raise {
  signed16(self.uint(2))
}

///|
fn Stream::bits(
  self : Stream,
  count : Int32,
  lsb~ : Bool = false,
) -> Int32 raise {
  let mut value = 0
  for _ in 0..<count {
    guard self.pos < self.data.length() else {
      bad("truncated MTX bit stream")
      return 0
    }
    let shift = if lsb { self.bit } else { 7 - self.bit }
    value = (value << 1) | ((self.data[self.pos].to_int() >> shift) & 1)
    self.bit += 1
    if self.bit == 8 {
      self.bit = 0
      self.pos += 1
    }
  }
  value
}

///|
fn Stream::put(self : Stream, value : Int32, count~ : Int32 = 1) -> Unit raise {
  guard self.bit == 0 && self.pos >= 0 && count <= budget - self.pos else {
    bad("MTX output budget exceeded")
    return
  }
  while self.data.length() < self.pos + count {
    self.data.push(0)
  }
  for i in 0..<count {
    self.data[self.pos + i] = ((value >> ((count - i - 1) * 8)) & 255).to_byte()
  }
  self.pos += count
}

///|
fn Stream::copy(self : Stream, out : Stream, count : Int32) -> Unit raise {
  guard count >= 0 && self.bit == 0 && count <= self.data.length() - self.pos else {
    bad("truncated MTX copy")
    return
  }
  for _ in 0..<count {
    out.put(self.u8())
  }
}

///|
fn Stream::bytes(self : Stream) -> Bytes {
  Bytes::from_array(self.data)
}

///|
fn Stream::short255(self : Stream) -> Int32 raise {
  let mut code = self.u8()
  if code == 253 {
    return self.s16()
  }
  let sign = if code == 250 {
    code = self.u8()
    -1
  } else {
    1
  }
  let value = if code == 255 {
    250 + self.u8()
  } else if code == 254 {
    500 + self.u8()
  } else {
    code
  }
  sign * value
}

///|
fn Stream::ushort255(self : Stream) -> Int32 raise {
  match self.u8() {
    253 => self.uint(2)
    255 => 253 + self.u8()
    254 => 506 + self.u8()
    code => code
  }
}

///|
fn Stream::magnitude(self : Stream) -> Int32 raise {
  if self.bits(1, lsb=true) == 0 {
    return 0
  }
  let mut value = 1
  while self.bits(1, lsb=true) == 1 {
    value += 1
    guard value <= 65536 else {
      bad("MTX magnitude out of range")
      return 0
    }
  }
  if self.bits(1, lsb=true) == 1 {
    -value
  } else {
    value
  }
}
