///|
fn pdf_tweak_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_tweak_extgstate_key_name : PdfName = pdf_tweak_name("/ExtGState")

///|
fn pdf_tweak_extgstate_key() -> PdfName {
  pdf_tweak_extgstate_key_name
}

///|
let pdf_tweak_line_width_key_name : PdfName = pdf_tweak_name("/LW")

///|
fn pdf_tweak_line_width_key() -> PdfName {
  pdf_tweak_line_width_key_name
}

///|
let pdf_tweak_length_key_name : PdfName = pdf_tweak_name("/Length")

///|
fn pdf_tweak_length_key() -> PdfName {
  pdf_tweak_length_key_name
}

///|
let pdf_tweak_device_rgb_key_name : PdfName = pdf_tweak_name("/DeviceRGB")

///|
fn pdf_tweak_device_rgb_key() -> PdfName {
  pdf_tweak_device_rgb_key_name
}

///|
/// Colour value used by cpdf-style content colour rewrite operations.
pub(all) enum PdfContentColour {
  PdfContentGrey(Double)
  PdfContentRGB(Double, Double, Double)
  PdfContentCMYK(Double, Double, Double, Double)
} derive(Debug, Eq, ToJson)

///|
/// The default black content colour.
pub let pdf_content_black : PdfContentColour = PdfContentGrey(0.0)

///|
fn PdfContentColour::pdf_tweak_fill_op(self : PdfContentColour) -> PdfContentOp {
  match self {
    PdfContentGrey(grey) => Op_g(grey)
    PdfContentRGB(red, green, blue) => Op_rg(red, green, blue)
    PdfContentCMYK(cyan, magenta, yellow, black) =>
      Op_k(cyan, magenta, yellow, black)
  }
}

///|
fn PdfContentColour::pdf_tweak_stroke_op(
  self : PdfContentColour,
) -> PdfContentOp {
  match self {
    PdfContentGrey(grey) => Op_G(grey)
    PdfContentRGB(red, green, blue) => Op_RG(red, green, blue)
    PdfContentCMYK(cyan, magenta, yellow, black) =>
      Op_K(cyan, magenta, yellow, black)
  }
}

///|
fn pdf_tweak_number(object : PdfObject) -> Double? {
  match object {
    PdfReal(value) => Some(value)
    PdfInteger(value) => Some(value.to_double())
    _ => None
  }
}

///|
fn pdf_tweak_ctm_scale(stack : ArrayView[TransformMatrix]) -> Double {
  if stack.length() == 0 {
    1.0
  } else {
    stack[stack.length() - 1].decompose().scale
  }
}

