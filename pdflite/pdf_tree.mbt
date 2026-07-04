///|
fn pdf_tree_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_tree_names_key_name : @core.PdfName = pdf_tree_name("/Names")

///|
fn pdf_tree_names_key() -> @core.PdfName {
  pdf_tree_names_key_name
}

///|
let pdf_tree_nums_key_name : @core.PdfName = pdf_tree_name("/Nums")

///|
fn pdf_tree_nums_key() -> @core.PdfName {
  pdf_tree_nums_key_name
}

///|
let pdf_tree_kids_key_name : @core.PdfName = pdf_tree_name("/Kids")

///|
fn pdf_tree_kids_key() -> @core.PdfName {
  pdf_tree_kids_key_name
}

///|
let pdf_tree_limits_key_name : @core.PdfName = pdf_tree_name("/Limits")

///|
fn pdf_tree_limits_key() -> @core.PdfName {
  pdf_tree_limits_key_name
}

///|
fn pdf_tree_byte_compare(left : Byte, right : Byte) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn pdf_tree_bytes_compare(left : Bytes, right : Bytes) -> Int {
  let shared = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  for i in 0..<shared {
    let compared = pdf_tree_byte_compare(left[i], right[i])
    if compared != 0 {
      break compared
    }
  } nobreak {
    left.length().compare(right.length())
  }
}
