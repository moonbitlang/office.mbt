///|
fn pdf_text_hex_digit_value(byte : Byte) -> Int? {
  let value = byte.to_int()
  if value >= 48 && value <= 57 {
    Some(value - 48)
  } else if value >= 65 && value <= 70 {
    Some(value - 55)
  } else if value >= 97 && value <= 102 {
    Some(value - 87)
  } else {
    None
  }
}

///|
fn pdf_text_parse_hex_bytes(
  line : BytesView,
  start : Int,
  stop : Int,
) -> PdfBytes? {
  guard stop >= start else { return None }
  let mut digit_count = 0
  let mut scan = start
  while scan < stop {
    let value = line[scan].to_int()
    if pdf_is_whitespace_byte(value) {
      ()
    } else {
      match pdf_text_hex_digit_value(line[scan]) {
        Some(_) => digit_count += 1
        None => return None
      }
    }
    scan += 1
  }
  let output = Array::make((digit_count + 1) / 2, b'\x00')
  let mut high : Int? = None
  let mut position = 0
  let mut index = start
  while index < stop {
    let value = line[index].to_int()
    if pdf_is_whitespace_byte(value) {
      ()
    } else {
      match pdf_text_hex_digit_value(line[index]) {
        Some(nibble) =>
          match high {
            Some(high_nibble) => {
              output[position] = (high_nibble * 16 + nibble).to_byte()
              position += 1
              high = None
            }
            None => high = Some(nibble)
          }
        None => ()
      }
    }
    index += 1
  }
  if high is Some(high_nibble) {
    output[position] = (high_nibble * 16).to_byte()
  }
  Some(Bytes::from_array(output))
}

///|
fn pdf_text_skip_cmap_whitespace(line : BytesView, start : Int) -> Int {
  let mut index = start
  while index < line.length() && pdf_is_whitespace_byte(line[index].to_int()) {
    index += 1
  }
  index
}

///|
fn pdf_text_line_contains_ascii(line : BytesView, word : String) -> Bool {
  pdf_text_index_of_ascii(line, word) != None
}

