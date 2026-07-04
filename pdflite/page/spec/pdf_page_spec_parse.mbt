///|
fn PdfPageSpecContext::parse_tokens(
  self : PdfPageSpecContext,
  tokens : ArrayView[PdfPageSpecToken],
) -> Array[Int] raise PdfError {
  if tokens.length() == 0 {
    self.bad()
  }
  let comma_count = pdf_pagespec_count_commas(tokens)
  if comma_count > 0 {
    let parts : Array[Array[Int]] = Array::new(capacity=comma_count + 1)
    for part in pdf_pagespec_split_commas(tokens, self, comma_count) {
      parts.push(self.parse_tokens(part))
    }
    pdf_pagespec_flatten(parts)
  } else if tokens.length() == 1 {
    match tokens[0] {
      PageSpecWord("all") => pdf_pagespec_all_pages(self.end_page)
      PageSpecWord("reverse") => pdf_pagespec_range(self.end_page, 1)
      PageSpecWord("empty") => []
      PageSpecWord("odd") =>
        pdf_pagespec_filter_odd(pdf_pagespec_all_pages(self.end_page))
      PageSpecWord("even") =>
        pdf_pagespec_filter_even(pdf_pagespec_all_pages(self.end_page))
      PageSpecWord("portrait") =>
        self.select_dimensions(pdf_pagespec_all_pages(self.end_page), true)
      PageSpecWord("landscape") =>
        self.select_dimensions(pdf_pagespec_all_pages(self.end_page), false)
      PageSpecWord("annotated") =>
        self.select_annotated(pdf_pagespec_all_pages(self.end_page))
      token =>
        match pdf_pagespec_token_number(self, token) {
          Some(page) => [page]
          None => {
            self.bad()
            []
          }
        }
    }
  } else if tokens.length() == 3 && tokens[1] is PageSpecDash {
    match
      (
        pdf_pagespec_token_number(self, tokens[0]),
        pdf_pagespec_token_number(self, tokens[2]),
      ) {
      (Some(start), Some(finish)) => pdf_pagespec_range(start, finish)
      _ => {
        self.bad()
        []
      }
    }
  } else {
    self.bad()
    []
  }
}

///|
fn pdf_pagespec_digit_dup_prefix(text : String) -> (Int, String)? {
  let bytes = @utf8.encode(text)
  let mut index = 0
  while index < bytes.length() && pdf_pagespec_is_digit(bytes[index].to_int()) {
    index += 1
  }
  if index > 0 &&
    index + 3 <= bytes.length() &&
    bytes[index].to_int() == 68 &&
    bytes[index + 1].to_int() == 85 &&
    bytes[index + 2].to_int() == 80 {
    let count_text = @ascii.decode_lossy(bytes[0:index])
    match pdf_pagespec_parse_nonnegative_int(count_text) {
      Some(count) =>
        Some((count, text.unsafe_substring(start=index + 3, end=text.length())))
      None => None
    }
  } else {
    None
  }
}

///|
fn PdfPageSpecContext::filter_valid_pages(
  self : PdfPageSpecContext,
  pages : ArrayView[Int],
) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=pages.length())
  for page in pages {
    if page > 0 && page <= self.end_page {
      output.push(page)
    }
  }
  output
}

///|
fn PdfPageSpecContext::parse_resolved_text(
  self : PdfPageSpecContext,
  text : String,
) -> Array[Int] raise PdfError {
  match pdf_pagespec_digit_dup_prefix(text) {
    Some((count, rest)) =>
      return pdf_pagespec_duplicate_range(count, self.parse_inner(rest))
    None => ()
  }
  if text.has_prefix("NOT") {
    return pdf_pagespec_invert_range(
      self.end_page,
      self.parse_inner(text.unsafe_substring(start=3, end=text.length())),
    )
  }
  if text == "odd" {
    return pdf_pagespec_filter_odd(pdf_pagespec_all_pages(self.end_page))
  }
  if text == "even" {
    return pdf_pagespec_filter_even(pdf_pagespec_all_pages(self.end_page))
  }
  if text == "portrait" {
    return self.select_dimensions(pdf_pagespec_all_pages(self.end_page), true)
  }
  if text == "landscape" {
    return self.select_dimensions(pdf_pagespec_all_pages(self.end_page), false)
  }
  if text == "annotated" {
    return self.select_annotated(pdf_pagespec_all_pages(self.end_page))
  }
  if text.has_suffix("odd") {
    return pdf_pagespec_filter_odd(
      self.parse_inner(text.unsafe_substring(start=0, end=text.length() - 3)),
    )
  }
  if text.has_suffix("even") {
    return pdf_pagespec_filter_even(
      self.parse_inner(text.unsafe_substring(start=0, end=text.length() - 4)),
    )
  }
  if text.has_suffix("portrait") {
    return self.select_dimensions(
      self.parse_inner(text.unsafe_substring(start=0, end=text.length() - 8)),
      true,
    )
  }
  if text.has_suffix("landscape") {
    return self.select_dimensions(
      self.parse_inner(text.unsafe_substring(start=0, end=text.length() - 9)),
      false,
    )
  }
  self.parse_tokens(pdf_pagespec_tokenize(text, self))
}

///|
fn PdfPageSpecContext::parse_inner(
  self : PdfPageSpecContext,
  spec : String,
) -> Array[Int] raise PdfError {
  let effective = if spec == "" { "all" } else { spec }
  let resolved = self.resolve_references(@utf8.encode(effective))
  let resolved_text = @ascii.decode_lossy(resolved)
  self.filter_valid_pages(self.parse_resolved_text(resolved_text))
}

///|
/// Parse a cpdf page specification with optional document-dependent selectors.
pub fn pdf_parse_pagespec_with_selectors(
  end_page : Int,
  spec : String,
  selectors : PdfPageSpecSelectors?,
) -> Array[Int] raise PdfError {
  if end_page < 1 {
    raise BadPageSpecification(spec)
  }
  { end_page, selectors, source: spec }.parse_inner(spec)
}

///|
/// Parse a cpdf page specification against a document with `end_page` pages.
pub fn pdf_parse_pagespec_for_count(
  end_page : Int,
  spec : String,
) -> Array[Int] raise PdfError {
  pdf_parse_pagespec_with_selectors(end_page, spec, None)
}

///|
/// Parse a cpdf page specification without a concrete PDF document.
pub fn pdf_parse_pagespec_without_pdf(
  spec : String,
) -> Array[Int] raise PdfError {
  pdf_parse_pagespec_for_count(500000, spec)
}
