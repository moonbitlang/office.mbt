///|
fn measure_carlito(text : String) -> @linebreak.Measured {
  @linebreak.measure(text, @fonts.face("Carlito"), 12)
}

///|
fn line_texts(
  text : String,
  lines : Array[@linebreak.LineRange],
) -> Array[String] {
  let out : Array[String] = []
  for line in lines {
    out.push(text[line.start:line.end].to_owned())
  }
  out
}

///|
test "latin text wraps at spaces greedily" {
  let text = "the quick brown fox jumps over the lazy dog"
  let m = measure_carlito(text)
  // ~90pt fits roughly three words of 12pt Carlito per line
  let lines = @linebreak.break_lines(text, m.advances_pt, 90, 90)
  json_inspect(line_texts(text, lines), content=[
    "the quick brown ", "fox jumps over ", "the lazy dog",
  ])
  // every line's visible width respects the limit
  for line in lines {
    assert_true(line.width_pt <= 90)
  }
}

///|
test "line ranges partition the text at soft breaks" {
  let text = "aaa bbb ccc ddd"
  let m = measure_carlito(text)
  let lines = @linebreak.break_lines(text, m.advances_pt, 30, 30)
  let mut expected_start = 0
  for line in lines {
    assert_eq(line.start, expected_start)
    expected_start = line.end
  }
  assert_eq(expected_start, text.length())
}

///|
test "overlong word force-breaks mid-word" {
  let text = "Pneumonoultramicroscopicsilicovolcanoconiosis"
  let m = measure_carlito(text)
  let lines = @linebreak.break_lines(text, m.advances_pt, 60, 60)
  assert_true(lines.length() > 1)
  for line in lines {
    assert_true(line.end > line.start)
  }
}

///|
test "newline is a hard break and is consumed" {
  let text = "one\ntwo"
  let m = measure_carlito(text)
  let lines = @linebreak.break_lines(text, m.advances_pt, 500, 500)
  json_inspect(line_texts(text, lines), content=["one", "two"])
}

///|
test "trailing spaces hang without counting toward width" {
  let text = "ab   "
  let m = measure_carlito(text)
  let lines = @linebreak.break_lines(text, m.advances_pt, 500, 500)
  assert_eq(lines.length(), 1)
  let bare = measure_carlito("ab")
  let mut bare_width = 0.0
  for a in bare.advances_pt {
    bare_width += a
  }
  assert_eq(lines[0].width_pt, bare_width)
  assert_eq(lines[0].end, text.length())
}

///|
test "cjk text breaks between ideographs" {
  let text = "汉字排版引擎测试"
  let cjk = @fonts.cjk_fallback()
  let m = @linebreak.measure(text, cjk, 12)
  // each han char is 12pt wide; a 40pt line fits three
  let lines = @linebreak.break_lines(text, m.advances_pt, 40, 40)
  json_inspect(line_texts(text, lines), content=[
    "汉字排", "版引擎", "测试",
  ])
}

///|
test "kinsoku forbids line-starting closing punctuation" {
  let text = "汉字排版。引擎"
  let cjk = @fonts.cjk_fallback()
  let m = @linebreak.measure(text, cjk, 12)
  // 48pt fits exactly four han columns; the ideographic full stop must
  // not start a line, so the break backs off to before 版
  let lines = @linebreak.break_lines(text, m.advances_pt, 48, 48)
  let texts = line_texts(text, lines)
  json_inspect(texts, content=["汉字排", "版。引擎"])
  for t in texts {
    assert_true(t.length() > 0)
    assert_false(t[0].to_int() == '。'.to_int())
  }
}

///|
test "kinsoku forbids line-ending opening punctuation" {
  let text = "汉字排「引擎」"
  let cjk = @fonts.cjk_fallback()
  let m = @linebreak.measure(text, cjk, 12)
  let lines = @linebreak.break_lines(text, m.advances_pt, 48, 48)
  let texts = line_texts(text, lines)
  json_inspect(texts, content=["汉字排", "「引擎」"])
  for t in texts {
    assert_true(t.length() > 0)
    assert_false(t[t.length() - 1].to_int() == '「'.to_int())
  }
}

///|
test "mixed latin and cjk breaks at the script boundary" {
  let text = "engine引擎test"
  let m = measure_carlito(text)
  // fallback marks the han characters
  assert_false(m.fallback[0])
  assert_true(m.fallback[6])
  let lines = @linebreak.break_lines(text, m.advances_pt, 45, 45)
  json_inspect(line_texts(text, lines), content=["engine引", "擎test"])
}

///|
test "first line width differs from the rest" {
  let text = "aaa bbb ccc ddd eee"
  let m = measure_carlito(text)
  // narrow first line (one word), wide rest
  let lines = @linebreak.break_lines(text, m.advances_pt, 25, 200)
  assert_true(lines.length() == 2)
  assert_true(lines[0].end < 5)
}

///|
test "surrogate pairs measure on the lead unit and never split" {
  let text = "a𝄞b" // U+1D11E musical symbol, outside the BMP
  let m = measure_carlito(text)
  assert_eq(m.advances_pt.length(), 4)
  assert_eq(m.advances_pt[2], 0) // trail unit carries no advance
  let lines = @linebreak.break_lines(text, m.advances_pt, 0.1, 0.1)
  for line in lines {
    // a break inside the pair would put the trail unit at a line start
    let first = text[line.start].to_int()
    assert_false(first >= 0xDC00 && first <= 0xDFFF)
  }
}

///|
test "empty text yields one empty line" {
  let lines = @linebreak.break_lines("", [], 100, 100)
  assert_eq(lines.length(), 1)
  assert_eq(lines[0].width_pt, 0)
}