///|
fn pdf_tweak_extgstate_line_width(
  document : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> Double? {
  match document.lookup_direct(pdf_tweak_extgstate_key(), resources) {
    Some(extgstate) =>
      match document.lookup_direct(name, extgstate) {
        Some(gdict) =>
          match document.lookup_direct(pdf_tweak_line_width_key(), gdict) {
            Some(value) => pdf_tweak_number(value)
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_tweak_append_page_content_ops_page(
  self : PdfDocument,
  page : PdfPage,
  ops : ArrayView[PdfContentOp],
  before : Bool,
  fast : Bool,
) -> PdfPage raise PdfError {
  if ops.length() == 0 {
    page
  } else if before {
    self.prepend_operators(page, ops, fast~)
  } else {
    self.postpend_operators(page, ops, fast~)
  }
}

///|
fn PdfDocument::pdf_tweak_append_page_content_page(
  self : PdfDocument,
  page : PdfPage,
  content : BytesView,
  before : Bool,
  fast : Bool,
) -> PdfPage raise PdfError {
  if content.length() == 0 {
    page
  } else {
    let ops = self.parse_content_view_with_resources(page.resources, content)
    self.pdf_tweak_append_page_content_ops_page(page, ops, before, fast)
  }
}

///|
fn pdf_tweak_validate_page_count(
  length : Int,
  page_count : Int,
) -> Unit raise PdfError {
  if length != page_count {
    raise BadPageSpecification("append_page_content_multiple")
  }
}

///|
fn pdf_tweak_is_digit_byte(byte : Byte) -> Bool {
  byte >= 48 && byte <= 57
}

///|
fn pdf_tweak_parse_digits(
  bytes : BytesView,
  start : Int,
  finish : Int,
  source : String,
) -> Int raise PdfError {
  if start >= finish {
    raise BadPageSpecification(source)
  }
  let mut value = 0
  for index in start..<finish {
    value = value * 10 + bytes[index].to_int() - 48
  }
  value
}

///|
fn pdf_tweak_digit_end(bytes : BytesView, start : Int) -> Int {
  let mut index = start
  while index < bytes.length() && pdf_tweak_is_digit_byte(bytes[index]) {
    index += 1
  }
  index
}

///|
fn pdf_tweak_split_chain(bytes : BytesView, start : Int) -> Array[PdfName] {
  let output : Array[PdfName] = []
  let mut index = start
  while index < bytes.length() {
    if bytes[index].to_int() == 47 {
      let segment_start = index
      index += 1
      while index < bytes.length() && bytes[index].to_int() != 47 {
        index += 1
      }
      output.push(pdf_name_of_bytes(bytes[segment_start:index].to_owned()))
    } else {
      index = bytes.length()
    }
  }
  output
}

///|
fn PdfDocument::pdf_tweak_find_chained_object(
  self : PdfDocument,
  start : PdfObject,
  chain : ArrayView[PdfName],
  source : String,
) -> PdfObject raise PdfError {
  match self.lookup_chain(start, chain) {
    Some(object) => object
    None => raise BadPageSpecification(source)
  }
}

///|
fn PdfDocument::pdf_tweak_find_numbered_object(
  self : PdfDocument,
  number : Int,
  chain : ArrayView[PdfName],
  source : String,
) -> PdfObject raise PdfError {
  let object = if number == 0 {
    self.trailer_dict()
  } else {
    self.lookup_object_or_null(number)
  }
  self.pdf_tweak_find_chained_object(object, chain, source)
}

///|
fn pdf_tweak_replace_array_entry(
  values : ArrayView[PdfObject],
  index : Int,
  value : PdfObject,
  source : String,
) -> PdfObject raise PdfError {
  if index < 0 || index >= values.length() {
    raise BadPageSpecification(source)
  }
  PdfArray(
    [
      for i in 0..<values.length() => if i == index { value } else { values[i] }
    ],
  )
}

///|
fn pdf_tweak_chain_array_index(name : PdfName) -> Int? {
  let bytes = name.bytes()
  guard bytes.length() >= 3 &&
    bytes[0].to_int() == 47 &&
    bytes[1].to_int() == 91 else {
    return None
  }
  guard pdf_tweak_is_digit_byte(bytes[2]) else { return None }
  let mut value = 0
  let mut index = 2
  while index < bytes.length() && pdf_tweak_is_digit_byte(bytes[index]) {
    value = value * 10 + bytes[index].to_int() - 48
    index += 1
  }
  Some(value)
}

///|
fn PdfDocument::pdf_tweak_replace_existing_chain(
  self : PdfDocument,
  object : PdfObject,
  chain : ArrayView[PdfName],
  chain_index : Int,
  value : PdfObject,
  source : String,
) -> PdfObject raise PdfError {
  let key = chain[chain_index]
  let final_key = chain_index + 1 == chain.length()
  match object {
    PdfDictionary(_) | PdfStreamObject(_) =>
      if final_key {
        match object.lookup_immediate(key) {
          Some(_) => object.replace_dict_entry(key, value)
          None => raise BadPageSpecification(source)
        }
      } else {
        match object.lookup_immediate(key) {
          Some(PdfIndirect(number)) => {
            let updated = self.pdf_tweak_replace_existing_chain(
              self.lookup_object_or_null(number),
              chain,
              chain_index + 1,
              value,
              source,
            )
            self.add_object_given_number(number, updated)
            object
          }
          Some(child) => {
            let updated = self.pdf_tweak_replace_existing_chain(
              child,
              chain,
              chain_index + 1,
              value,
              source,
            )
            object.replace_dict_entry(key, updated)
          }
          None => raise BadPageSpecification(source)
        }
      }
    PdfArray(values) =>
      match pdf_tweak_chain_array_index(key) {
        Some(index) =>
          if final_key {
            pdf_tweak_replace_array_entry(values, index, value, source)
          } else {
            match values.get(index) {
              Some(PdfIndirect(number)) => {
                let updated = self.pdf_tweak_replace_existing_chain(
                  self.lookup_object_or_null(number),
                  chain,
                  chain_index + 1,
                  value,
                  source,
                )
                self.add_object_given_number(number, updated)
                object
              }
              Some(child) => {
                let updated = self.pdf_tweak_replace_existing_chain(
                  child,
                  chain,
                  chain_index + 1,
                  value,
                  source,
                )
                pdf_tweak_replace_array_entry(values, index, updated, source)
              }
              None => raise BadPageSpecification(source)
            }
          }
        None => raise BadPageSpecification(source)
      }
    _ => raise BadPageSpecification(source)
  }
}

///|
fn PdfDocument::pdf_tweak_replace_numbered_object(
  self : PdfDocument,
  number : Int,
  chain : ArrayView[PdfName],
  value : PdfObject,
  source : String,
) -> Unit raise PdfError {
  if chain.length() == 0 {
    if number == 0 {
      self.set_trailer_dict(value)
    } else {
      self.add_object_given_number(number, value)
    }
  } else {
    let object = if number == 0 {
      self.trailer_dict()
    } else {
      self.lookup_object_or_null(number)
    }
    let updated = self.pdf_tweak_replace_existing_chain(
      object, chain, 0, value, source,
    )
    if number == 0 {
      self.set_trailer_dict(updated)
    } else {
      self.add_object_given_number(number, updated)
    }
  }
}

///|
fn pdf_tweak_number_spec(spec : String) -> Int raise PdfError {
  let bytes = @ascii.encode(spec)
  if bytes.length() == 0 {
    raise BadPageSpecification(spec)
  }
  let digit_end = pdf_tweak_digit_end(bytes, 0)
  if digit_end != bytes.length() {
    raise BadPageSpecification(spec)
  }
  pdf_tweak_parse_digits(bytes, 0, digit_end, spec)
}

///|
fn pdf_tweak_black_text_text_op(op : PdfContentOp) -> Bool {
  match op {
    Op_Tj(_)
    | Op_TJ(_)
    | Op_quote(_)
    | Op_double_quote(_, _, _)
    | Op_Td(_, _)
    | Op_TD(_, _)
    | Op_Tm(_)
    | Op_Tstar
    | Op_Tc(_)
    | Op_Tw(_)
    | Op_Tz(_)
    | Op_TL(_)
    | Op_Tf(_, _)
    | Op_Tr(_)
    | Op_Ts(_) => true
    _ => false
  }
}

///|
fn pdf_tweak_black_text_colour_op(op : PdfContentOp) -> Bool {
  match op {
    Op_G(_)
    | Op_g(_)
    | Op_RG(_, _, _)
    | Op_rg(_, _, _)
    | Op_K(_, _, _, _)
    | Op_k(_, _, _, _)
    | Op_SC(_)
    | Op_sc(_)
    | Op_SCN(_)
    | Op_scn(_)
    | Op_SCNName(_, _)
    | Op_scnName(_, _)
    | Op_CS(_)
    | Op_cs(_)
    | Op_sh(_)
    | Op_gs(_) => true
    _ => false
  }
}

///|
fn pdf_tweak_black_stroke_op(op : PdfContentOp) -> Bool {
  match op {
    Op_SC(_)
    | Op_SCN(_)
    | Op_SCNName(_, _)
    | Op_G(_)
    | Op_RG(_, _, _)
    | Op_K(_, _, _, _) => true
    _ => false
  }
}

///|
fn pdf_tweak_black_fill_op(op : PdfContentOp) -> Bool {
  match op {
    Op_sc(_)
    | Op_scn(_)
    | Op_scnName(_, _)
    | Op_g(_)
    | Op_rg(_, _, _)
    | Op_k(_, _, _, _) => true
    _ => false
  }
}

///|
/// Rewrite text content so text is painted with `colour`.
///
/// Colour and graphics-state operators inside text blocks are moved after the
/// text block, while non-text drawing operators inside the text block are
/// copied after `ET`, matching `cpdftweak.ml`'s `blacktext_ops`.
pub fn pdf_black_text_ops(
  colour : PdfContentColour,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  let removed : Array[PdfContentOp] = []
  let mut text_level = 0
  for op in ops {
    match op {
      Op_BT => {
        text_level += 1
        output.push(op)
        output.push(colour.pdf_tweak_fill_op())
      }
      Op_ET => {
        text_level -= 1
        output.push(op)
        for removed_op in removed {
          output.push(removed_op)
        }
        removed.clear()
      }
      _ =>
        if text_level > 0 && pdf_tweak_black_text_colour_op(op) {
          removed.push(op)
        } else {
          if text_level > 0 && !pdf_tweak_black_text_text_op(op) {
            removed.push(op)
          }
          output.push(op)
        }
    }
  }
  output
}

///|
/// Rewrite stroke colour operators to `colour`.
pub fn pdf_black_lines_ops(
  colour : PdfContentColour,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in ops {
    match op {
      Op_CS(_) => output.push(Op_CS(pdf_tweak_device_rgb_key()))
      _ if pdf_tweak_black_stroke_op(op) =>
        output.push(colour.pdf_tweak_stroke_op())
      _ => output.push(op)
    }
  }
  output
}

///|
/// Rewrite fill colour operators to `colour`.
pub fn pdf_black_fills_ops(
  colour : PdfContentColour,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in ops {
    match op {
      Op_cs(_) => output.push(Op_cs(pdf_tweak_device_rgb_key()))
      _ if pdf_tweak_black_fill_op(op) =>
        output.push(colour.pdf_tweak_fill_op())
      _ => output.push(op)
    }
  }
  output
}

///|
fn PdfDocument::pdf_tweak_black_text_page(
  self : PdfDocument,
  page : PdfPage,
  colour : PdfContentColour,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [pdf_content_stream_of_ops(pdf_black_text_ops(colour, ops))],
  }
}

///|
fn pdf_tweak_black_text_xobject(
  colour : PdfContentColour,
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_black_text_ops(colour, ops))]
}

///|
fn PdfDocument::pdf_tweak_black_lines_page(
  self : PdfDocument,
  page : PdfPage,
  colour : PdfContentColour,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [pdf_content_stream_of_ops(pdf_black_lines_ops(colour, ops))],
  }
}

///|
fn pdf_tweak_black_lines_xobject(
  colour : PdfContentColour,
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_black_lines_ops(colour, ops))]
}

