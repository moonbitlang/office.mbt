///|
/// A byte sink used in two phases: first without storage to prove the exact
/// serialized size, then with one fixed backing array of that size. Keeping the
/// position and limit checks in one type makes the sizing and emission paths
/// obey identical overflow and output-ceiling rules.
priv struct FixedByteOutput {
  storage : FixedArray[Byte]?
  mut position : Int
  limit : Int?
}

///|
fn FixedByteOutput::counting(limit? : Int) -> FixedByteOutput raise ZipError {
  match limit {
    Some(value) if value < 0 =>
      raise UnsupportedFeature(msg="ZIP output limit must be non-negative")
    _ => ()
  }
  { storage: None, position: 0, limit }
}

///|
fn FixedByteOutput::allocated(size : Int) -> FixedByteOutput raise ZipError {
  if size < 0 {
    raise UnsupportedFeature(msg="negative ZIP output size")
  }
  {
    storage: Some(FixedArray::make(size, b'\x00')),
    position: 0,
    limit: Some(size),
  }
}

///|
fn FixedByteOutput::length(self : FixedByteOutput) -> Int {
  self.position
}

///|
fn FixedByteOutput::is_counting(self : FixedByteOutput) -> Bool {
  self.storage is None
}

///|
fn FixedByteOutput::remaining_limit(self : FixedByteOutput) -> Int? {
  match self.limit {
    Some(limit) if self.position <= limit => Some(limit - self.position)
    Some(_) => Some(0)
    None => None
  }
}

///|
fn FixedByteOutput::check_growth(
  self : FixedByteOutput,
  additional : Int,
) -> Unit raise ZipError {
  if additional < 0 ||
    self.position < 0 ||
    additional > 0x7fffffff - self.position {
    raise UnsupportedFeature(msg="ZIP output size exceeds the Int range")
  }
  match self.limit {
    Some(limit) =>
      if limit < 0 ||
        self.position > limit ||
        additional > limit - self.position {
        raise OutputLimitExceeded(limit~)
      }
    None => ()
  }
  match self.storage {
    Some(storage) =>
      if self.position > storage.length() ||
        additional > storage.length() - self.position {
        raise UnsupportedFeature(msg="fixed ZIP output plan was undersized")
      }
    None => ()
  }
}

///|
fn FixedByteOutput::count_bytes(
  self : FixedByteOutput,
  additional : Int,
) -> Unit raise ZipError {
  if !self.is_counting() {
    raise UnsupportedFeature(msg="cannot skip bytes in allocated ZIP output")
  }
  self.check_growth(additional)
  self.position = self.position + additional
}

///|
fn FixedByteOutput::write_byte(
  self : FixedByteOutput,
  value : Byte,
) -> Unit raise ZipError {
  self.check_growth(1)
  match self.storage {
    Some(storage) => storage[self.position] = value
    None => ()
  }
  self.position = self.position + 1
}

///|
fn FixedByteOutput::write_bytes(
  self : FixedByteOutput,
  bytes : BytesView,
) -> Unit raise ZipError {
  let length = bytes.length()
  self.check_growth(length)
  match self.storage {
    Some(storage) =>
      if length > 0 {
        storage.blit_from_bytesview(self.position, bytes)
      }
    None => ()
  }
  self.position = self.position + length
}

///|
/// Emits an overlapping DEFLATE back-reference. A counting sink needs only the
/// validated distance and length; an allocated sink copies from bytes already
/// written to the same exact-size destination.
fn FixedByteOutput::copy_back_reference(
  self : FixedByteOutput,
  distance : Int,
  length : Int,
) -> Unit raise ZipError {
  if distance <= 0 || distance > self.position {
    raise UnsupportedFeature(msg="invalid back-reference distance")
  }
  self.check_growth(length)
  match self.storage {
    Some(storage) =>
      for _ in 0..<length {
        storage[self.position] = storage[self.position - distance]
        self.position = self.position + 1
      }
    None => self.position = self.position + length
  }
}

///|
/// Reinterprets the one exact backing allocation as immutable bytes. Callers
/// must not retain or mutate the output sink after this ownership handoff.
fn FixedByteOutput::finish(self : FixedByteOutput) -> Bytes raise ZipError {
  match self.storage {
    Some(storage) => {
      if self.position != storage.length() {
        raise UnsupportedFeature(
          msg="fixed ZIP output plan was not fully emitted",
        )
      }
      storage.unsafe_reinterpret_as_bytes()
    }
    None =>
      raise UnsupportedFeature(msg="counting ZIP output has no byte storage")
  }
}
