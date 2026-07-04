///|
priv struct PdfImageExtractionJbig2Global {
  object_number : Int
  serial : Int
}

///|
priv struct PdfImageExtractionState {
  next_jbig2_serial : Ref[Int]
  globals : Array[PdfImageExtractionJbig2Global]
}

///|
fn PdfImageExtractionState::jbig2_serial(
  self : PdfImageExtractionState,
  object_number : Int,
) -> Int? {
  for entry in self.globals {
    if entry.object_number == object_number {
      break Some(entry.serial)
    }
  } nobreak {
    None
  }
}

///|
fn PdfImageExtractionState::add_jbig2_global(
  self : PdfImageExtractionState,
  object_number : Int,
) -> Int {
  self.next_jbig2_serial.val += 1
  let serial = self.next_jbig2_serial.val
  self.globals.push({ object_number, serial })
  serial
}
