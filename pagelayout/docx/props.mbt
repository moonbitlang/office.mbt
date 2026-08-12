///|
// Partially-specified OOXML formatting. Every field is optional so the
// style cascade can layer docDefaults → style chain → direct formatting
// by overlaying "what this level says" onto "what lower levels said".

///|
/// Character formatting as authored at one cascade level.
pub(all) struct RunProps {
  family : String?
  size : @pagelayout.HalfPoints?
  bold : Bool?
  italic : Bool?
  color : @pagelayout.Color?
} derive(Eq, Debug, ToJson)

///|
/// Formatting that specifies nothing — the identity for `merge`.
pub fn RunProps::empty() -> RunProps {
  { family: None, size: None, bold: None, italic: None, color: None }
}

///|
/// Overlay `over` onto `self`: every field `over` specifies wins.
pub fn RunProps::merge(self : RunProps, over : RunProps) -> RunProps {
  {
    family: if over.family is Some(_) {
      over.family
    } else {
      self.family
    },
    size: if over.size is Some(_) {
      over.size
    } else {
      self.size
    },
    bold: if over.bold is Some(_) {
      over.bold
    } else {
      self.bold
    },
    italic: if over.italic is Some(_) {
      over.italic
    } else {
      self.italic
    },
    color: if over.color is Some(_) {
      over.color
    } else {
      self.color
    },
  }
}

///|
/// Resolve to the layout engine's run style, filling anything still
/// unspecified after the whole cascade (Calibri, 10pt, regular, black).
///
/// The size deserves its comment, because 11pt looks like the right
/// answer and is not. 11pt is what recent Word templates write into
/// `docDefaults` *explicitly* (`w:sz="22"`) — a document carrying that
/// never reaches this fallback. OOXML itself prescribes nothing for a
/// hierarchy that is silent all the way down; the consumer chooses, and
/// LibreOffice — the reference renderer the fidelity harness can run —
/// chooses 10pt, read from its own content stream (`10 Tf`, no scaling
/// transform). The corpus's technical manual is exactly such a document:
/// at 11pt, 94.5% of its 20,216 comparable words fell in the 1.10
/// width-ratio bucket, compounding to 56 pages against 48. Switching
/// this constant erased that mode entirely — 0% of 20,331 comparable
/// words after — so the constant accounts for the whole mode.
pub fn RunProps::resolve(self : RunProps) -> @paragraph.RunStyle {
  {
    family: self.family.unwrap_or("Calibri"),
    size_pt: match self.size {
      Some(hp) => hp.to_pt()
      None => 10.0
    },
    bold: self.bold.unwrap_or(false),
    italic: self.italic.unwrap_or(false),
    color: self.color.unwrap_or(@pagelayout.black),
  }
}

///|
/// Paragraph formatting as authored at one cascade level. Indents and
/// spacing stay in twips until resolution.
pub(all) struct ParaProps {
  align : @paragraph.Alignment?
  indent_left : @pagelayout.Twips?
  indent_right : @pagelayout.Twips?
  indent_first : @pagelayout.Twips?
  space_before : @pagelayout.Twips?
  space_after : @pagelayout.Twips?
  line_spacing : @paragraph.LineSpacing?
  keep_lines : Bool?
  keep_next : Bool?
  widow_control : Bool?
  page_break_before : Bool?
  /// `w:numPr`: the list instance and level this paragraph belongs to.
  num_id : Int?
  num_level : Int?
  /// `w:tabs`, in authored order.
  tabs : Array[@paragraph.TabStop]?
} derive(Eq, Debug, ToJson)

///|
/// Formatting that specifies nothing — the identity for `merge`.
pub fn ParaProps::empty() -> ParaProps {
  {
    align: None,
    indent_left: None,
    indent_right: None,
    indent_first: None,
    space_before: None,
    space_after: None,
    line_spacing: None,
    keep_lines: None,
    keep_next: None,
    widow_control: None,
    page_break_before: None,
    num_id: None,
    num_level: None,
    tabs: None,
  }
}

///|
/// Overlay `over` onto `self`: every field `over` specifies wins.
pub fn ParaProps::merge(self : ParaProps, over : ParaProps) -> ParaProps {
  {
    align: if over.align is Some(_) {
      over.align
    } else {
      self.align
    },
    indent_left: if over.indent_left is Some(_) {
      over.indent_left
    } else {
      self.indent_left
    },
    indent_right: if over.indent_right is Some(_) {
      over.indent_right
    } else {
      self.indent_right
    },
    indent_first: if over.indent_first is Some(_) {
      over.indent_first
    } else {
      self.indent_first
    },
    space_before: if over.space_before is Some(_) {
      over.space_before
    } else {
      self.space_before
    },
    space_after: if over.space_after is Some(_) {
      over.space_after
    } else {
      self.space_after
    },
    line_spacing: if over.line_spacing is Some(_) {
      over.line_spacing
    } else {
      self.line_spacing
    },
    keep_lines: if over.keep_lines is Some(_) {
      over.keep_lines
    } else {
      self.keep_lines
    },
    keep_next: if over.keep_next is Some(_) {
      over.keep_next
    } else {
      self.keep_next
    },
    widow_control: if over.widow_control is Some(_) {
      over.widow_control
    } else {
      self.widow_control
    },
    page_break_before: if over.page_break_before is Some(_) {
      over.page_break_before
    } else {
      self.page_break_before
    },
    num_id: if over.num_id is Some(_) {
      over.num_id
    } else {
      self.num_id
    },
    num_level: if over.num_level is Some(_) {
      over.num_level
    } else {
      self.num_level
    },
    tabs: if over.tabs is Some(_) {
      over.tabs
    } else {
      self.tabs
    },
  }
}

///|
fn twips_pt(v : @pagelayout.Twips?) -> Double {
  match v {
    Some(t) => t.to_pt()
    None => 0.0
  }
}

///|
/// Resolve to the layout engine's paragraph style. Word's defaults apply
/// to anything unspecified: left-aligned, no indents or spacing, single
/// line spacing.
pub fn ParaProps::resolve(
  self : ParaProps,
  default_tab_pt? : Double = 36.0,
) -> @paragraph.ParagraphStyle {
  // The implicit hanging-indent tab stop is NOT inserted here: a
  // numbering level's indents can still override these after resolution,
  // and a stop derived from superseded indents would linger in the ruler
  // for a mid-paragraph tab to hit. The reader applies
  // ParagraphStyle::with_hanging_tab_stop once, where indents are final.
  let resolved = @paragraph.ParagraphStyle::{
    align: self.align.unwrap_or(AlignLeft),
    indent_left_pt: twips_pt(self.indent_left),
    indent_right_pt: twips_pt(self.indent_right),
    indent_first_pt: twips_pt(self.indent_first),
    space_before_pt: twips_pt(self.space_before),
    space_after_pt: twips_pt(self.space_after),
    line_spacing: self.line_spacing.unwrap_or(Single),
    tabs: {
      // Sorted by position: the ruler returns the first qualifying stop
      // in array order, so an unsorted list — legal in a hand-built
      // document even though Word writes ascending — would make a tab
      // skip a nearer stop for a farther one that merely sorts earlier.
      stops: self.tabs
      .unwrap_or([])
      .copy()
      ..sort_by((a, b) => a.position_pt.compare(b.position_pt)),
      default_interval_pt: default_tab_pt,
    },
  }
  resolved
}
