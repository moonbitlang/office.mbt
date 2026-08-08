///|
// Pagination: stack laid-out paragraphs into the section's content box,
// breaking pages under widow/orphan control and keep rules, and assemble
// the final page-model IR with absolute coordinates and interned fonts.

///|
/// Section geometry, in points (the DOCX frontend converts from twips).
pub(all) struct SectionProps {
  page_width_pt : Double
  page_height_pt : Double
  margin_top_pt : Double
  margin_right_pt : Double
  margin_bottom_pt : Double
  margin_left_pt : Double
} derive(Eq, Debug, ToJson)

///|
/// Word's defaults: US Letter (8.5×11in) with 1in margins.
pub fn SectionProps::default() -> SectionProps {
  {
    page_width_pt: 612,
    page_height_pt: 792,
    margin_top_pt: 72,
    margin_right_pt: 72,
    margin_bottom_pt: 72,
    margin_left_pt: 72,
  }
}

///|
/// One block of document flow. Keep flags mirror Word's paragraph
/// pagination properties: `keep_lines` forbids splitting the paragraph,
/// `keep_next` glues it to the start of the following block, and
/// `widow_control` enforces at least two lines on each side of a split.
pub(all) enum Block {
  Paragraph(
    input~ : @paragraph.ParagraphInput,
    keep_lines~ : Bool,
    keep_next~ : Bool,
    widow_control~ : Bool
  )
  PageBreak
} derive(Eq, Debug, ToJson)

///|
/// A paragraph block with Word's defaults (widow control on, no keeps).
pub fn Block::paragraph(
  input : @paragraph.ParagraphInput,
  keep_lines? : Bool = false,
  keep_next? : Bool = false,
  widow_control? : Bool = true,
) -> Block {
  Paragraph(input~, keep_lines~, keep_next~, widow_control~)
}

///|
priv struct LineSlot {
  rel_baseline_pt : Double // baseline within this slot
  height_pt : Double
  runs : Array[@paragraph.PlacedRun]
}

///|
priv struct LaidParagraph {
  slots : Array[LineSlot]
  space_before_pt : Double
  space_after_pt : Double
  keep_lines : Bool
  keep_next : Bool
  widow_control : Bool
}

///|
fn lay_blocks(
  blocks : Array[Block],
  content_width : Double,
) -> Array[LaidParagraph?] {
  // None marks an explicit page break
  let out : Array[LaidParagraph?] = []
  for block in blocks {
    match block {
      PageBreak => out.push(None)
      Paragraph(input~, keep_lines~, keep_next~, widow_control~) => {
        let layout = @paragraph.layout_paragraph(input, content_width)
        let slots : Array[LineSlot] = []
        let mut top = input.style.space_before_pt
        for line in layout.lines {
          slots.push({
            rel_baseline_pt: line.baseline_pt - top,
            height_pt: line.height_pt,
            runs: line.runs,
          })
          top += line.height_pt
        }
        out.push(
          Some({
            slots,
            space_before_pt: input.style.space_before_pt,
            space_after_pt: input.style.space_after_pt,
            keep_lines,
            keep_next,
            widow_control,
          }),
        )
      }
    }
  }
  out
}

///|
priv struct PageCursor {
  model : @pagelayout.PageModel
  section : SectionProps
  pages : Array[@pagelayout.Page]
  mut y : Double // next free y within the content box, from page top
}

///|
fn PageCursor::current(self : PageCursor) -> @pagelayout.Page {
  self.pages[self.pages.length() - 1]
}

///|
fn PageCursor::remaining(self : PageCursor) -> Double {
  self.section.page_height_pt - self.section.margin_bottom_pt - self.y
}

///|
fn PageCursor::at_page_top(self : PageCursor) -> Bool {
  self.y == self.section.margin_top_pt
}

///|
fn PageCursor::break_page(self : PageCursor) -> Unit {
  self.pages.push({
    width_pt: self.section.page_width_pt,
    height_pt: self.section.page_height_pt,
    items: [],
  })
  self.y = self.section.margin_top_pt
}

