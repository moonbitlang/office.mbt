///|
priv enum PdfPageSpecToken {
  PageSpecNumber(Int)
  PageSpecWord(String)
  PageSpecDash
  PageSpecComma
}

///|
priv struct PdfPageSpecContext {
  end_page : Int
  document : PdfDocument?
  source : String
}

///|
fn PdfPageSpecContext::bad(self : PdfPageSpecContext) -> Unit raise PdfError {
  raise BadPageSpecification(self.source)
}

///|
fn pdf_pagespec_is_digit(value : Int) -> Bool {
  value >= 48 && value <= 57
}

///|
fn pdf_pagespec_is_separator(value : Int) -> Bool {
  value == 45 || value == 44 || pdf_is_whitespace_byte(value)
}

///|
fn pdf_pagespec_parse_nonnegative_int(text : String) -> Int? {
  if text.length() == 0 {
    None
  } else {
    let mut valid = true
    for char in text {
      let value = char.to_int()
      if !pdf_pagespec_is_digit(value) {
        valid = false
      }
    }
    if !valid {
      None
    } else {
      let parsed : Result[Int, Error] = try? @strconv.from_str(text)
      match parsed {
        Ok(value) if value >= 0 => Some(value)
        _ => None
      }
    }
  }
}

///|
fn pdf_pagespec_token_of_view(
  view : BytesView,
  context : PdfPageSpecContext,
) -> PdfPageSpecToken raise PdfError {
  let text = @ascii.decode_lossy(view)
  match pdf_pagespec_parse_nonnegative_int(text) {
    Some(value) => PageSpecNumber(value)
    None =>
      if text.length() == 0 {
        context.bad()
        PageSpecWord("")
      } else {
        PageSpecWord(text)
      }
  }
}

///|
fn pdf_pagespec_tokenize(
  text : String,
  context : PdfPageSpecContext,
) -> Array[PdfPageSpecToken] raise PdfError {
  let bytes = @utf8.encode(text)
  let tokens : Array[PdfPageSpecToken] = Array::new(capacity=bytes.length())
  let mut index = 0
  while index < bytes.length() {
    let value = bytes[index].to_int()
    if pdf_is_whitespace_byte(value) {
      index += 1
    } else if value == 45 {
      tokens.push(PageSpecDash)
      index += 1
    } else if value == 44 {
      tokens.push(PageSpecComma)
      index += 1
    } else {
      let start = index
      while index < bytes.length() &&
            !pdf_pagespec_is_separator(bytes[index].to_int()) {
        index += 1
      }
      tokens.push(pdf_pagespec_token_of_view(bytes[start:index], context))
    }
  }
  tokens
}

///|
fn pdf_pagespec_range(start : Int, finish : Int) -> Array[Int] {
  let output : Array[Int] = Array::new(
    capacity=if start <= finish {
      finish - start + 1
    } else {
      start - finish + 1
    },
  )
  if start <= finish {
    let mut page = start
    while page <= finish {
      output.push(page)
      page += 1
    }
  } else {
    let mut page = start
    while page >= finish {
      output.push(page)
      page -= 1
    }
  }
  output
}

///|
fn pdf_pagespec_all_pages(end_page : Int) -> Array[Int] {
  pdf_pagespec_range(1, end_page)
}

///|
fn pdf_pagespec_invert_range(
  end_page : Int,
  range : ArrayView[Int],
) -> Array[Int] {
  if end_page <= 0 {
    []
  } else {
    let selected_pages = Array::make(end_page + 1, false)
    for selected in range {
      if selected >= 1 && selected <= end_page {
        selected_pages[selected] = true
      }
    }
    let output : Array[Int] = Array::new(capacity=end_page)
    for page in 1..<=end_page {
      if !selected_pages[page] {
        output.push(page)
      }
    }
    output
  }
}

///|
fn pdf_pagespec_count_commas(tokens : ArrayView[PdfPageSpecToken]) -> Int {
  let mut count = 0
  for token in tokens {
    if token is PageSpecComma {
      count += 1
    }
  }
  count
}

///|
fn pdf_pagespec_sum_lengths(parts : ArrayView[Array[Int]]) -> Int {
  let mut length = 0
  for part in parts {
    length += part.length()
  }
  length
}

///|
fn pdf_pagespec_flatten(parts : ArrayView[Array[Int]]) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=pdf_pagespec_sum_lengths(parts))
  for part in parts {
    for page in part {
      output.push(page)
    }
  }
  output
}