///|
fn PdfDocument::pdf_tweak_black_fills_page(
  self : PdfDocument,
  page : PdfPage,
  colour : PdfContentColour,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [pdf_content_stream_of_ops(pdf_black_fills_ops(colour, ops))],
  }
}

///|
fn pdf_tweak_black_fills_xobject(
  colour : PdfContentColour,
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_black_fills_ops(colour, ops))]
}

///|
/// Paint text on selected one-based pages and Form XObjects with `colour`.
pub fn PdfDocument::black_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : PdfContentColour,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      document.process_xobjects(page, fn(
        doc,
        resources,
        streams,
      ) raise PdfError {
        pdf_tweak_black_text_xobject(colour, doc, resources, streams)
      })
      rewritten.push(document.pdf_tweak_black_text_page(page, colour))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::black_text`.
pub fn pdf_black_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : PdfContentColour,
) -> PdfDocument raise PdfError {
  document.black_text(page_numbers, colour)
}

///|
/// Compatibility wrapper matching cpdftweak's `blacktext` name and order.
pub fn pdf_blacktext(
  colour : PdfContentColour,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.black_text(page_numbers, colour)
}

///|
/// Paint line strokes on selected one-based pages and Form XObjects with `colour`.
pub fn PdfDocument::black_lines(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : PdfContentColour,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      document.process_xobjects(page, fn(
        doc,
        resources,
        streams,
      ) raise PdfError {
        pdf_tweak_black_lines_xobject(colour, doc, resources, streams)
      })
      rewritten.push(document.pdf_tweak_black_lines_page(page, colour))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::black_lines`.
