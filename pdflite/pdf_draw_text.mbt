///|
fn PdfDrawRenderState::text_ops(
  self : PdfDrawRenderState,
  text : String,
) -> Array[@content.PdfContentOp] raise @core.PdfError {
  let width_cache = pdf_draw_font_width_cache_new(self.font_size)
  let (ops, _) = self.text_ops_and_width_with_cache(text, width_cache)
  ops
}

///|
priv struct PdfDrawFontWidthCache {
  font_size : Double
  entries : Array[(Int, Array[Double])]
}

///|
fn pdf_draw_font_width_cache_new(font_size : Double) -> PdfDrawFontWidthCache {
  { font_size, entries: [] }
}

///|
fn PdfDrawFontWidthCache::widths(
  self : PdfDrawFontWidthCache,
  font_index : Int,
  font : PdfFont,
) -> Array[Double] raise @core.PdfError {
  for entry in self.entries {
    if entry.0 == font_index {
      return entry.1
    }
  }
  let widths = pdf_type_font_widths(font, self.font_size)
  self.entries.push((font_index, widths))
  widths
}

///|
fn PdfDrawRenderState::text_ops_and_width_with_cache(
  self : PdfDrawRenderState,
  text : String,
  width_cache : PdfDrawFontWidthCache,
) -> (Array[@content.PdfContentOp], Double) raise @core.PdfError {
  if self.current_fontpack_identifier == "" {
    raise SoftError("FontPack not selected")
  }
  let codepoints = pdf_codepoints_of_utf8(@utf8.encode(text))
  let triples : Array[(Int, Int, PdfFont)] = Array::new(
    capacity=codepoints.length(),
  )
  let mut width = 0.0
  for codepoint in codepoints {
    match self.current_fontpack.get_char(codepoint) {
      Some((charcode, font_index, font)) => {
        let widths = width_cache.widths(font_index, font)
        if charcode < 0 || charcode >= widths.length() {
          raise FontWidthExpected
        }
        width += widths[charcode]
        triples.push((charcode, font_index, font))
      }
      None => ()
    }
  }
  let output : Array[@content.PdfContentOp] = Array::new(
    capacity=triples.length() * 2,
  )
  for run in pdf_fontpack_collate_runs(triples) {
    guard run.length() > 0 else { continue }
    let font_index = run[0].1
    let resource_name = self.font_resource_name(
      self.current_fontpack_identifier,
      font_index,
    )
    let bytes = Array::make(run.length(), b'\x00')
    for index, triple in run {
      bytes[index] = @core.pdf_byte_of_int(triple.0)
    }
    output.push(Op_Tf(resource_name, self.font_size))
    output.push(Op_Tj(Bytes::from_array(bytes)))
  }
  (output, width)
}

///|
fn pdf_draw_decode_lossy_view(bytes : BytesView) -> String {
  let output = Array::make(bytes.length(), b'\x00')
  for index, byte in bytes {
    output[index] = byte
  }
  @utf8.decode_lossy(Bytes::from_array(output))
}

///|
fn pdf_draw_split_on_space(text : String) -> Array[String] {
  let bytes = @utf8.encode(text)
  let parts : Array[String] = Array::new(capacity=bytes.length())
  let mut part_start = 0
  let mut index = 0
  while index < bytes.length() {
    if bytes[index] == b' ' {
      parts.push(pdf_draw_decode_lossy_view(bytes[part_start:index]))
      index += 1
      part_start = index
    } else {
      index += 1
    }
  }
  parts.push(pdf_draw_decode_lossy_view(bytes[part_start:]))
  parts
}

///|
fn pdf_draw_remove_duplicate_tfs(
  ops : ArrayView[@content.PdfContentOp],
) -> Array[@content.PdfContentOp] {
  let output : Array[@content.PdfContentOp] = Array::new(capacity=ops.length())
  let mut previous : @core.PdfName? = None
  for op in ops {
    match op {
      Op_Tf(font, _) =>
        match previous {
          Some(seen) if seen == font => ()
          _ => {
            output.push(op)
            previous = Some(font)
          }
        }
      _ => output.push(op)
    }
  }
  output
}

///|
fn pdf_draw_merge_adjacent_tjs(
  ops : ArrayView[@content.PdfContentOp],
) -> Array[@content.PdfContentOp] {
  let output : Array[@content.PdfContentOp] = Array::new(capacity=ops.length())
  let mut index = 0
  while index < ops.length() {
    match ops[index] {
      Op_Tj(_) => {
        let run_start = index
        let mut total_length = 0
        while index < ops.length() {
          match ops[index] {
            Op_Tj(text) => {
              total_length += text.length()
              index += 1
            }
            _ => break
          }
        }
        let bytes = Array::make(total_length, b'\x00')
        let mut position = 0
        for op_index in run_start..<index {
          match ops[op_index] {
            Op_Tj(text) =>
              for byte in text {
                bytes[position] = byte
                position += 1
              }
            _ => ()
          }
        }
        output.push(Op_Tj(Bytes::from_array(bytes)))
      }
      _ => {
        output.push(ops[index])
        index += 1
      }
    }
  }
  output
}