///|
fn pdf_text_index_of_ascii(line : BytesView, word : String) -> Int? {
  let needle = @ascii.encode(word)
  guard needle.length() > 0 && line.length() >= needle.length() else {
    return None
  }
  for index in 0..<=(line.length() - needle.length()) {
    let mut matched = true
    for offset in 0..<needle.length() {
      if line[index + offset] != needle[offset] {
        matched = false
      }
    }
    if matched {
      break Some(index)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_index_of_ascii_from(
  line : BytesView,
  word : String,
  start : Int,
) -> Int? {
  guard start < line.length() else { return None }
  match pdf_text_index_of_ascii(line[start:], word) {
    Some(index) => Some(start + index)
    None => None
  }
}

///|
fn pdf_text_after_ascii(line : BytesView, word : String) -> BytesView? {
  match pdf_text_index_of_ascii(line, word) {
    Some(index) => {
      let word_length = @ascii.encode(word).length()
      Some(line[index + word_length:])
    }
    None => None
  }
}

///|
fn pdf_text_view_equals_ascii(view : BytesView, text : String) -> Bool {
  let expected = @ascii.encode(text)
  guard view.length() == expected.length() else { return false }
  for index in 0..<view.length() {
    if view[index] != expected[index] {
      break false
    }
  } nobreak {
    true
  }
}

///|
fn pdf_text_parse_cmap_int_after_token(data : BytesView, key : String) -> Int? {
  let cursor = byte_cursor_of_view(data)
  let mut expect_value = false
  for line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(line)
    let tokens = pdf_split_whitespace_tokens(uncommented)
    for token in tokens {
      if expect_value {
        expect_value = false
        let parsed = try pdf_parse_ascii_int_view(token) catch {
          _ => None
        } noraise {
          value => Some(value)
        }
        match parsed {
          Some(value) => return Some(value)
          None => ()
        }
      }
      if pdf_text_view_equals_ascii(token, key) {
        expect_value = true
      }
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_parse_cmap_wmode(data : BytesView) -> Int? {
  pdf_text_parse_cmap_int_after_token(data, "/WMode")
}

///|
fn pdf_text_parse_cmap_name_token(token : BytesView) -> PdfName? {
  guard token.length() > 1 && token[0].to_int() == 47 else { return None }
  let bytes : Array[Byte] = [47]
  let mut index = 1
  while index < token.length() {
    let value = token[index].to_int()
    if value == 35 {
      guard index + 2 < token.length() else { return None }
      match
        (
          pdf_hex_value(token[index + 1].to_int()),
          pdf_hex_value(token[index + 2].to_int()),
        ) {
        (Some(high), Some(low)) => {
          bytes.push((high * 16 + low).to_byte())
          index += 3
        }
        _ => return None
      }
    } else {
      bytes.push(token[index])
      index += 1
    }
  }
  Some(pdf_name_of_bytes(Bytes::from_array(bytes)))
}

///|
fn pdf_text_parse_cmap_name_after_token(
  data : BytesView,
  key : String,
) -> PdfName? {
  let cursor = byte_cursor_of_view(data)
  let mut expect_value = false
  for line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(line)
    let tokens = pdf_split_whitespace_tokens(uncommented)
    for token in tokens {
      if expect_value {
        expect_value = false
        match pdf_text_parse_cmap_name_token(token) {
          Some(name) => return Some(name)
          None => ()
        }
      }
      if pdf_text_view_equals_ascii(token, key) {
        expect_value = true
      }
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_parse_cmap_object_token(token : BytesView) -> PdfObject? {
  try pdf_parse_object_from_view(token) catch {
    _ => None
  } noraise {
    object => Some(object)
  }
}

///|
priv enum PdfTextCMapCIDSystemInfoKey {
  PdfTextCMapCIDSystemRegistry
  PdfTextCMapCIDSystemOrdering
  PdfTextCMapCIDSystemSupplement
}

///|
fn pdf_text_parse_cmap_cid_system_value(
  key : PdfTextCMapCIDSystemInfoKey,
  token : BytesView,
  registry : Array[PdfBytes],
  ordering : Array[PdfBytes],
  supplement : Array[Int],
) -> Unit {
  match (key, pdf_text_parse_cmap_object_token(token)) {
    (PdfTextCMapCIDSystemRegistry, Some(PdfString(value))) =>
      registry.push(value)
    (PdfTextCMapCIDSystemOrdering, Some(PdfString(value))) =>
      ordering.push(value)
    (PdfTextCMapCIDSystemSupplement, Some(PdfInteger(value))) =>
      supplement.push(value)
    _ => ()
  }
}

///|
fn pdf_text_parse_cmap_cid_system_info(data : BytesView) -> PdfCIDSystemInfo? {
  let cursor = byte_cursor_of_view(data)
  let registries : Array[PdfBytes] = Array::new(capacity=1)
  let orderings : Array[PdfBytes] = Array::new(capacity=1)
  let supplements : Array[Int] = Array::new(capacity=1)
  let mut seen_cid_system_info = false
  let mut expect_value : PdfTextCMapCIDSystemInfoKey? = None
  for line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(line)
    let tokens = pdf_split_whitespace_tokens(uncommented)
    for token in tokens {
      if !seen_cid_system_info {
        if pdf_text_view_equals_ascii(token, "/CIDSystemInfo") {
          seen_cid_system_info = true
        }
        continue
      }
      match expect_value {
        Some(key) => {
          pdf_text_parse_cmap_cid_system_value(
            key, token, registries, orderings, supplements,
          )
          expect_value = None
          if registries.length() > 0 &&
            orderings.length() > 0 &&
            supplements.length() > 0 {
            return Some({
              registry: registries[0],
              ordering: orderings[0],
              supplement: supplements[0],
            })
          }
        }
        None => ()
      }
      if pdf_text_view_equals_ascii(token, "/Registry") {
        expect_value = Some(PdfTextCMapCIDSystemRegistry)
      } else if pdf_text_view_equals_ascii(token, "/Ordering") {
        expect_value = Some(PdfTextCMapCIDSystemOrdering)
      } else if pdf_text_view_equals_ascii(token, "/Supplement") {
        expect_value = Some(PdfTextCMapCIDSystemSupplement)
      }
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_parse_cmap_usecmap(data : BytesView) -> PdfName? {
  let cursor = byte_cursor_of_view(data)
  let mut previous_name : PdfName? = None
  for line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(line)
    let tokens = pdf_split_whitespace_tokens(uncommented)
    for token in tokens {
      if pdf_text_view_equals_ascii(token, "usecmap") {
        match previous_name {
          Some(name) => return Some(name)
          None => ()
        }
      }
      previous_name = pdf_text_parse_cmap_name_token(token)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_cmap_end_marker(line : BytesView, start : Int) -> (Int, Int)? {
  let markers = [
    "endbfchar", "endbfrange", "endcidchar", "endcidrange", "endnotdefchar", "endnotdefrange",
    "endcodespacerange",
  ]
  let mut best : (Int, Int)? = None
  for marker in markers {
    match pdf_text_index_of_ascii_from(line, marker, start) {
      Some(index) => {
        let length = @ascii.encode(marker).length()
        match best {
          Some((best_index, _)) if best_index <= index => ()
          _ => best = Some((index, length))
        }
      }
      None => ()
    }
  }
  best
}

///|
fn pdf_text_cmap_section_line_views(line : BytesView) -> Array[BytesView] {
  let views : Array[BytesView] = Array::new(capacity=line.length())
  let mut start = 0
  while start < line.length() {
    match pdf_text_cmap_end_marker(line, start) {
      Some((index, length)) => {
        let stop = index + length
        views.push(line[start:stop])
        start = stop
      }
      None => {
        views.push(line[start:])
        break
      }
    }
  }
  views
}

///|
fn pdf_text_cmap_comment_start(line : BytesView) -> Int {
  let mut in_literal = false
  let mut escaped = false
  let mut literal_depth = 0
  for index in 0..<line.length() {
    let value = line[index].to_int()
    if in_literal {
      if escaped {
        escaped = false
      } else if value == 92 {
        escaped = true
      } else if value == 40 {
        literal_depth += 1
      } else if value == 41 {
        literal_depth -= 1
        if literal_depth <= 0 {
          in_literal = false
          literal_depth = 0
        }
      }
    } else if value == 37 {
      return index
    } else if value == 40 {
      in_literal = true
      literal_depth = 1
      escaped = false
    }
  }
  line.length()
}

///|
fn pdf_text_cmap_line_without_comment(line : BytesView) -> PdfBytes {
  let stop = pdf_text_cmap_comment_start(line)
  let output = Array::make(stop, b'\x00')
  for index in 0..<stop {
    output[index] = line[index]
  }
  Bytes::from_array(output)
}

///|
fn pdf_text_parse_cmap_hex_groups(line : BytesView) -> Array[PdfBytes]? {
  let groups : Array[PdfBytes] = Array::new(capacity=line.length() / 2)
  let mut index = 0
  while index < line.length() {
    index = pdf_text_skip_cmap_whitespace(line, index)
    if index >= line.length() {
      break
    }
    if line[index].to_int() != 60 {
      break
    }
    let start = index + 1
    let mut stop = start
    while stop < line.length() && line[stop].to_int() != 62 {
      stop += 1
    }
    guard stop < line.length() else { return None }
    match pdf_text_parse_hex_bytes(line, start, stop) {
      Some(bytes) => groups.push(bytes)
      None => return None
    }
    index = stop + 1
  }
  if groups.length() == 0 {
    None
  } else {
    Some(groups)
  }
}

///|
fn pdf_text_parse_cmap_hex_group_at(
  line : BytesView,
  start : Int,
) -> (PdfBytes, Int)? {
  let index = pdf_text_skip_cmap_whitespace(line, start)
  guard index < line.length() && line[index].to_int() == 60 else { return None }
  let body_start = index + 1
  let mut stop = body_start
  while stop < line.length() && line[stop].to_int() != 62 {
    stop += 1
  }
  guard stop < line.length() else { return None }
  match pdf_text_parse_hex_bytes(line, body_start, stop) {
    Some(bytes) => Some((bytes, stop + 1))
    None => None
  }
}

///|
fn pdf_text_bytes_to_int(bytes : BytesView) -> Int? {
  guard bytes.length() > 0 else { return None }
  let mut value = 0
  for byte in bytes {
    value = (value << 8) | byte.to_int()
  }
  Some(value)
}

///|
fn pdf_text_parse_cmap_ascii_int_at(
  line : BytesView,
  start : Int,
) -> (Int, Int)? {
  let index = pdf_text_skip_cmap_whitespace(line, start)
  guard index < line.length() else { return None }
  let mut stop = index
  if line[stop].to_int() == 43 || line[stop].to_int() == 45 {
    stop += 1
  }
  let digit_start = stop
  while stop < line.length() {
    let value = line[stop].to_int()
    if value >= 48 && value <= 57 {
      stop += 1
    } else {
      break
    }
  }
  guard stop > digit_start else { return None }
  try pdf_parse_ascii_int_view(line[index:stop]) catch {
    _ => None
  } noraise {
    value => Some((value, stop))
  }
}

///|
fn pdf_text_index_of_byte(line : BytesView, target : Int, start : Int) -> Int? {
  let mut index = start
  while index < line.length() {
    if line[index].to_int() == target {
      break Some(index)
    }
    index += 1
  } nobreak {
    None
  }
}

///|
fn pdf_text_tounicode_bfrange_inline_entries(
  line : BytesView,
) -> Array[(Int, PdfBytes)]? {
  let entries : Array[(Int, PdfBytes)] = Array::new(capacity=line.length())
  let mut index = 0
  while index < line.length() {
    match pdf_text_parse_cmap_hex_group_at(line, index) {
      Some((source, after_source)) =>
        match pdf_text_parse_cmap_hex_group_at(line, after_source) {
          Some((stop, after_stop)) =>
            match (pdf_text_bytes_to_int(source), pdf_text_bytes_to_int(stop)) {
              (Some(first), Some(last)) if first <= last => {
                index = pdf_text_skip_cmap_whitespace(line, after_stop)
                if index < line.length() && line[index].to_int() == 91 {
                  match pdf_text_index_of_byte(line, 93, index + 1) {
                    Some(close) => {
                      match
                        pdf_text_parse_cmap_hex_groups(line[index + 1:close]) {
                        Some(unicodes) =>
                          match
                            pdf_text_tounicode_bfrange_array_entries(
                              first, last, unicodes,
                            ) {
                            Some(line_entries) =>
                              for entry in line_entries {
                                entries.push(entry)
                              }
                            None => return None
                          }
                        None => return None
                      }
                      index = close + 1
                    }
                    None => return None
                  }
                } else {
                  match pdf_text_parse_cmap_hex_group_at(line, index) {
                    Some((unicode, after_unicode)) => {
                      for code in first..<=last {
                        match
                          pdf_text_add_to_big_endian_bytes(
                            unicode,
                            code - first,
                          ) {
                          Some(bytes) => entries.push((code, bytes))
                          None => return None
                        }
                      }
                      index = after_unicode
                    }
                    None => return None
                  }
                }
              }
              _ => return None
            }
          None => return None
        }
      None => break
    }
  }
  if entries.length() == 0 {
    None
  } else {
    Some(entries)
  }
}

///|
fn pdf_text_add_to_big_endian_bytes(
  bytes : PdfBytes,
  increment : Int,
) -> PdfBytes? {
  guard increment >= 0 else { return None }
  let output = bytes.to_array()
  let mut carry = increment
  let mut index = output.length()
  while index > 0 && carry > 0 {
    index -= 1
    let sum = output[index].to_int() + carry % 256
    output[index] = (sum % 256).to_byte()
    carry = carry / 256 + sum / 256
  }
  if carry == 0 {
    Some(Bytes::from_array(output))
  } else {
    None
  }
}

///|
fn pdf_text_tounicode_bfrange_array_entries(
  first : Int,
  last : Int,
  unicodes : ArrayView[PdfBytes],
) -> Array[(Int, PdfBytes)]? {
  guard first <= last && unicodes.length() == last - first + 1 else {
    return None
  }
  let entries : Array[(Int, PdfBytes)] = Array::new(capacity=unicodes.length())
  for index in 0..<unicodes.length() {
    entries.push((first + index, unicodes[index]))
  }
  Some(entries)
}

///|
fn pdf_text_push_tounicode_bfchar_entry(
  entries : Array[(Int, PdfBytes)],
  source : PdfBytes,
  unicode : PdfBytes,
) -> Unit {
  match pdf_text_bytes_to_int(source) {
    Some(code) => entries.push((code, unicode))
    None => ()
  }
}

///|
fn pdf_text_append_tounicode_bfchar_entries(
  entries : Array[(Int, PdfBytes)],
  pending_source : PdfBytes?,
  line : BytesView,
) -> PdfBytes? {
  let mut pending = pending_source
  match pdf_text_parse_cmap_hex_groups(line) {
    Some(groups) => {
      let mut index = 0
      match pending {
        Some(source) =>
          if groups.length() > 0 {
            pdf_text_push_tounicode_bfchar_entry(entries, source, groups[0])
            pending = None
            index = 1
          }
        None => ()
      }
      while index + 1 < groups.length() {
        pdf_text_push_tounicode_bfchar_entry(
          entries,
          groups[index],
          groups[index + 1],
        )
        index += 2
      }
      if index < groups.length() {
        pending = Some(groups[index])
      }
      pending
    }
    None => pending
  }
}

///|
fn pdf_text_tounicode_bfrange_entries_of_line(
  line : BytesView,
) -> Array[(Int, PdfBytes)]? {
  pdf_text_tounicode_bfrange_inline_entries(line)
}

///|
fn pdf_text_push_tounicode_bfrange_entries(
  entries : Array[(Int, PdfBytes)],
  line_entries : ArrayView[(Int, PdfBytes)],
) -> Unit {
  for entry in line_entries {
    entries.push(entry)
  }
}

///|
priv struct PdfTextCMapBFRangeArray {
  first : Int
  last : Int
  unicodes : Array[PdfBytes]
}

///|
fn pdf_text_extend_cmap_hex_groups(
  output : Array[PdfBytes],
  line : BytesView,
) -> Unit {
  match pdf_text_parse_cmap_hex_groups(line) {
    Some(groups) =>
      for group in groups {
        output.push(group)
      }
    None => ()
  }
}

///|
fn pdf_text_cmap_bfrange_array_line(line : BytesView) -> BytesView {
  match pdf_text_index_of_byte(line, 91, 0) {
    Some(open) => line[open + 1:]
    None => line
  }
}

///|
priv enum PdfTextCMapBFRangeArrayAppend {
  PdfTextCMapBFRangeArrayPending(PdfTextCMapBFRangeArray)
  PdfTextCMapBFRangeArrayClosed(BytesView)
}

///|
fn pdf_text_append_pending_bfrange_array(
  entries : Array[(Int, PdfBytes)],
  pending : PdfTextCMapBFRangeArray,
  line : BytesView,
) -> PdfTextCMapBFRangeArrayAppend {
  let content = pdf_text_cmap_bfrange_array_line(line)
  match pdf_text_index_of_byte(content, 93, 0) {
    Some(close) => {
      pdf_text_extend_cmap_hex_groups(pending.unicodes, content[0:close])
      match
        pdf_text_tounicode_bfrange_array_entries(
          pending.first,
          pending.last,
          pending.unicodes,
        ) {
        Some(line_entries) =>
          pdf_text_push_tounicode_bfrange_entries(entries, line_entries)
        None => ()
      }
      PdfTextCMapBFRangeArrayClosed(content[close + 1:])
    }
    None => {
      pdf_text_extend_cmap_hex_groups(pending.unicodes, content)
      PdfTextCMapBFRangeArrayPending(pending)
    }
  }
}

///|
priv enum PdfTextCMapBFRangeLineAppend {
  PdfTextCMapBFRangeLineDone
  PdfTextCMapBFRangeLinePending(PdfTextCMapBFRangeArray)
  PdfTextCMapBFRangeLineContinue(BytesView)
}

///|
fn pdf_text_append_tounicode_bfrange_entry(
  entries : Array[(Int, PdfBytes)],
  line : BytesView,
) -> PdfTextCMapBFRangeLineAppend {
  match pdf_text_parse_cmap_hex_group_at(line, 0) {
    Some((source, after_source)) =>
      match pdf_text_parse_cmap_hex_group_at(line, after_source) {
        Some((stop, after_stop)) =>
          match (pdf_text_bytes_to_int(source), pdf_text_bytes_to_int(stop)) {
            (Some(first), Some(last)) if first <= last => {
              let value_start = pdf_text_skip_cmap_whitespace(line, after_stop)
              let pending : PdfTextCMapBFRangeArray = {
                first,
                last,
                unicodes: [],
              }
              if value_start >= line.length() {
                PdfTextCMapBFRangeLinePending(pending)
              } else if line[value_start].to_int() == 91 {
                match
                  pdf_text_append_pending_bfrange_array(
                    entries,
                    pending,
                    line[value_start + 1:],
                  ) {
                  PdfTextCMapBFRangeArrayClosed(rest) =>
                    PdfTextCMapBFRangeLineContinue(rest)
                  PdfTextCMapBFRangeArrayPending(pending) =>
                    PdfTextCMapBFRangeLinePending(pending)
                }
              } else {
                match pdf_text_parse_cmap_hex_group_at(line, value_start) {
                  Some((unicode, after_unicode)) => {
                    let line_entries : Array[(Int, PdfBytes)] = Array::new(
                      capacity=last - first + 1,
                    )
                    for code in first..<=last {
                      match
                        pdf_text_add_to_big_endian_bytes(unicode, code - first) {
                        Some(bytes) => line_entries.push((code, bytes))
                        None => return PdfTextCMapBFRangeLineDone
                      }
                    }
                    pdf_text_push_tounicode_bfrange_entries(
                      entries, line_entries,
                    )
                    PdfTextCMapBFRangeLineContinue(line[after_unicode:])
                  }
                  None => PdfTextCMapBFRangeLineDone
                }
              }
            }
            _ => PdfTextCMapBFRangeLineDone
          }
        None => PdfTextCMapBFRangeLineDone
      }
    None => PdfTextCMapBFRangeLineDone
  }
}

///|
fn pdf_text_append_tounicode_bfrange_line(
  entries : Array[(Int, PdfBytes)],
  line : BytesView,
) -> PdfTextCMapBFRangeArray? {
  match pdf_text_tounicode_bfrange_entries_of_line(line) {
    Some(line_entries) => {
      pdf_text_push_tounicode_bfrange_entries(entries, line_entries)
      return None
    }
    None => ()
  }
  let mut current = line
  while current.length() > 0 {
    match pdf_text_append_tounicode_bfrange_entry(entries, current) {
      PdfTextCMapBFRangeLineDone => return None
      PdfTextCMapBFRangeLinePending(pending) => return Some(pending)
      PdfTextCMapBFRangeLineContinue(rest) => current = rest
    }
  }
  None
}

///|
priv enum PdfTextToUnicodeSection {
  PdfTextToUnicodeNone
  PdfTextToUnicodeBFChar
  PdfTextToUnicodeBFRange
}

///|
priv enum PdfTextCMapSection {
  PdfTextCMapNone
  PdfTextCMapCIDChar
  PdfTextCMapCIDRange
  PdfTextCMapNotDefChar
  PdfTextCMapNotDefRange
  PdfTextCMapCodeSpace
}

///|
fn pdf_text_cmap_contains_whitespace(data : BytesView) -> Bool {
  for byte in data {
    if pdf_is_whitespace_byte(byte.to_int()) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_text_cmap_without_whitespace(data : BytesView) -> PdfBytes {
  let mut length = 0
  for byte in data {
    if !pdf_is_whitespace_byte(byte.to_int()) {
      length += 1
    }
  }
  let output = Array::make(length, b'\x00')
  let mut position = 0
  for byte in data {
    if !pdf_is_whitespace_byte(byte.to_int()) {
      output[position] = byte
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_text_parse_tounicode_sections(
  data : BytesView,
) -> Array[(Int, PdfBytes)]? {
  let cursor = byte_cursor_of_view(data)
  let entries : Array[(Int, PdfBytes)] = Array::new(capacity=data.length() / 4)
  let mut section = PdfTextToUnicodeNone
  let mut pending_bfchar_source : PdfBytes? = None
  let mut pending_bfrange_array : PdfTextCMapBFRangeArray? = None
  for raw_line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(raw_line)
    for raw_segment in pdf_text_cmap_section_line_views(uncommented) {
      let mut line = raw_segment
      match pdf_text_after_ascii(raw_segment, "beginbfchar") {
        Some(rest) => {
          section = PdfTextToUnicodeBFChar
          line = rest
        }
        None =>
          match pdf_text_after_ascii(raw_segment, "beginbfrange") {
            Some(rest) => {
              section = PdfTextToUnicodeBFRange
              line = rest
            }
            None => ()
          }
      }
      let end_bfchar = pdf_text_line_contains_ascii(line, "endbfchar")
      let end_bfrange = pdf_text_line_contains_ascii(line, "endbfrange")
      match pending_bfrange_array {
        Some(pending) =>
          match pdf_text_append_pending_bfrange_array(entries, pending, line) {
            PdfTextCMapBFRangeArrayClosed(rest) =>
              pending_bfrange_array = pdf_text_append_tounicode_bfrange_line(
                entries, rest,
              )
            PdfTextCMapBFRangeArrayPending(pending) =>
              pending_bfrange_array = Some(pending)
          }
        None =>
          match section {
            PdfTextToUnicodeBFChar =>
              pending_bfchar_source = pdf_text_append_tounicode_bfchar_entries(
                entries, pending_bfchar_source, line,
              )
            PdfTextToUnicodeBFRange =>
              pending_bfrange_array = pdf_text_append_tounicode_bfrange_line(
                entries, line,
              )
            PdfTextToUnicodeNone => ()
          }
      }
      if end_bfchar && section is PdfTextToUnicodeBFChar {
        section = PdfTextToUnicodeNone
        pending_bfchar_source = None
      }
      if end_bfrange && section is PdfTextToUnicodeBFRange {
        section = PdfTextToUnicodeNone
      }
    }
  }
  if entries.length() == 0 {
    None
  } else {
    Some(entries)
  }
}

///|
fn pdf_text_push_cmap_cidchar_entries(
  entries : Array[(Int, Int)],
  line : BytesView,
) -> Unit {
  let mut index = 0
  while index < line.length() {
    match pdf_text_parse_cmap_hex_group_at(line, index) {
      Some((source, after_source)) =>
        match pdf_text_parse_cmap_ascii_int_at(line, after_source) {
          Some((cid, after_cid)) => {
            match pdf_text_bytes_to_int(source) {
              Some(code) => entries.push((code, cid))
              None => ()
            }
            index = after_cid
          }
          None => break
        }
      None => break
    }
  }
}

///|
fn pdf_text_push_cmap_cidrange_entries(
  entries : Array[(Int, Int)],
  line : BytesView,
) -> Unit {
  let mut index = 0
  while index < line.length() {
    match pdf_text_parse_cmap_hex_group_at(line, index) {
      Some((source, after_source)) =>
        match pdf_text_parse_cmap_hex_group_at(line, after_source) {
          Some((stop, after_stop)) =>
            match pdf_text_parse_cmap_ascii_int_at(line, after_stop) {
              Some((cid, after_cid)) => {
                match
                  (pdf_text_bytes_to_int(source), pdf_text_bytes_to_int(stop)) {
                  (Some(first), Some(last)) if first <= last =>
                    for code in first..<=last {
                      entries.push((code, cid + code - first))
                    }
                  _ => ()
                }
                index = after_cid
              }
              None => break
            }
          None => break
        }
      None => break
    }
  }
}

///|
fn pdf_text_push_cmap_codespace_entries(
  entries : Array[PdfCMapCodeSpace],
  line : BytesView,
) -> Unit {
  let mut index = 0
  while index < line.length() {
    match pdf_text_parse_cmap_hex_group_at(line, index) {
      Some((source, after_source)) =>
        match pdf_text_parse_cmap_hex_group_at(line, after_source) {
          Some((stop, after_stop)) => {
            match (pdf_text_bytes_to_int(source), pdf_text_bytes_to_int(stop)) {
              (Some(first), Some(last)) if first <= last &&
                source.length() == stop.length() =>
                entries.push({ length: source.length(), first, last })
              _ => ()
            }
            index = after_stop
          }
          None => break
        }
      None => break
    }
  }
}

///|
fn pdf_text_parse_cmap_cid_sections(data : BytesView) -> Array[(Int, Int)]? {
  let cursor = byte_cursor_of_view(data)
  let entries : Array[(Int, Int)] = Array::new(capacity=data.length() / 4)
  let mut section = PdfTextCMapNone
  for raw_line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(raw_line)
    for raw_segment in pdf_text_cmap_section_line_views(uncommented) {
      let mut line = raw_segment
      match pdf_text_after_ascii(raw_segment, "begincidchar") {
        Some(rest) => {
          section = PdfTextCMapCIDChar
          line = rest
        }
        None =>
          match pdf_text_after_ascii(raw_segment, "begincidrange") {
            Some(rest) => {
              section = PdfTextCMapCIDRange
              line = rest
            }
            None => ()
          }
      }
      match section {
        PdfTextCMapCIDChar => pdf_text_push_cmap_cidchar_entries(entries, line)
        PdfTextCMapCIDRange =>
          pdf_text_push_cmap_cidrange_entries(entries, line)
        _ => ()
      }
      if pdf_text_line_contains_ascii(line, "endcidchar") &&
        section is PdfTextCMapCIDChar {
        section = PdfTextCMapNone
      }
      if pdf_text_line_contains_ascii(line, "endcidrange") &&
        section is PdfTextCMapCIDRange {
        section = PdfTextCMapNone
      }
    }
  }
  if entries.length() == 0 {
    None
  } else {
    Some(entries)
  }
}

///|
fn pdf_text_parse_cmap_notdef_sections(data : BytesView) -> Array[(Int, Int)]? {
  let cursor = byte_cursor_of_view(data)
  let entries : Array[(Int, Int)] = Array::new(capacity=data.length() / 4)
  let mut section = PdfTextCMapNone
  for raw_line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(raw_line)
    for raw_segment in pdf_text_cmap_section_line_views(uncommented) {
      let mut line = raw_segment
      match pdf_text_after_ascii(raw_segment, "beginnotdefchar") {
        Some(rest) => {
          section = PdfTextCMapNotDefChar
          line = rest
        }
        None =>
          match pdf_text_after_ascii(raw_segment, "beginnotdefrange") {
            Some(rest) => {
              section = PdfTextCMapNotDefRange
              line = rest
            }
            None => ()
          }
      }
      match section {
        PdfTextCMapNotDefChar =>
          pdf_text_push_cmap_cidchar_entries(entries, line)
        PdfTextCMapNotDefRange =>
          pdf_text_push_cmap_cidrange_entries(entries, line)
        _ => ()
      }
      if pdf_text_line_contains_ascii(line, "endnotdefchar") &&
        section is PdfTextCMapNotDefChar {
        section = PdfTextCMapNone
      }
      if pdf_text_line_contains_ascii(line, "endnotdefrange") &&
        section is PdfTextCMapNotDefRange {
        section = PdfTextCMapNone
      }
    }
  }
  if entries.length() == 0 {
    None
  } else {
    Some(entries)
  }
}

///|
fn pdf_text_parse_cmap_codespace_sections(
  data : BytesView,
) -> Array[PdfCMapCodeSpace]? {
  let cursor = byte_cursor_of_view(data)
  let entries : Array[PdfCMapCodeSpace] = Array::new(capacity=data.length() / 4)
  let mut section = PdfTextCMapNone
  for raw_line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(raw_line)
    for raw_segment in pdf_text_cmap_section_line_views(uncommented) {
      let mut line = raw_segment
      match pdf_text_after_ascii(raw_segment, "begincodespacerange") {
        Some(rest) => {
          section = PdfTextCMapCodeSpace
          line = rest
        }
        None => ()
      }
      match section {
        PdfTextCMapCodeSpace =>
          pdf_text_push_cmap_codespace_entries(entries, line)
        _ => ()
      }
      if pdf_text_line_contains_ascii(line, "endcodespacerange") &&
        section is PdfTextCMapCodeSpace {
        section = PdfTextCMapNone
      }
    }
  }
  if entries.length() == 0 {
    None
  } else {
    Some(entries)
  }
}

///|
let pdf_text_cmap_split_begin_marker : PdfBytes = b"begin"

///|
let pdf_text_cmap_split_end_marker : PdfBytes = b"end"

///|
let pdf_text_cmap_split_suffixes : ReadOnlyArray[PdfBytes] = [
  b"bfchar", b"bfrange", b"cidchar", b"cidrange", b"notdefchar", b"notdefrange",
  b"codespacerange",
]

///|
fn pdf_text_cmap_starts_with_at(
  data : BytesView,
  start : Int,
  expected : BytesView,
) -> Bool {
  if start < 0 || start + expected.length() > data.length() {
    false
  } else {
    for offset in 0..<expected.length() {
      if data[start + offset] != expected[offset] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn pdf_text_cmap_has_split_marker_at(
  data : BytesView,
  start : Int,
  prefix : BytesView,
) -> Bool {
  guard pdf_text_cmap_starts_with_at(data, start, prefix) else { return false }
  let whitespace_start = start + prefix.length()
  let mut suffix_start = whitespace_start
  while suffix_start < data.length() &&
        pdf_is_whitespace_byte(data[suffix_start].to_int()) {
    suffix_start += 1
  }
  guard suffix_start > whitespace_start else { return false }
  for suffix in pdf_text_cmap_split_suffixes {
    if pdf_text_cmap_starts_with_at(data, suffix_start, suffix) {
      return true
    }
  }
  false
}

///|
fn pdf_text_cmap_has_split_marker(data : BytesView) -> Bool {
  for index in 0..<data.length() {
    if pdf_text_cmap_has_split_marker_at(
        data, index, pdf_text_cmap_split_begin_marker,
      ) ||
      pdf_text_cmap_has_split_marker_at(
        data, index, pdf_text_cmap_split_end_marker,
      ) {
      return true
    }
  }
  false
}

///|
fn pdf_text_parse_cmap_cids(data : BytesView) -> Array[(Int, Int)]? {
  if pdf_text_cmap_contains_whitespace(data) {
    let parsed = pdf_text_parse_cmap_cid_sections(data)
    if pdf_text_cmap_has_split_marker(data) {
      let compact = pdf_text_cmap_without_whitespace(data)
      let compact_parsed = pdf_text_parse_cmap_cid_sections(compact)
      match (parsed, compact_parsed) {
        (Some(original_entries), Some(compact_entries)) =>
          if compact_entries.length() > original_entries.length() {
            Some(compact_entries)
          } else {
            Some(original_entries)
          }
        (None, Some(compact_entries)) => Some(compact_entries)
        _ => parsed
      }
    } else {
      parsed
    }
  } else {
    pdf_text_parse_cmap_cid_sections(data)
  }
}

///|
fn pdf_text_parse_cmap_notdefs(data : BytesView) -> Array[(Int, Int)]? {
  if pdf_text_cmap_contains_whitespace(data) {
    let parsed = pdf_text_parse_cmap_notdef_sections(data)
    if pdf_text_cmap_has_split_marker(data) {
      let compact = pdf_text_cmap_without_whitespace(data)
      let compact_parsed = pdf_text_parse_cmap_notdef_sections(compact)
      match (parsed, compact_parsed) {
        (Some(original_entries), Some(compact_entries)) =>
          if compact_entries.length() > original_entries.length() {
            Some(compact_entries)
          } else {
            Some(original_entries)
          }
        (None, Some(compact_entries)) => Some(compact_entries)
        _ => parsed
      }
    } else {
      parsed
    }
  } else {
    pdf_text_parse_cmap_notdef_sections(data)
  }
}

///|
fn pdf_text_parse_cmap_codespaces(data : BytesView) -> Array[PdfCMapCodeSpace]? {
  if pdf_text_cmap_contains_whitespace(data) {
    let parsed = pdf_text_parse_cmap_codespace_sections(data)
    if pdf_text_cmap_has_split_marker(data) {
      let compact = pdf_text_cmap_without_whitespace(data)
      let compact_parsed = pdf_text_parse_cmap_codespace_sections(compact)
      match (parsed, compact_parsed) {
        (Some(original_entries), Some(compact_entries)) =>
          if compact_entries.length() > original_entries.length() {
            Some(compact_entries)
          } else {
            Some(original_entries)
          }
        (None, Some(compact_entries)) => Some(compact_entries)
        _ => parsed
      }
    } else {
      parsed
    }
  } else {
    pdf_text_parse_cmap_codespace_sections(data)
  }
}

///|
fn pdf_text_parse_tounicode(data : BytesView) -> Array[(Int, PdfBytes)]? {
  if pdf_text_cmap_contains_whitespace(data) {
    let parsed = pdf_text_parse_tounicode_sections(data)
    if pdf_text_cmap_has_split_marker(data) {
      let compact = pdf_text_cmap_without_whitespace(data)
      let compact_parsed = pdf_text_parse_tounicode_sections(compact)
      match (parsed, compact_parsed) {
        (Some(original_entries), Some(compact_entries)) =>
          if compact_entries.length() > original_entries.length() {
            Some(compact_entries)
          } else {
            Some(original_entries)
          }
        (None, Some(compact_entries)) => Some(compact_entries)
        _ => parsed
      }
    } else {
      parsed
    }
  } else {
    pdf_text_parse_tounicode_sections(data)
  }
}

///|
/// Parse raw CMap or ToUnicode bytes into mapping tables and metadata.
///
/// The parser accepts common CMap sections such as code-space ranges,
/// `bfchar`/`bfrange`, CID ranges, notdef ranges, `/UseCMap`, `/WMode`, and
/// CID-system metadata. Unrecognized or malformed sections are skipped rather
/// than causing a document-level failure.
pub fn pdf_parse_cmap_data(data : BytesView) -> PdfParsedCMap {
  {
    map: match pdf_text_parse_tounicode(data) {
      Some(entries) => entries
      None => []
    },
    cid_map: match pdf_text_parse_cmap_cids(data) {
      Some(entries) => entries
      None => []
    },
    notdef_map: match pdf_text_parse_cmap_notdefs(data) {
      Some(entries) => entries
      None => []
    },
    codespaces: match pdf_text_parse_cmap_codespaces(data) {
      Some(entries) => entries
      None => []
    },
    usecmap: pdf_text_parse_cmap_usecmap(data),
    wmode: pdf_text_parse_cmap_wmode(data),
    cmap_name: pdf_text_parse_cmap_name_after_token(data, "/CMapName"),
    cmap_type: pdf_text_parse_cmap_int_after_token(data, "/CMapType"),
    cid_system_info: pdf_text_parse_cmap_cid_system_info(data),
  }
}

///|
fn pdf_text_tounicode_has_charcode(
  entries : ArrayView[(Int, PdfBytes)],
  code : Int,
) -> Bool {
  for entry in entries {
    if entry.0 == code {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_text_compose_tounicode_entries(
  current : ArrayView[(Int, PdfBytes)],
  inherited : ArrayView[(Int, PdfBytes)],
) -> Array[(Int, PdfBytes)] {
  let output : Array[(Int, PdfBytes)] = Array::new(
    capacity=current.length() + inherited.length(),
  )
  let seen : @hashmap.HashMap[Int, Bool] = HashMap([])
  for entry in current {
    output.push(entry)
    seen[entry.0] = true
  }
  for entry in inherited {
    if !seen.contains(entry.0) {
      seen[entry.0] = true
      output.push(entry)
    }
  }
  output
}

///|
fn pdf_text_compose_cid_entries(
  current : ArrayView[(Int, Int)],
  inherited : ArrayView[(Int, Int)],
) -> Array[(Int, Int)] {
  let output : Array[(Int, Int)] = Array::new(
    capacity=current.length() + inherited.length(),
  )
  let seen : @hashmap.HashMap[Int, Bool] = HashMap([])
  for entry in current {
    output.push(entry)
    seen[entry.0] = true
  }
  for entry in inherited {
    if !seen.contains(entry.0) {
      seen[entry.0] = true
      output.push(entry)
    }
  }
  output
}

///|
fn pdf_text_compose_codespaces(
  current : ArrayView[PdfCMapCodeSpace],
  inherited : ArrayView[PdfCMapCodeSpace],
) -> Array[PdfCMapCodeSpace] {
  let output : Array[PdfCMapCodeSpace] = Array::new(
    capacity=current.length() + inherited.length(),
  )
  for entry in current {
    output.push(entry)
  }
  for entry in inherited {
    output.push(entry)
  }
  output
}

///|
fn pdf_text_compose_parsed_cmap(
  current : PdfParsedCMap,
  inherited : PdfParsedCMap,
) -> PdfParsedCMap {
  {
    map: pdf_text_compose_tounicode_entries(current.map, inherited.map),
    cid_map: pdf_text_compose_cid_entries(current.cid_map, inherited.cid_map),
    notdef_map: pdf_text_compose_cid_entries(
      current.notdef_map,
      inherited.notdef_map,
    ),
    codespaces: pdf_text_compose_codespaces(
      current.codespaces,
      inherited.codespaces,
    ),
    usecmap: match current.usecmap {
      Some(_) => current.usecmap
      None => inherited.usecmap
    },
    wmode: match current.wmode {
      Some(_) => current.wmode
      None => inherited.wmode
    },
    cmap_name: match current.cmap_name {
      Some(_) => current.cmap_name
      None => inherited.cmap_name
    },
    cmap_type: match current.cmap_type {
      Some(_) => current.cmap_type
      None => inherited.cmap_type
    },
    cid_system_info: match current.cid_system_info {
      Some(_) => current.cid_system_info
      None => inherited.cid_system_info
    },
  }
}

///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_wmode(
  self : PdfDocument,
  stream_object : PdfObject,
) -> Int? {
  match self.lookup_direct(pdf_text_wmode_key_name, stream_object) {
    Some(PdfInteger(value)) => Some(value)
    _ => None
  }
}

///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_cmap_name(
  self : PdfDocument,
  stream_object : PdfObject,
) -> PdfName? {
  match self.lookup_direct(pdf_text_cmap_name_key_name, stream_object) {
    Some(PdfNameObject(name)) => Some(name)
    _ => None
  }
}

///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_cmap_type(
  self : PdfDocument,
  stream_object : PdfObject,
) -> Int? {
  match self.lookup_direct(pdf_text_cmap_type_key_name, stream_object) {
    Some(PdfInteger(value)) => Some(value)
    _ => None
  }
}

///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_usecmap_name(
  self : PdfDocument,
  stream_object : PdfObject,
) -> PdfName? {
  match self.lookup_direct(pdf_text_usecmap_key_name, stream_object) {
    Some(PdfNameObject(name)) => Some(name)
    _ => None
  }
}

///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_cid_system_info(
  self : PdfDocument,
  stream_object : PdfObject,
) -> PdfCIDSystemInfo? {
  match self.lookup_direct(pdf_text_cid_system_info_key_name, stream_object) {
    Some(value) =>
      try self.read_cid_system_info(value) catch {
        _ => None
      } noraise {
        info => Some(info)
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_text_apply_cmap_stream_dictionary_metadata(
  self : PdfDocument,
  stream_object : PdfObject,
  parsed : PdfParsedCMap,
) -> PdfParsedCMap {
  {
    ..parsed,
    usecmap: match parsed.usecmap {
      Some(_) => parsed.usecmap
      None => self.pdf_text_cmap_stream_dictionary_usecmap_name(stream_object)
    },
    wmode: match parsed.wmode {
      Some(_) => parsed.wmode
      None => self.pdf_text_cmap_stream_dictionary_wmode(stream_object)
    },
    cmap_name: match parsed.cmap_name {
      Some(_) => parsed.cmap_name
      None => self.pdf_text_cmap_stream_dictionary_cmap_name(stream_object)
    },
    cmap_type: match parsed.cmap_type {
      Some(_) => parsed.cmap_type
      None => self.pdf_text_cmap_stream_dictionary_cmap_type(stream_object)
    },
    cid_system_info: match parsed.cid_system_info {
      Some(_) => parsed.cid_system_info
      None =>
        self.pdf_text_cmap_stream_dictionary_cid_system_info(stream_object)
    },
  }
}

///|
fn PdfDocument::pdf_text_decoded_cmap_stream_data_direct(
  self : PdfDocument,
  object : PdfObject,
) -> PdfBytes raise PdfError {
  match self.direct(object) {
    PdfStreamObject(stream) => {
      let decoded = match
        self.pdf_stream_first_filter_direct(stream.dictionary) {
        None => stream
        Some(_) => self.pdf_decode_stream_value_direct(stream)
      }
      pdf_stream_data_bytes(decoded.data)
    }
    _ => raise CMapEncodingExpected
  }
}

///|
fn PdfDocument::parse_cmap_with_seen(
  self : PdfDocument,
  cmap : PdfObject,
  seen : @hashmap.HashMap[Int, Bool],
) -> PdfParsedCMap raise PdfError {
  match cmap {
    PdfIndirect(number) => {
      guard !seen.contains(number) else { raise CMapEncodingExpected }
      seen[number] = true
    }
    _ => ()
  }
  let bytes = self.pdf_text_decoded_cmap_stream_data_direct(cmap)
  let stream_object = self.direct(cmap)
  let parsed = self.pdf_text_apply_cmap_stream_dictionary_metadata(
    stream_object,
    pdf_parse_cmap_data(bytes),
  )
  match
    (parsed.usecmap, stream_object.lookup_immediate(pdf_text_usecmap_key_name)) {
    (None, Some(base)) =>
      match base {
        PdfIndirect(_) | PdfStreamObject(_) =>
          try self.parse_cmap_with_seen(base, seen) catch {
            _ => parsed
          } noraise {
            inherited => pdf_text_compose_parsed_cmap(parsed, inherited)
          }
        _ => parsed
      }
    _ => parsed
  }
}

///|
/// Decode and parse a CMap stream object in this document.
///
/// The stream is decoded through its first filter, stream-dictionary metadata
/// is merged with parsed metadata, and indirect `/UseCMap` bases are composed
/// with cycle protection. Malformed or non-stream inputs raise `PdfError`.
pub fn PdfDocument::parse_cmap(
  self : PdfDocument,
  cmap : PdfObject,
) -> PdfParsedCMap raise PdfError {
  self.parse_cmap_with_seen(cmap, HashMap([]))
}

///|
/// Compatibility wrapper for `PdfDocument::parse_cmap`.
pub fn pdf_parse_cmap(
  document : PdfDocument,
  cmap : PdfObject,
) -> PdfParsedCMap raise PdfError {
  document.parse_cmap(cmap)
}
