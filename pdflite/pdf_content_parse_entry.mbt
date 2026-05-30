///|
/// Decode and parse a list of content stream objects from this document.
///
/// Each input must resolve to a stream object. Stream filters are decoded before
/// parsing, then the decoded streams are concatenated with whitespace. Use
/// `parse_content_ops_with_resources` when inline-image length inference needs
/// page resources.
pub fn PdfDocument::parse_content_ops(
  self : PdfDocument,
  streams : ArrayView[@syntax.PdfObject],
) -> Array[@content.PdfContentOp] raise @core.PdfError {
  let raw_streams = self.pdf_content_raw_streams(streams)
  pdf_parse_content_ops_from_view(pdf_content_concat_streams(raw_streams))
}

///|
/// Decode and parse content stream objects with page resources.
///
/// The resource dictionary is used for inline-image color-space component
/// lookup when an unfiltered inline image has no reliable declared length.
pub fn PdfDocument::parse_content_ops_with_resources(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  streams : ArrayView[@syntax.PdfObject],
) -> Array[@content.PdfContentOp] raise @core.PdfError {
  let raw_streams = self.pdf_content_raw_streams(streams)
  pdf_parse_content_ops_from_view_with_context(
    pdf_content_concat_streams(raw_streams),
    pdf_content_parse_context(
      Some(fn(colour_space) raise @core.PdfError {
        self.colour_space_components(resources, colour_space)
      }),
    ),
  )
}

///|
/// Parse content bytes with page resources.
///
/// This is the owned-byte wrapper for `parse_content_view_with_resources`.
pub fn PdfDocument::parse_content_bytes_with_resources(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  data : @core.PdfBytes,
) -> Array[@content.PdfContentOp] raise @core.PdfError {
  self.parse_content_view_with_resources(resources, data)
}

///|
/// Parse a content byte view with page resources.
///
/// The input view is read directly; returned operators own any byte data they
/// need to keep, such as text strings and inline-image data.
pub fn PdfDocument::parse_content_view_with_resources(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  data : BytesView,
) -> Array[@content.PdfContentOp] raise @core.PdfError {
  pdf_parse_content_ops_from_view_with_context(
    data,
    pdf_content_parse_context(
      Some(fn(colour_space) raise @core.PdfError {
        self.colour_space_components(resources, colour_space)
      }),
    ),
  )
}

///|
fn PdfDocument::pdf_content_raw_streams(
  self : PdfDocument,
  streams : ArrayView[@syntax.PdfObject],
) -> Array[@core.PdfBytes] raise @core.PdfError {
  let raw_streams : Array[@core.PdfBytes] = Array::new(
    capacity=streams.length(),
  )
  for stream_ref in streams {
    match self.direct(stream_ref) {
      PdfStreamObject(stream) =>
        raw_streams.push(
          @syntax.pdf_stream_data_bytes(
            self.pdf_decode_stream_value_direct(stream).data,
          ),
        )
      _ => raise ParseStreamExpected
    }
  }
  raw_streams
}

///|
fn pdf_content_read_complex_object(
  cursor : @core.ByteCursor,
  first : @syntax.PdfLexeme,
) -> @syntax.PdfObject raise @core.PdfError {
  let lexemes : Array[@syntax.PdfLexeme] = [first]
  let mut array_depth = 0
  let mut dict_depth = 0
  match first {
    LexLeftSquare => array_depth = 1
    LexLeftDict => dict_depth = 1
    _ => ()
  }
  while array_depth > 0 || dict_depth > 0 {
    let token = @syntax.pdf_cursor_lex_token(cursor)
    match token {
      StopLexing | LexNone => raise ParseObjectExpected
      LexLeftSquare => array_depth += 1
      LexRightSquare => array_depth -= 1
      LexLeftDict => dict_depth += 1
      LexRightDict => dict_depth -= 1
      _ => ()
    }
    lexemes.push(token)
  }
  @syntax.pdf_parse_single_lexeme_object(lexemes)
}

///|
fn pdf_content_read_object(
  cursor : @core.ByteCursor,
) -> @syntax.PdfObject raise @core.PdfError {
  let token = @syntax.pdf_cursor_lex_token(cursor)
  match token {
    StopLexing | LexNone => raise ParseObjectExpected
    LexLeftSquare | LexLeftDict =>
      pdf_content_read_complex_object(cursor, token)
    _ => @syntax.pdf_parse_single_lexeme_object([token])
  }
}

///|
fn pdf_content_operator_or_literal(view : BytesView) -> PdfContentLexeme {
  match view {
    [116, 114, 117, 101] => ContentOperand(PdfBoolean(true))
    [102, 97, 108, 115, 101] => ContentOperand(PdfBoolean(false))
    [110, 117, 108, 108] => ContentOperand(PdfNull)
    _ => ContentOperator(view)
  }
}

///|
fn pdf_content_lex_next(
  cursor : @core.ByteCursor,
) -> PdfContentLexeme raise @core.PdfError {
  @syntax.pdf_cursor_drop_whitespace(cursor)
  let value = cursor.peek_byte()
  match value {
    value if value == @core.pdf_no_more => ContentEnd
    37 => {
      ignore(@syntax.pdf_cursor_lex_comment(cursor))
      ContentComment
    }
    47 | 40 | 91 | 60 => ContentOperand(pdf_content_read_object(cursor))
    value if @syntax.pdf_is_number_start_byte(value) =>
      ContentOperand(pdf_content_read_object(cursor))
    116 | 102 | 110 =>
      pdf_content_operator_or_literal(
        @syntax.pdf_cursor_read_regular_token_view(cursor),
      )
    _ => ContentOperator(@syntax.pdf_cursor_read_regular_token_view(cursor))
  }
}