///|
pub fn pdf_invert_page_range(
  end_page : Int,
  range : ArrayView[Int],
) -> Array[Int] {
  pdf_pagespec_invert_range(end_page, range)
}

///|
/// Source-spelled compatibility alias for cpdfpagespec's `invert_range`.
pub fn pdf_invert_range(end_page : Int, range : ArrayView[Int]) -> Array[Int] {
  pdf_pagespec_invert_range(end_page, range)
}

///|
fn pdf_pagespec_duplicate_range(
  count : Int,
  range : ArrayView[Int],
) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=count * range.length())
  for page in range {
    for _ in 0..<count {
      output.push(page)
    }
  }
  output
}

///|
fn pdf_pagespec_filter_odd(range : ArrayView[Int]) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=range.length())
  for page in range {
    if page % 2 != 0 {
      output.push(page)
    }
  }
  output
}

///|
fn pdf_pagespec_filter_even(range : ArrayView[Int]) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=range.length())
  for page in range {
    if page % 2 == 0 {
      output.push(page)
    }
  }
  output
}

///|
fn pdf_pagespec_token_number(
  context : PdfPageSpecContext,
  token : PdfPageSpecToken,
) -> Int? raise PdfError {
  match token {
    PageSpecNumber(value) => Some(value)
    PageSpecWord("end") => Some(context.end_page)
    PageSpecWord(text) if text.has_prefix("~") => {
      let rest = text.unsafe_substring(start=1, end=text.length())
      match pdf_pagespec_parse_nonnegative_int(rest) {
        Some(value) => Some(context.end_page + 1 - value)
        None => {
          context.bad()
          None
        }
      }
    }
    _ => None
  }
}

///|
fn pdf_pagespec_split_commas(
  tokens : ArrayView[PdfPageSpecToken],
  context : PdfPageSpecContext,
  comma_count : Int,
) -> Array[Array[PdfPageSpecToken]] raise PdfError {
  let parts : Array[Array[PdfPageSpecToken]] = Array::new(
    capacity=comma_count + 1,
  )
  let mut current : Array[PdfPageSpecToken] = Array::new(
    capacity=tokens.length(),
  )
  for token in tokens {
    if token is PageSpecComma {
      if current.length() == 0 {
        context.bad()
      }
      parts.push(current)
      current = Array::new(capacity=tokens.length())
    } else {
      current.push(token)
    }
  }
  if current.length() == 0 {
    context.bad()
  }
  parts.push(current)
  parts
}

///|
fn PdfPageSpecContext::select_dimensions(
  self : PdfPageSpecContext,
  candidates : ArrayView[Int],
  portrait : Bool,
) -> Array[Int] raise PdfError {
  match self.document {
    Some(document) => {
      let pages = document.pages_of_pagetree()
      let output : Array[Int] = Array::new(capacity=candidates.length())
      for page_number in candidates {
        if page_number >= 1 && page_number <= pages.length() {
          let page = pages[page_number - 1]
          let rectangle = document.parse_rectangle(page.mediabox)
          let width = rectangle.max_x - rectangle.min_x
          let height = rectangle.max_y - rectangle.min_y
          if (portrait && width < height) || (!portrait && width > height) {
            output.push(page_number)
          }
        }
      }
      output
    }
    None => {
      self.bad()
      []
    }
  }
}