pub fn pdf_black_lines(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : PdfContentColour,
) -> PdfDocument raise PdfError {
  document.black_lines(page_numbers, colour)
}

///|
/// Compatibility wrapper matching cpdftweak's `blacklines` name and order.
pub fn pdf_blacklines(
  colour : PdfContentColour,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.black_lines(page_numbers, colour)
}

///|
/// Paint fills on selected one-based pages and Form XObjects with `colour`.
pub fn PdfDocument::black_fills(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : PdfContentColour,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      document.process_xobjects(page, fn(
        doc,
        resources,
        streams,
      ) raise PdfError {
        pdf_tweak_black_fills_xobject(colour, doc, resources, streams)
      })
      rewritten.push(document.pdf_tweak_black_fills_page(page, colour))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::black_fills`.
pub fn pdf_black_fills(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : PdfContentColour,
) -> PdfDocument raise PdfError {
  document.black_fills(page_numbers, colour)
}

///|
/// Compatibility wrapper matching cpdftweak's `blackfills` name and order.
pub fn pdf_blackfills(
  colour : PdfContentColour,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.black_fills(page_numbers, colour)
}

///|
/// Remove text rendering-mode operators so hidden text is rendered normally.
pub fn pdf_reveal_hidden_text_ops(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in ops {
    match op {
      Op_Tr(_) => ()
      _ => output.push(op)
    }
  }
  output
}

///|
fn PdfDocument::pdf_tweak_reveal_hidden_text_page(
  self : PdfDocument,
  page : PdfPage,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [pdf_content_stream_of_ops(pdf_reveal_hidden_text_ops(ops))],
  }
}

///|
fn pdf_tweak_reveal_hidden_text_xobject(
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_reveal_hidden_text_ops(ops))]
}

///|
/// Reveal hidden text on selected one-based pages and their Form XObjects.
///
/// This ports the `cpdftweak.ml` reveal-hidden-text behavior by removing all
/// `Tr` text rendering-mode operators from selected content streams.
pub fn PdfDocument::reveal_hidden_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      document.process_xobjects(page, pdf_tweak_reveal_hidden_text_xobject)
      rewritten.push(document.pdf_tweak_reveal_hidden_text_page(page))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::reveal_hidden_text`.
pub fn pdf_reveal_hidden_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.reveal_hidden_text(page_numbers)
}