///|
fn PageCursor::place_slot(self : PageCursor, slot : LineSlot) -> Unit {
  let page = self.current()
  let baseline = self.y + slot.rel_baseline_pt
  for run in slot.runs {
    let font = self.model.add_font(run.font)
    page.items.push(
      Text({
        font,
        size_pt: run.size_pt,
        x_pt: self.section.margin_left_pt + run.x_pt,
        baseline_pt: baseline,
        text: run.text,
        advances_pt: run.advances_pt,
        color: run.color,
      }),
    )
  }
  self.y += slot.height_pt
}

///|
/// How many of `para`'s slots starting at `start` fit into `room` points,
/// and their total height.
fn fitting_lines(
  para : LaidParagraph,
  start : Int,
  room : Double,
) -> (Int, Double) {
  let mut used = 0.0
  let mut n = 0
  for i in start..<para.slots.length() {
    let next = used + para.slots[i].height_pt
    if next > room + 0.0001 {
      break
    }
    used = next
    n += 1
  }
  (n, used)
}

///|
/// Paginate `blocks` into `section`'s content box, honoring explicit page
/// breaks, keep-lines, keep-next, and 2/2 widow-orphan control.
/// Space-before is suppressed for paragraphs that start at the top of a
/// page (Word's behavior at automatic breaks).
pub fn paginate(
  blocks : Array[Block],
  section? : SectionProps = SectionProps::default(),
) -> @pagelayout.PageModel {
  let cursor = PageCursor::{
    model: @pagelayout.PageModel::new(),
    section,
    pages: [],
    y: section.margin_top_pt,
  }
  cursor.break_page()
  let paras = lay_blocks(
    blocks,
    section.page_width_pt - section.margin_left_pt - section.margin_right_pt,
  )
  for index, entry in paras {
    let para = match entry {
      None => {
        cursor.break_page()
        continue
      }
      Some(p) => p
    }
    let total = para.slots.length()
    if total == 0 {
      continue
    }
    // keep-next glues this paragraph's end to the next block's first line
    let keep_next_extra = if para.keep_next && index + 1 < paras.length() {
      match paras[index + 1] {
        Some(next) =>
          match next.slots.get(0) {
            Some(first) => next.space_before_pt + first.height_pt
            None => 0.0
          }
        None => 0.0
      }
    } else {
      0.0
    }
    let mut start = 0 // first line slot not yet placed
    while start < total {
      let fresh = cursor.at_page_top()
      let lead = if start == 0 && !fresh { para.space_before_pt } else { 0.0 }
      let room = cursor.remaining() - lead
      let rest = total - start
      let (by_height, height_used) = fitting_lines(para, start, room)
      let mut fit = by_height
      if fit == rest && height_used + keep_next_extra > room && !fresh {
        // whole paragraph fits but its keep-next companion would not:
        // move the paragraph (Word glues it to the next block's start)
        cursor.break_page()
        continue
      }
      if fit < rest {
        // the paragraph must split (or move)
        if para.keep_lines {
          if !fresh {
            cursor.break_page()
            continue
          }
          fit = rest // taller than an empty page: place and overflow
        } else if para.widow_control {
          // orphans: at least two lines before the break
          if start == 0 && fit < 2 && !fresh {
            cursor.break_page()
            continue
          }
          // widows: at least two lines after the break
          if rest - fit == 1 && fit > 0 {
            fit -= 1
          }
          if fit == 0 {
            if !fresh {
              cursor.break_page()
              continue
            }
            fit = 1 // nothing ever fits: force progress line by line
          }
        } else if fit == 0 {
          if !fresh {
            cursor.break_page()
            continue
          }
          fit = 1
        }
      }
      cursor.y += lead
      for i in start..<(start + fit) {
        cursor.place_slot(para.slots[i])
      }
      start += fit
      if start < total {
        cursor.break_page()
      }
    }
    cursor.y += para.space_after_pt
  }
  for page in cursor.pages {
    cursor.model.pages.push(page)
  }
  cursor.model
}
