///|
priv struct PdfImageExtractionRunState {
  serial : Ref[Int]
  written : Array[Int]
  jbig2 : PdfImageExtractionState
}

///|
fn PdfImageExtractionRunState::reset_written(
  self : PdfImageExtractionRunState,
) -> Unit {
  self.written.clear()
}

///|
fn PdfImageExtractionRunState::claim_images(
  self : PdfImageExtractionRunState,
  images : ArrayView[PdfObject],
  dedup : Bool,
  dedup_per_page : Bool,
) -> Array[PdfObject] {
  if !dedup && !dedup_per_page {
    images.to_owned()
  } else {
    let claimed : Array[PdfObject] = Array::new(capacity=images.length())
    for image in images {
      match image {
        PdfIndirect(number) if self.written.contains(number) => ()
        PdfIndirect(number) => {
          self.written.push(number)
          claimed.push(image)
        }
        _ => claimed.push(image)
      }
    }
    claimed
  }
}

///|
fn PdfImageExtractionRunState::next_serial(
  self : PdfImageExtractionRunState,
) -> Int {
  let serial = self.serial.val
  self.serial.val += 1
  serial
}
