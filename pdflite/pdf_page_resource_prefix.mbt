///|
fn pdf_page_prefixed_name(prefix : String, name : PdfName) -> PdfName {
  let prefix_bytes = @ascii.encode(prefix)
  let bytes = name.bytes()
  let start = if bytes.length() > 0 && bytes[0].to_int() == 47 { 1 } else { 0 }
  let output = Array::make(
    1 + prefix_bytes.length() + bytes.length() - start,
    b'\x00',
  )
  output[0] = 47
  let mut position = 1
  for byte in prefix_bytes {
    output[position] = byte
    position += 1
  }
  for i in start..<bytes.length() {
    output[position] = bytes[i]
    position += 1
  }
  pdf_name_of_bytes(Bytes::from_array(output))
}

///|
fn pdf_page_name_member(names : ArrayView[PdfName], name : PdfName) -> Bool {
  for candidate in names {
    if candidate == name {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_page_direct_color_names() -> Array[PdfName] {
  [
    pdf_page_device_gray_name, pdf_page_device_rgb_name, pdf_page_device_cmyk_name,
    pdf_page_pattern_resource_name,
  ]
}

///|
fn pdf_page_direct_inline_color_names() -> Array[PdfName] {
  [
    pdf_page_device_gray_name, pdf_page_device_rgb_name, pdf_page_device_cmyk_name,
    pdf_page_g_name, pdf_page_rgb_name, pdf_page_cmyk_name,
  ]
}

///|
fn PdfDocument::pdf_page_prefix_inline_image_dictionary(
  self : PdfDocument,
  prefix : String,
  dictionary : @syntax.PdfObject,
) -> @syntax.PdfObject raise PdfError {
  match
    self.lookup_direct_or_else(
      pdf_page_cs_key_name, pdf_page_colorspace_resource_name, dictionary,
    ) {
    Some(PdfNameObject(name)) if !pdf_page_name_member(
        pdf_page_direct_inline_color_names(),
        name,
      ) =>
      dictionary
      .remove_dict_entry(pdf_page_colorspace_resource_name)
      .remove_dict_entry(pdf_page_cs_key_name)
      .add_dict_entry(
        pdf_page_cs_key_name,
        PdfNameObject(pdf_page_prefixed_name(prefix, name)),
      )
    _ => dictionary
  }
}

///|
fn PdfDocument::pdf_page_prefix_content_op(
  self : PdfDocument,
  prefix : String,
  op : @content.PdfContentOp,
) -> @content.PdfContentOp raise PdfError {
  match op {
    Op_Tf(font, size) => Op_Tf(pdf_page_prefixed_name(prefix, font), size)
    Op_gs(name) => Op_gs(pdf_page_prefixed_name(prefix, name))
    Op_CS(name) =>
      if pdf_page_name_member(pdf_page_direct_color_names(), name) {
        op
      } else {
        Op_CS(pdf_page_prefixed_name(prefix, name))
      }
    Op_cs(name) =>
      if pdf_page_name_member(pdf_page_direct_color_names(), name) {
        op
      } else {
        Op_cs(pdf_page_prefixed_name(prefix, name))
      }
    Op_SCNName(name, values) =>
      Op_SCNName(pdf_page_prefixed_name(prefix, name), values)
    Op_scnName(name, values) =>
      Op_scnName(pdf_page_prefixed_name(prefix, name), values)
    Op_sh(name) => Op_sh(pdf_page_prefixed_name(prefix, name))
    Op_Do(name) => Op_Do(pdf_page_prefixed_name(prefix, name))
    Op_DP(tag, PdfNameObject(name)) =>
      Op_DP(tag, PdfNameObject(pdf_page_prefixed_name(prefix, name)))
    Op_BDC(tag, PdfNameObject(name)) =>
      Op_BDC(tag, PdfNameObject(pdf_page_prefixed_name(prefix, name)))
    Op_InlineImage(dictionary, decode_parms, data) =>
      Op_InlineImage(
        self.pdf_page_prefix_inline_image_dictionary(prefix, dictionary),
        decode_parms,
        data,
      )
    _ => op
  }
}

///|
fn PdfDocument::pdf_page_prefix_content_ops(
  self : PdfDocument,
  prefix : String,
  ops : ArrayView[@content.PdfContentOp],
) -> Array[@content.PdfContentOp] raise PdfError {
  let output : Array[@content.PdfContentOp] = Array::new(capacity=ops.length())
  for op in ops {
    output.push(self.pdf_page_prefix_content_op(prefix, op))
  }
  output
}

///|
fn PdfDocument::pdf_page_prefix_resource_dictionary(
  self : PdfDocument,
  prefix : String,
  resources : @syntax.PdfObject,
) -> @syntax.PdfObject raise PdfError {
  let mut output = resources
  for resource_key in pdf_page_resource_keys() {
    match self.lookup_direct(resource_key, resources) {
      Some(PdfDictionary(entries)) => {
        let new_entries : Array[(PdfName, @syntax.PdfObject)] = Array::new(
          capacity=entries.length(),
        )
        for entry in entries {
          let (name, value) = entry
          new_entries.push((pdf_page_prefixed_name(prefix, name), value))
        }
        output = output.add_dict_entry(resource_key, PdfDictionary(new_entries))
      }
      _ => output = output.add_dict_entry(resource_key, PdfDictionary([]))
    }
  }
  output
}
