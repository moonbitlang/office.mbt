///|
fn PdfDocumentPageSpecContext::read_page_label_reference(
  self : PdfDocumentPageSpecContext,
  spec : BytesView,
  open_index : Int,
) -> (Bytes, Int) raise @core.PdfError {
  let label : Array[Byte] = []
  for index = open_index + 1; index < spec.length(); {
    match spec[index] {
      b']' => return (Bytes::from_array(label), index + 1)
      b'\\' if index + 1 < spec.length() && spec[index + 1] is (b'[' | b']') => {
        label.push(spec[index + 1])
        continue index + 2
      }
      b'[' => {
        self.bad()
        continue index + 1
      }
      byte => {
        label.push(byte)
        continue index + 1
      }
    }
  }
  self.bad()
  (Bytes::new(0), spec.length())
}

///|
fn PdfDocumentPageSpecContext::page_number_bytes_for_label(
  self : PdfDocumentPageSpecContext,
  label : BytesView,
  labels : ArrayView[@label.PdfPageLabel],
) -> Bytes raise @core.PdfError {
  for page_number in 1..<=self.end_page {
    let page_label = match
      @label.pdf_page_label_text_of_page_number(page_number, labels) {
      Some(value) => value
      None => Bytes::new(0)
    }
    if page_label[:] == label {
      return @ascii.encode(page_number.to_string())
    }
  }
  self.bad()
  Bytes::new(0)
}

///|
fn PdfDocumentPageSpecContext::resolve_page_labels(
  self : PdfDocumentPageSpecContext,
  spec : BytesView,
) -> Bytes raise @core.PdfError {
  let labels = self.document.read_page_labels()
  let output : Array[Byte] = Array::new(capacity=spec.length())
  for index = 0; index < spec.length(); {
    match spec[index] {
      b'[' => {
        let (label, next_index) = self.read_page_label_reference(spec, index)
        let page_number = self.page_number_bytes_for_label(label, labels)
        for byte in page_number {
          output.push(byte)
        }
        continue next_index
      }
      b'\\' if index + 1 < spec.length() && spec[index + 1] is (b'[' | b']') => {
        output.push(spec[index + 1])
        continue index + 2
      }
      b']' => {
        self.bad()
        continue index + 1
      }
      byte => {
        output.push(byte)
        continue index + 1
      }
    }
  }
  Bytes::from_array(output)
}
