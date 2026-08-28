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
  /// `w:pgMar w:header` — distance from the page's top edge to the top
  /// of the header, which sits above the body's top margin.
  header_pt : Double
  /// `w:pgMar w:footer` — distance from the page's bottom edge to the
  /// bottom of the footer.
  footer_pt : Double
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
    header_pt: 36,
    footer_pt: 36,
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
  /// A table. `keep_next` glues it to the block that follows, as for a
  /// paragraph; rows split across pages unless a row says `cant_split`,
  /// and `w:tblHeader` rows repeat on each continuation.
  TableBlock(table~ : @table.Table, keep_next~ : Bool)
  /// An image occupying its own block, at its authored size scaled down
  /// to fit the measure. Images are atomic: one that does not fit the
  /// remaining space moves to the next page.
  ImageBlock(
    width_pt~ : Double,
    height_pt~ : Double,
    data~ : Bytes,
    mime~ : String
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
/// A table block with Word's defaults.
pub fn Block::table(table : @table.Table, keep_next? : Bool = false) -> Block {
  TableBlock(table~, keep_next~)
}

///|
/// An image block at its authored size.
pub fn Block::image(
  width_pt : Double,
  height_pt : Double,
  data : Bytes,
  mime : String,
) -> Block {
  ImageBlock(width_pt~, height_pt~, data~, mime~)
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
/// A table measured against the content width, plus its keep rule.
priv struct LaidTable {
  layout : @table.TableLayoutResult
  keep_next : Bool
}

///|
/// One block after measurement, ready to place.
priv struct LaidImage {
  width : Double
  height : Double
  data : Bytes
  mime : String
}

///|
priv enum LaidBlock {
  LaidPara(LaidParagraph)
  LaidTbl(LaidTable)
  LaidImg(LaidImage)
  LaidBreak
}

///|
fn lay_blocks(
  blocks : Array[Block],
  content_width : Double,
) -> Array[LaidBlock] {
  let out : Array[LaidBlock] = []
  for block in blocks {
    match block {
      PageBreak => out.push(LaidBreak)
      TableBlock(table~, keep_next~) =>
        out.push(
          LaidTbl({
            layout: @table.layout_table(table, content_width),
            keep_next,
          }),
        )
      ImageBlock(width_pt~, height_pt~, data~, mime~) => {
        // an image wider than the measure scales down, keeping its
        // aspect ratio, as Word does
        let scale = if width_pt > content_width && width_pt > 0.0 {
          content_width / width_pt
        } else {
          1.0
        }
        out.push(
          LaidImg({
            width: width_pt * scale,
            height: height_pt * scale,
            data,
            mime,
          }),
        )
      }
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
          LaidPara({
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
/// How much room the start of `block` needs, for keep-next lookahead:
/// a paragraph's space-before plus its first line, or a table's first
/// row.
fn block_head_height(block : LaidBlock) -> Double {
  match block {
    LaidBreak => 0.0
    LaidPara(p) =>
      match p.slots.get(0) {
        Some(first) => p.space_before_pt + first.height_pt
        None => 0.0
      }
    LaidTbl(t) =>
      match t.layout.rows.get(0) {
        Some(first) => first.height_pt
        None => 0.0
      }
    LaidImg(image) => image.height
  }
}

///|
/// Place a table, splitting between rows when it does not fit. A row
/// marked `cant_split` moves whole to the next page rather than being
/// broken; `w:tblHeader` rows repeat at the top of each continuation.
fn place_table(
  cursor : PageCursor,
  tbl : LaidTable,
  blocks : Array[LaidBlock],
  index : Int,
) -> Unit {
  let layout = tbl.layout
  let total = layout.rows.length()
  if total == 0 {
    return
  }
  let keep_next_extra = if tbl.keep_next && index + 1 < blocks.length() {
    block_head_height(blocks[index + 1])
  } else {
    0.0
  }
  let mut start = 0
  while start < total {
    let continuation = start > 0
    let header_height = if continuation {
      @table.rows_height_pt(layout, start, start, repeat_header=true)
    } else {
      0.0
    }
    let room = cursor.remaining() - header_height
    // how many rows fit
    let mut fit = 0
    let mut used = 0.0
    for i in start..<total {
      let next = used + layout.rows[i].height_pt
      if next > room + 0.0001 {
        break
      }
      used = next
      fit += 1
    }
    // the tail must also leave room for a keep-next companion
    if fit == total - start &&
      used + keep_next_extra > room &&
      !cursor.at_page_top() {
      cursor.break_page()
      continue
    }
    if fit == 0 {
      if !cursor.at_page_top() {
        cursor.break_page()
        continue
      }
      // a single row taller than an empty page: place it and overflow
      fit = 1
    }
    // rows are atomic in this engine — a row's lines are never split
    // across pages — so `w:cantSplit` is already satisfied by placing
    // whole rows. It becomes meaningful when cell content itself can
    // break, which is a later milestone.
    let items = @table.emit_rows(
      cursor.model,
      layout,
      cursor.section.margin_left_pt,
      cursor.y,
      start,
      start + fit,
      repeat_header=continuation,
    )
    let page = cursor.current()
    for item in items {
      page.items.push(item)
    }
    cursor.y += header_height + used
    start += fit
    if start < total {
      cursor.break_page()
    }
  }
}

///|
/// Paginate `blocks` into `section`'s content box, honoring explicit page
/// breaks, keep-lines, keep-next, and 2/2 widow-orphan control.
/// Space-before is suppressed for paragraphs that start at the top of a
/// page (Word's behavior at automatic breaks).
/// A header or footer: blocks repeated on every page of the section.
pub(all) struct PageFurniture {
  header : Array[Block]
  footer : Array[Block]
  /// What page one carries when `title_page` is set. Empty means the page
  /// carries nothing — a title page with no running head is the usual
  /// reason a document sets `w:titlePg` at all, so an empty first-page
  /// variant is a real choice rather than a missing one.
  first_header : Array[Block]
  first_footer : Array[Block]
  /// What even-numbered pages carry when `even_and_odd` is set.
  even_header : Array[Block]
  even_footer : Array[Block]
  /// `w:titlePg`: whether page one takes the first-page variants.
  title_page : Bool
  /// `w:evenAndOddHeaders`: whether even pages take the even variants.
  even_and_odd : Bool
} derive(Eq, Debug, ToJson)

///|
/// No running header or footer.
pub fn PageFurniture::none() -> PageFurniture {
  {
    header: [],
    footer: [],
    first_header: [],
    first_footer: [],
    even_header: [],
    even_footer: [],
    title_page: false,
    even_and_odd: false,
  }
}

///|
/// The header and footer a given page carries, by zero-based index.
fn PageFurniture::for_page(
  self : PageFurniture,
  index : Int,
) -> (Array[Block], Array[Block]) {
  // page numbers are 1-based, so an even page is an odd index
  if self.title_page && index == 0 {
    (self.first_header, self.first_footer)
  } else if self.even_and_odd && index % 2 == 1 {
    (self.even_header, self.even_footer)
  } else {
    (self.header, self.footer)
  }
}

///|
/// Lay the furniture out once and stamp it onto every page. The header
/// hangs from `header_pt` below the page top; the footer's *bottom* sits
/// `footer_pt` above the page bottom, so it grows upward as it gets
/// taller — which is how Word anchors them.
fn stamp_furniture(
  model : @pagelayout.PageModel,
  section : SectionProps,
  furniture : PageFurniture,
) -> Unit {
  let width = section.page_width_pt -
    section.margin_left_pt -
    section.margin_right_pt
  // Furniture holding a PAGE or NUMPAGES field renders differently on
  // every page, so it is laid out per page; furniture without fields is
  // laid out once and reused, which is the common case.
  let total = model.pages.length()
  // A title page carries different blocks from the rest, so the layout
  // cannot be shared across that boundary however static the content is.
  let varies = furniture_varies(furniture) ||
    furniture.title_page ||
    furniture.even_and_odd
  let (first_header, first_footer) = furniture.for_page(0)
  let mut header_items = furniture_items(model, first_header, width, 1, total)
  let mut footer_items = furniture_items(model, first_footer, width, 1, total)
  let mut footer_top = section.page_height_pt -
    section.footer_pt -
    furniture_height(footer_items)
  for index, page in model.pages {
    if varies && index > 0 {
      let (header, footer) = furniture.for_page(index)
      header_items = furniture_items(model, header, width, index + 1, total)
      footer_items = furniture_items(model, footer, width, index + 1, total)
      footer_top = section.page_height_pt -
        section.footer_pt -
        furniture_height(footer_items)
    }
    for entry in header_items {
      let (dy, item) = entry
      page.items.push(
        offset_item(item, section.margin_left_pt, section.header_pt + dy),
      )
    }
    for entry in footer_items {
      let (dy, item) = entry
      page.items.push(
        offset_item(item, section.margin_left_pt, footer_top + dy),
      )
    }
  }
}

///|
/// Lay furniture blocks out at `width`, returning each item with its y
/// offset from the furniture's own top edge.
fn furniture_items(
  model : @pagelayout.PageModel,
  blocks : Array[Block],
  width : Double,
  page_number : Int,
  page_count : Int,
) -> Array[(Double, @pagelayout.PageItem)] {
  let out : Array[(Double, @pagelayout.PageItem)] = []
  // paragraphs stack, so each one's lines are offset by what came before
  let mut y = 0.0
  for block in blocks {
    match block {
      Paragraph(input~, ..) => {
        // a PAGE or NUMPAGES run takes the real value here, where the
        // page is finally known
        let resolved = if input.has_fields() {
          let runs : Array[@paragraph.RunInput] = []
          for run in input.runs {
            runs.push(run.evaluate(page_number, page_count))
          }
          @paragraph.ParagraphInput::{ ..input, runs, }
        } else {
          input
        }
        let laid = @paragraph.layout_paragraph(resolved, width)
        for line in laid.lines {
          for run in line.runs {
            let font = model.add_font(run.font)
            out.push(
              (
                y + line.baseline_pt,
                Text({
                  font,
                  size_pt: run.size_pt,
                  x_pt: run.x_pt,
                  baseline_pt: 0,
                  text: run.text,
                  advances_pt: run.advances_pt,
                  color: run.color,
                }),
              ),
            )
          }
        }
        y += laid.height_pt
      }
      // Word often builds a header from a table
      TableBlock(table~, ..) => {
        let laid = @table.layout_table(table, width)
        let items = @table.emit_rows(model, laid, 0, y, 0, laid.rows.length())
        for item in items {
          match item {
            Text(run) => out.push((run.baseline_pt, Text(run)))
            other => out.push((0, other))
          }
        }
        y += laid.height_pt
      }
      // an image in a header or footer sits at the furniture's origin
      ImageBlock(width_pt~, height_pt~, data~, mime~) => {
        out.push(
          (
            0,
            Image({
              x_pt: 0,
              y_pt: y,
              w_pt: width_pt,
              h_pt: height_pt,
              data,
              mime,
            }),
          ),
        )
        y += height_pt
      }
      PageBreak => ()
    }
  }
  out
}

///|
/// Whether any furniture block holds a field, and so must be laid out
/// again for each page.
fn furniture_varies(furniture : PageFurniture) -> Bool {
  for blocks in [furniture.header, furniture.footer] {
    for block in blocks {
      if block is Paragraph(input~, ..) && input.has_fields() {
        return true
      }
    }
  }
  false
}

///|
fn furniture_height(items : Array[(Double, @pagelayout.PageItem)]) -> Double {
  let mut tallest = 0.0
  for entry in items {
    let (dy, _) = entry
    if dy > tallest {
      tallest = dy
    }
  }
  tallest
}

///|
fn offset_item(
  item : @pagelayout.PageItem,
  dx : Double,
  dy : Double,
) -> @pagelayout.PageItem {
  match item {
    Text(run) => Text({ ..run, x_pt: run.x_pt + dx, baseline_pt: dy, })
    other => other
  }
}

///|
/// Paginate `blocks` into `section`'s content box, honoring explicit page
/// breaks, keep-lines, keep-next, and 2/2 widow-orphan control.
/// Space-before is suppressed for paragraphs that start at the top of a
/// page (Word's behavior at automatic breaks). `furniture` is laid out
/// once and stamped onto every page.
pub fn paginate(
  blocks : Array[Block],
  section? : SectionProps = SectionProps::default(),
  furniture? : PageFurniture = PageFurniture::none(),
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
      LaidBreak => {
        cursor.break_page()
        continue
      }
      LaidTbl(tbl) => {
        place_table(cursor, tbl, paras, index)
        continue
      }
      LaidImg(image) => {
        // atomic: move a too-tall image to a fresh page, but place it
        // anyway if it exceeds an empty page rather than looping
        if image.height > cursor.remaining() && !cursor.at_page_top() {
          cursor.break_page()
        }
        cursor.current().items.push(
          Image({
            x_pt: cursor.section.margin_left_pt,
            y_pt: cursor.y,
            w_pt: image.width,
            h_pt: image.height,
            data: image.data,
            mime: image.mime,
          }),
        )
        cursor.y += image.height
        continue
      }
      LaidPara(p) => p
    }
    let total = para.slots.length()
    if total == 0 {
      continue
    }
    // keep-next glues this paragraph's end to the next block's first line
    let keep_next_extra = if para.keep_next && index + 1 < paras.length() {
      block_head_height(paras[index + 1])
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
  stamp_furniture(cursor.model, section, furniture)
  cursor.model
}