///|
fn PdfPageSpecContext::select_annotated(
  self : PdfPageSpecContext,
  candidates : ArrayView[Int],
) -> Array[Int] raise PdfError {
  match self.document {
    Some(document) => {
      let pages = document.pages_of_pagetree()
      let output : Array[Int] = Array::new(capacity=candidates.length())
      for page_number in candidates {
        if page_number >= 1 && page_number <= pages.length() {
          let page = pages[page_number - 1]
          match document.lookup_direct(pdf_page_annots_key(), page.rest) {
            Some(PdfArray(annotations)) if annotations.length() > 0 =>
              output.push(page_number)
            _ => ()
          }
        }
      }
      output
    }
    None => {
      self.bad()
      []
    }
  }
}

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
fn PdfPageSpecContext::read_page_label_reference(
  self : PdfPageSpecContext,
  spec : BytesView,
  open_index : Int,
) -> (Bytes, Int) raise PdfError {
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
fn PdfPageSpecContext::page_number_bytes_for_label(
  self : PdfPageSpecContext,
  label : BytesView,
  labels : ArrayView[PdfPageLabel],
) -> Bytes raise PdfError {
  let mut found = false
  let mut output = Bytes::new(0)
  for page_number in 1..<=self.end_page {
    let page_label = match
      pdf_page_label_text_of_page_number(page_number, labels) {
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
fn PdfPageSpecContext::resolved_page_labels_length(
  self : PdfPageSpecContext,
  spec : BytesView,
  labels : ArrayView[PdfPageLabel],
) -> Int raise PdfError {
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
fn PdfPageSpecContext::resolve_page_labels(
  self : PdfPageSpecContext,
  spec : BytesView,
) -> Bytes raise PdfError {
  match self.document {
    None => {
      for byte in spec {
        if byte.to_int() == 91 || byte.to_int() == 93 {
          self.bad()
        }
      }
      spec.to_owned()
    }
    Some(document) => {
      let labels = document.read_page_labels()
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
  let resolved = self.resolve_page_labels(@utf8.encode(effective))
  let resolved_text = @ascii.decode_lossy(resolved)
  self.filter_valid_pages(self.parse_resolved_text(resolved_text))
}

///|
pub fn pdf_parse_pagespec_for_count(
  end_page : Int,
  spec : String,
) -> Array[Int] raise PdfError {
  if end_page < 1 {
    raise BadPageSpecification(spec)
  }
  { end_page, document: None, source: spec }.parse_inner(spec)
}

///|
pub fn pdf_parse_pagespec_without_pdf(
  spec : String,
) -> Array[Int] raise PdfError {
  pdf_parse_pagespec_for_count(500000, spec)
}

///|
pub fn PdfDocument::parse_pagespec(
  self : PdfDocument,
  spec : String,
) -> Array[Int] raise PdfError {
  let end_page = self.endpage()
  if end_page < 1 {
    raise BadPageSpecification(spec)
  }
  { end_page, document: Some(self), source: spec }.parse_inner(spec)
}

///|
pub fn pdf_parse_pagespec(
  document : PdfDocument,
  spec : String,
) -> Array[Int] raise PdfError {
  document.parse_pagespec(spec)
}

///|
fn pdf_pagespec_same_values(
  left : ArrayView[Int],
  right : ArrayView[Int],
) -> Bool {
  if left.length() != right.length() {
    false
  } else {
    for index in 0..<left.length() {
      if left[index] != right[index] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn pdf_pagespec_join_ranges(ranges : ArrayView[(Int, Int)]) -> String {
  let mut output = ""
  for index in 0..<ranges.length() {
    let (start, finish) = ranges[index]
    if index > 0 {
      output = output + ","
    }
    if start == finish {
      output = output + start.to_string()
    } else {
      output = output + start.to_string() + "-" + finish.to_string()
    }
  }
  output
}

///|
pub fn pdf_string_of_pagespec_for_count(
  end_page : Int,
  pages : ArrayView[Int],
) -> String {
  if pages.length() == 0 {
    ""
  } else {
    let sorted = pages.to_owned()
    sorted.sort()
    if end_page > 3 &&
      pdf_pagespec_same_values(
        sorted,
        pdf_pagespec_filter_even(pdf_pagespec_all_pages(end_page)),
      ) {
      "even"
    } else if end_page > 2 &&
      pdf_pagespec_same_values(
        sorted,
        pdf_pagespec_filter_odd(pdf_pagespec_all_pages(end_page)),
      ) {
      "odd"
    } else if pdf_pagespec_same_values(sorted, pdf_pagespec_all_pages(end_page)) {
      "all"
    } else {
      let ranges : Array[(Int, Int)] = Array::new(capacity=sorted.length())
      let mut start = sorted[0]
      let mut previous = sorted[0]
      for index in 1..<sorted.length() {
        let page = sorted[index]
        if page == previous + 1 {
          previous = page
        } else {
          ranges.push((start, previous))
          start = page
          previous = page
        }
      }
      ranges.push((start, previous))
      pdf_pagespec_join_ranges(ranges)
    }
  }
}

///|
pub fn PdfDocument::string_of_pagespec(
  self : PdfDocument,
  pages : ArrayView[Int],
) -> String raise PdfError {
  pdf_string_of_pagespec_for_count(self.endpage(), pages)
}

///|
pub fn pdf_string_of_pagespec(
  document : PdfDocument,
  pages : ArrayView[Int],
) -> String raise PdfError {
  document.string_of_pagespec(pages)
}
