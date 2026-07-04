///|
fn pdf_pagespec_copy_view(
  output : Array[Byte],
  position : Int,
  bytes : BytesView,
) -> Int {
  let mut position = position
  for byte in bytes {
    output[position] = byte
    position += 1
  }
  position
}

///|
fn PdfDocumentPageSpecContext::read_page_label_reference(
  self : PdfDocumentPageSpecContext,
  spec : BytesView,
  open_index : Int,
) -> (Bytes, Int) raise @core.PdfError {
  let mut index = open_index + 1
  let mut label_length = 0
  let mut closed = false
  while index < spec.length() && !closed {
    let current = spec[index].to_int()
    if current == 93 {
      closed = true
      index += 1
    } else if current == 92 &&
      index + 1 < spec.length() &&
      (spec[index + 1].to_int() == 91 || spec[index + 1].to_int() == 93) {
      label_length += 1
      index += 2
    } else if current == 91 {
      self.bad()
    } else {
      label_length += 1
      index += 1
    }
  }
  if !closed {
    self.bad()
  }
  let output = Array::make(label_length, b'\x00')
  let mut position = 0
  let mut label_index = open_index + 1
  let close_index = index - 1
  while label_index < close_index {
    let current = spec[label_index].to_int()
    if current == 92 &&
      label_index + 1 < close_index &&
      (
        spec[label_index + 1].to_int() == 91 ||
        spec[label_index + 1].to_int() == 93
      ) {
      output[position] = spec[label_index + 1]
      label_index += 2
    } else {
      output[position] = spec[label_index]
      label_index += 1
    }
    position += 1
  }
  (Bytes::from_array(output), index)
}

///|
fn PdfDocumentPageSpecContext::page_number_bytes_for_label(
  self : PdfDocumentPageSpecContext,
  label : BytesView,
  labels : ArrayView[@label.PdfPageLabel],
) -> Bytes raise @core.PdfError {
  let mut found = false
  let mut output = Bytes::new(0)
  for page_number in 1..<=self.end_page {
    let page_label = match
      @label.pdf_page_label_text_of_page_number(page_number, labels) {
      Some(value) => value
      None => Bytes::new(0)
    }
    if !found && page_label[:] == label {
      output = @ascii.encode(page_number.to_string())
      found = true
    }
  }
  if found {
    output
  } else {
    self.bad()
    Bytes::new(0)
  }
}

///|
fn PdfDocumentPageSpecContext::resolved_page_labels_length(
  self : PdfDocumentPageSpecContext,
  spec : BytesView,
  labels : ArrayView[@label.PdfPageLabel],
) -> Int raise @core.PdfError {
  let mut length = 0
  let mut index = 0
  while index < spec.length() {
    let value = spec[index].to_int()
    if value == 91 {
      let (label, next_index) = self.read_page_label_reference(spec, index)
      let page_number = self.page_number_bytes_for_label(label, labels)
      length += page_number.length()
      index = next_index
    } else if value == 92 &&
      index + 1 < spec.length() &&
      (spec[index + 1].to_int() == 91 || spec[index + 1].to_int() == 93) {
      length += 1
      index += 2
    } else if value == 93 {
      self.bad()
    } else {
      length += 1
      index += 1
    }
  }
  length
}

///|
fn PdfDocumentPageSpecContext::resolve_page_labels(
  self : PdfDocumentPageSpecContext,
  spec : BytesView,
) -> Bytes raise @core.PdfError {
  let labels = self.document.read_page_labels()
  let output = Array::make(
    self.resolved_page_labels_length(spec, labels),
    b'\x00',
  )
  let mut index = 0
  let mut position = 0
  while index < spec.length() {
    let value = spec[index].to_int()
    if value == 91 {
      let (label, next_index) = self.read_page_label_reference(spec, index)
      let page_number = self.page_number_bytes_for_label(label, labels)
      position = pdf_pagespec_copy_view(output, position, page_number)
      index = next_index
    } else if value == 92 &&
      index + 1 < spec.length() &&
      (spec[index + 1].to_int() == 91 || spec[index + 1].to_int() == 93) {
      output[position] = spec[index + 1]
      position += 1
      index += 2
    } else if value == 93 {
      self.bad()
    } else {
      output[position] = spec[index]
      position += 1
      index += 1
    }
  }
  Bytes::from_array(output)
}