///|
fn pdf_draw_clean_up_text_ops(
  ops : ArrayView[@content.PdfContentOp],
) -> Array[@content.PdfContentOp] {
  pdf_draw_merge_adjacent_tjs(pdf_draw_remove_duplicate_tfs(ops))
}

///|
fn PdfDrawRenderState::justify_paragraph_line(
  self : PdfDrawRenderState,
  ops : ArrayView[@content.PdfContentOp],
  first_line : Bool,
  indent : Double,
  justification : PdfDrawJustification,
  remaining : Double,
) -> Array[@content.PdfContentOp] {
  ignore(self)
  let output : Array[@content.PdfContentOp] = Array::new(
    capacity=ops.length() + 2,
  )
  match justification {
    PdfDrawLeft => {
      if first_line {
        output.push(Op_Td(-indent, 0.0))
      }
      output.append(ops)
      if first_line {
        output.push(Op_Td(indent, 0.0))
      }
    }
    PdfDrawRight => {
      output.push(Op_Td(-remaining, 0.0))
      output.append(ops)
      output.push(Op_Td(remaining, 0.0))
    }
    PdfDrawCentre => {
      output.push(Op_Td(-remaining / 2.0, 0.0))
      output.append(ops)
      output.push(Op_Td(remaining / 2.0, 0.0))
    }
  }
  output
}

///|
fn PdfDrawRenderState::format_paragraph(
  self : PdfDrawRenderState,
  indent : Double,
  justification : PdfDrawJustification,
  width : Double,
  text : String,
) -> Array[@content.PdfContentOp] raise @core.PdfError {
  let width_cache = pdf_draw_font_width_cache_new(self.font_size)
  let split_words = pdf_draw_split_on_space(text)
  let words : Array[(Array[@content.PdfContentOp], Double)] = Array::new(
    capacity=split_words.length(),
  )
  for word in split_words {
    words.push(self.text_ops_and_width_with_cache(word, width_cache))
  }
  let (space_ops, space_width) = self.text_ops_and_width_with_cache(
    " ", width_cache,
  )
  let output : Array[@content.PdfContentOp] = Array::new(
    capacity=words.length() * 2,
  )
  let mut line_ops : Array[@content.PdfContentOp] = Array::new(
    capacity=words.length() * 2,
  )
  let mut remaining = width
  let mut first_line = true
  let mut first_loop = true
  let mut index = 0
  while index < words.length() {
    if first_loop {
      remaining -= indent
      first_loop = false
    }
    let (word_ops, word_width) = words[index]
    if remaining == width {
      line_ops.append(word_ops)
      remaining -= word_width
      index += 1
    } else if word_width + space_width <= remaining {
      line_ops.append(space_ops)
      line_ops.append(word_ops)
      remaining -= word_width + space_width
      index += 1
    } else {
      output.push(Op_Tstar)
      output.append(
        self.justify_paragraph_line(
          line_ops, first_line, indent, justification, remaining,
        ),
      )
      first_line = false
      line_ops = []
      remaining = width
    }
  }
  output.push(Op_Tstar)
  output.append(
    self.justify_paragraph_line(
      line_ops, first_line, indent, justification, remaining,
    ),
  )
  pdf_draw_clean_up_text_ops(output)
}

///|
fn PdfDrawRenderState::paragraph_ops(
  self : PdfDrawRenderState,
  indent : Double?,
  justification : PdfDrawJustification,
  width : Double,
  paragraphs : ArrayView[String],
) -> Array[@content.PdfContentOp] raise @core.PdfError {
  let output : Array[@content.PdfContentOp] = Array::new(
    capacity=paragraphs.length(),
  )
  let mut first = true
  for paragraph in paragraphs {
    if !first {
      match indent {
        None => output.push(Op_Tstar)
        Some(_) => ()
      }
    }
    let paragraph_indent = match indent {
      Some(value) if !first => value
      _ => 0.0
    }
    let paragraph_ops = self.format_paragraph(
      paragraph_indent, justification, width, paragraph,
    )
    if self.structure_tree_enabled && self.auto_tag {
      output.append(self.structure_tagged_ops("/P", paragraph_ops))
    } else {
      output.append(paragraph_ops)
    }
    first = false
  }
  output
}