///|
/// Compatibility wrapper matching cpdftweak's `reveal_hidden_text` argument order.
pub fn pdf_reveal_hidden_text_cpdf_order(
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.reveal_hidden_text(page_numbers)
}

///|
/// Remove clipping-path setup sequences from parsed content operators.
///
/// This ports `cpdftweak.ml`'s `remove_clipping_ops`: only the exact `W n`
/// sequence is rewritten, becoming just `n`.
pub fn pdf_remove_clipping_ops(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  let mut index = 0
  while index < ops.length() {
    if index + 1 < ops.length() && ops[index] == Op_W && ops[index + 1] == Op_n {
      output.push(Op_n)
      index += 2
    } else {
      output.push(ops[index])
      index += 1
    }
  }
  output
}

///|
fn PdfDocument::pdf_tweak_remove_clipping_page(
  self : PdfDocument,
  page : PdfPage,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  { ..page, content: [pdf_content_stream_of_ops(pdf_remove_clipping_ops(ops))] }
}

///|
fn pdf_tweak_remove_clipping_xobject(
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_remove_clipping_ops(ops))]
}

///|
/// Remove clipping paths from selected one-based pages and their Form XObjects.
pub fn PdfDocument::remove_clipping(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      document.process_xobjects(page, pdf_tweak_remove_clipping_xobject)
      rewritten.push(document.pdf_tweak_remove_clipping_page(page))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::remove_clipping`.
pub fn pdf_remove_clipping(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.remove_clipping(page_numbers)
}

///|
/// Append or prepend parsed content bytes to selected one-based pages.
///
/// `content` is byte-oriented PDF content syntax, matching the OCaml source's
/// `string` payload. Empty content is a no-op.
pub fn PdfDocument::append_page_content(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  content : BytesView,
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      rewritten.push(
        document.pdf_tweak_append_page_content_page(page, content, before, fast),
      )
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::append_page_content`.
pub fn pdf_append_page_content(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  content : BytesView,
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.append_page_content(page_numbers, content, before~, fast~)
}

///|
/// Compatibility wrapper matching cpdftweak's `append_page_content` argument order.
pub fn pdf_append_page_content_cpdf_order(
  content : BytesView,
  before : Bool,
  fast : Bool,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.append_page_content(page_numbers, content, before~, fast~)
}

///|
/// Append or prepend content operators to selected one-based pages.
pub fn PdfDocument::append_page_content_ops(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  ops : ArrayView[PdfContentOp],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      rewritten.push(
        document.pdf_tweak_append_page_content_ops_page(page, ops, before, fast),
      )
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::append_page_content_ops`.
pub fn pdf_append_page_content_ops(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  ops : ArrayView[PdfContentOp],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.append_page_content_ops(page_numbers, ops, before~, fast~)
}

///|
/// Append or prepend one content byte payload per page.
///
/// The payload list must match the current page count. Empty per-page payloads
/// leave that page unchanged.
pub fn PdfDocument::append_page_content_multiple(
  self : PdfDocument,
  contents : ArrayView[Bytes],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  pdf_tweak_validate_page_count(contents.length(), pages.length())
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    rewritten.push(
      document.pdf_tweak_append_page_content_page(
        pages[index],
        contents[index],
        before,
        fast,
      ),
    )
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::append_page_content_multiple`.
pub fn pdf_append_page_content_multiple(
  document : PdfDocument,
  contents : ArrayView[Bytes],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.append_page_content_multiple(contents, before~, fast~)
}

///|
/// Compatibility wrapper matching cpdftweak's `append_page_content_multiple`
/// argument order.
pub fn pdf_append_page_content_multiple_cpdf_order(
  contents : ArrayView[Bytes],
  before : Bool,
  fast : Bool,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.append_page_content_multiple(contents, before~, fast~)
}

///|
/// Append or prepend one content operator list per page.
pub fn PdfDocument::append_page_content_multiple_ops(
  self : PdfDocument,
  op_lists : ArrayView[Array[PdfContentOp]],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  pdf_tweak_validate_page_count(op_lists.length(), pages.length())
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    rewritten.push(
      document.pdf_tweak_append_page_content_ops_page(
        pages[index],
        op_lists[index],
        before,
        fast,
      ),
    )
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::append_page_content_multiple_ops`.
pub fn pdf_append_page_content_multiple_ops(
  document : PdfDocument,
  op_lists : ArrayView[Array[PdfContentOp]],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.append_page_content_multiple_ops(op_lists, before~, fast~)
}

///|
/// Compatibility wrapper matching cpdftweak's `append_page_content_multiple_ops`
/// argument order.
pub fn pdf_append_page_content_multiple_ops_cpdf_order(
  op_lists : ArrayView[Array[PdfContentOp]],
  before : Bool,
  fast : Bool,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.append_page_content_multiple_ops(op_lists, before~, fast~)
}

///|
/// Find an object using cpdf's object-spec grammar.
///
/// `""` selects the trailer dictionary, `/A/B` follows a trailer-rooted chain,
/// `4/A` follows a chain from object 4, and `P1/A` follows a chain from the
/// first page object.
pub fn PdfDocument::find_object_by_spec(
  self : PdfDocument,
  spec : String,
) -> PdfObject raise PdfError {
  let bytes = @ascii.encode(spec)
  if bytes.length() == 0 {
    self.trailer_dict()
  } else if bytes[0].to_int() == 80 {
    let digit_end = pdf_tweak_digit_end(bytes, 1)
    let page_number = pdf_tweak_parse_digits(bytes, 1, digit_end, spec)
    let page_refs = self.page_reference_numbers()
    if page_number < 1 || page_number > page_refs.length() {
      raise BadPageSpecification(spec)
    }
    let chain = pdf_tweak_split_chain(bytes, digit_end)
    self.pdf_tweak_find_numbered_object(page_refs[page_number - 1], chain, spec)
  } else if bytes[0].to_int() == 47 {
    let chain = pdf_tweak_split_chain(bytes, 0)
    self.pdf_tweak_find_chained_object(self.trailer_dict(), chain, spec)
  } else {
    let digit_end = pdf_tweak_digit_end(bytes, 0)
    let object_number = pdf_tweak_parse_digits(bytes, 0, digit_end, spec)
    let chain = pdf_tweak_split_chain(bytes, digit_end)
    self.pdf_tweak_find_numbered_object(object_number, chain, spec)
  }
}

///|
/// Compatibility wrapper for `PdfDocument::find_object_by_spec`.
pub fn pdf_find_object(
  document : PdfDocument,
  spec : String,
) -> PdfObject raise PdfError {
  document.find_object_by_spec(spec)
}

///|
/// Compatibility wrapper matching cpdftweak's `find_obj` name.
pub fn pdf_find_obj(
  document : PdfDocument,
  spec : String,
) -> PdfObject raise PdfError {
  document.find_object_by_spec(spec)
}

///|
/// Replace an object using the cpdf object-spec grammar.
pub fn PdfDocument::replace_object_by_spec(
  self : PdfDocument,
  spec : String,
  value : PdfObject,
) -> Unit raise PdfError {
  let bytes = @ascii.encode(spec)
  if bytes.length() == 0 {
    self.set_trailer_dict(value)
  } else if bytes[0].to_int() == 80 {
    let digit_end = pdf_tweak_digit_end(bytes, 1)
    let page_number = pdf_tweak_parse_digits(bytes, 1, digit_end, spec)
    let page_refs = self.page_reference_numbers()
    if page_number < 1 || page_number > page_refs.length() {
      raise BadPageSpecification(spec)
    }
    let chain = pdf_tweak_split_chain(bytes, digit_end)
    self.pdf_tweak_replace_numbered_object(
      page_refs[page_number - 1],
      chain,
      value,
      spec,
    )
  } else if bytes[0].to_int() == 47 {
    let chain = pdf_tweak_split_chain(bytes, 0)
    self.pdf_tweak_replace_numbered_object(0, chain, value, spec)
  } else {
    let digit_end = pdf_tweak_digit_end(bytes, 0)
    let object_number = pdf_tweak_parse_digits(bytes, 0, digit_end, spec)
    let chain = pdf_tweak_split_chain(bytes, digit_end)
    self.pdf_tweak_replace_numbered_object(object_number, chain, value, spec)
  }
}

///|
/// Compatibility wrapper for `PdfDocument::replace_object_by_spec`.
pub fn pdf_replace_object_by_spec(
  document : PdfDocument,
  spec : String,
  value : PdfObject,
) -> Unit raise PdfError {
  document.replace_object_by_spec(spec, value)
}

///|
/// Compatibility wrapper matching cpdftweak's `replace_obj` name.
pub fn pdf_replace_obj(
  document : PdfDocument,
  spec : String,
  value : PdfObject,
) -> Unit raise PdfError {
  document.replace_object_by_spec(spec, value)
}

///|
/// Remove an object by decimal object number string.
pub fn PdfDocument::remove_object_by_spec(
  self : PdfDocument,
  spec : String,
) -> Unit raise PdfError {
  self.remove_object(pdf_tweak_number_spec(spec))
}

///|
/// Compatibility wrapper for `PdfDocument::remove_object_by_spec`.
pub fn pdf_remove_object_by_spec(
  document : PdfDocument,
  spec : String,
) -> Unit raise PdfError {
  document.remove_object_by_spec(spec)
}

///|
/// Compatibility wrapper matching cpdftweak's `remove_obj` name.
pub fn pdf_remove_obj(
  document : PdfDocument,
  spec : String,
) -> Unit raise PdfError {
  document.remove_object_by_spec(spec)
}

///|
/// Replace a stream's bytes while preserving its dictionary except `/Length`.
pub fn PdfDocument::replace_stream_by_spec(
  self : PdfDocument,
  spec : String,
  data : BytesView,
) -> Unit raise PdfError {
  match self.find_object_by_spec(spec) {
    PdfStreamObject(stream) => {
      let data = data.to_owned()
      let dictionary = stream.dictionary.add_dict_entry(
        pdf_tweak_length_key(),
        PdfInteger(data.length()),
      )
      self.replace_object_by_spec(
        spec,
        PdfStreamObject({ dictionary, data: StreamGot(data) }),
      )
    }
    _ => raise ParseStreamExpected
  }
}

///|
/// Compatibility wrapper for `PdfDocument::replace_stream_by_spec`.
pub fn pdf_replace_stream_by_spec(
  document : PdfDocument,
  spec : String,
  data : BytesView,
) -> Unit raise PdfError {
  document.replace_stream_by_spec(spec, data)
}

///|
/// Rewrite line widths to honor the cpdf thin-lines threshold.
///
/// Positive `width` is a minimum width. Negative `width` uses its absolute
/// value as a maximum width, matching `cpdftweak.ml`.
pub fn pdf_thin_lines_ops(
  document : PdfDocument,
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
  width : Double,
) -> Array[PdfContentOp] raise PdfError {
  let limit = if width < 0.0 { -width } else { width }
  let is_minimum = width >= 0.0
  let ctm_stack : Array[TransformMatrix] = [transform_identity_matrix]
  let output : Array[PdfContentOp] = []
  for op in ops {
    match op {
      Op_w(line_width) => {
        let adjusted_limit = limit / pdf_tweak_ctm_scale(ctm_stack)
        let keep = if is_minimum {
          line_width >= adjusted_limit
        } else {
          line_width <= adjusted_limit
        }
        if keep {
          output.push(op)
        } else {
          output.push(Op_w(adjusted_limit))
        }
      }
      Op_cm(matrix) => {
        if ctm_stack.length() == 0 {
          raise MatrixMalformed
        }
        let index = ctm_stack.length() - 1
        ctm_stack[index] = transform_matrix_compose(ctm_stack[index], matrix)
        output.push(op)
      }
      Op_q => {
        if ctm_stack.length() == 0 {
          raise MatrixMalformed
        }
        ctm_stack.push(ctm_stack[ctm_stack.length() - 1])
        output.push(op)
      }
      Op_Q => {
        if ctm_stack.length() == 0 {
          raise MatrixMalformed
        }
        ignore(ctm_stack.pop())
        output.push(op)
      }
      Op_gs(name) => {
        output.push(op)
        match pdf_tweak_extgstate_line_width(document, resources, name) {
          Some(line_width) => output.push(Op_w(line_width))
          None => ()
        }
      }
      _ => output.push(op)
    }
  }
  if limit > 1.0 || limit < 1.0 {
    output.insert(0, Op_w(limit))
  }
  output
}

///|
fn PdfDocument::pdf_tweak_thin_lines_page(
  self : PdfDocument,
  page : PdfPage,
  width : Double,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [
      pdf_content_stream_of_ops(
        pdf_thin_lines_ops(self, page.resources, ops, width),
      ),
    ],
  }
}

///|
/// Set a minimum line width on selected one-based pages.
///
/// Passing a negative `width` sets the corresponding maximum line width, as in
/// cpdf's `thinlines` implementation.
pub fn PdfDocument::thin_lines(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  width : Double,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      rewritten.push(document.pdf_tweak_thin_lines_page(page, width))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::thin_lines`.
pub fn pdf_thin_lines(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  width : Double,
) -> PdfDocument raise PdfError {
  document.thin_lines(page_numbers, width)
}

///|
/// Compatibility wrapper matching cpdftweak's `thinlines` name and order.
pub fn pdf_thinlines(
  page_numbers : ArrayView[Int],
  width : Double,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.thin_lines(page_numbers, width)
}
