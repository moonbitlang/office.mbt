// A bounded, private reader-order view over N0b1's physical source identities,
// with story-wide complex-field classification, the reader's content-control
// and Markup Compatibility transforms, and final logical paths and UTF-16
// projection intervals. N0c consumes these ordered physical contributors,
// their source-pinned field provenance, and the `p[i]/r[j]` addresses that
// let an edit name a run.

///|
#warnings("-unused_field")
priv struct ReaderOrderSourceSpan {
  byte_start : Int
  byte_end : Int
}

///|
#warnings("-unused_value")
priv enum ProvisionalContributionKind {
  TextAtom
  TabAtom
  NoBreakHyphenAtom
  SoftHyphenAtom
  SymbolAtom
  TransparentSeam
  HardBarrier
} derive(Debug)

///|
/// One reader-visible atom or zero-width boundary. Its identity always indexes
/// `ReaderOrderProjection.source_elements`; `source_span` is a physical byte
/// range, while `projection_start`/`projection_end` locate it in the reader's
/// story and `logical_run_index` names its run.
#warnings("-unused_field-unused_mut")
priv struct ReaderOrderContribution {
  kind : ProvisionalContributionKind
  value : String
  source_identity : Int
  paragraph_identity : Int
  run_identity : Int?
  source_span : ReaderOrderSourceSpan
  mut field_identity : Int?
  mut field_region : ReaderOrderFieldRegion
  mut field_refusal : Int?
  /// Half-open interval this contribution occupies in the reader's story
  /// text, in UTF-16 code units. Assigned only after every transform and
  /// suppression decision, because a contribution the checkbox transform
  /// blanked contributes nothing and must occupy an empty interval even
  /// though its source span still names real bytes.
  ///
  /// Zero-width contributions -- seams and barriers -- get an empty interval
  /// at the position they sit, which is what makes them usable as insertion
  /// points.
  mut projection_start : Int
  mut projection_end : Int
  /// Index of this contribution's run within its reader paragraph, by order of
  /// first appearance, or -1 when it belongs to no run. With the paragraph's
  /// own index this is the `p[i]/r[j]` address surgery will edit through.
  mut logical_run_index : Int
}

///|
#warnings("-unused_field")
priv struct ReaderOrderRunSource {
  identity : Int
  source_span : ReaderOrderSourceSpan
}

///|
/// One physical paragraph contributing to a reader paragraph. Deleted
/// paragraph-mark prefixes remain separate entries here even though their
/// contents are joined into the terminal paragraph by BodyReader.
#warnings("-unused_field")
priv struct ReaderOrderParagraphSource {
  identity : Int
  source_span : ReaderOrderSourceSpan
  runs : Array[ReaderOrderRunSource]
}

///|
#warnings("-unused_field")
priv struct ReaderOrderParagraph {
  from_text_box : Bool
  sources : Array[ReaderOrderParagraphSource]
  contributions : Array[ReaderOrderContribution]
  /// Position of this paragraph in the reader's story, and the interval it
  /// occupies there. Both assigned by the legacy coordinate pass (test-only).
  mut logical_index : Int
  mut projection_start : Int
  mut projection_end : Int
}

///|
/// One direct physical paragraph child observed at the same point where
/// BodyReader begins interpreting that carrier. Keeping this event stream on
/// the N0b2 walk preserves recursive block order for N0b3 without reconstructing
/// it from the completed paragraph segments. Each event follows a charged N0b2
/// node visit, so the reader-order visit budget also bounds retained events.
priv struct ReaderOrderFieldCarrierEvent {
  paragraph_identity : Int
  carrier_identity : Int
}

///|
/// Private result. `source_part` identifies the OPC part. Physical coordinates
/// are exact source identities and byte spans; logical ones are the paragraph
/// index, run index and UTF-16 story interval assigned once every transform
/// has run.
#warnings("-unused_field")
priv struct ReaderOrderProjection {
  source_part : String
  source_elements : Array[ScannedElement]
  paragraphs : Array[ReaderOrderParagraph]
  field_carriers : Array[ReaderOrderFieldCarrierEvent]
  mut field_index : ReaderOrderFieldIndex
}

///|
let max_reader_order_node_visits : Int = 4_000_000

///|
let max_reader_order_projected_chars : Int = 64 * 1024 * 1024

///|
let max_reader_order_retained_contributors : Int = 3_000_000

///|
let max_reader_order_depth : Int = 256

///|
const READER_ORDER_VML_URI : String = "urn:schemas-microsoft-com:vml"

///|
const READER_ORDER_TRANSITIONAL_WORDPROCESSING_DRAWING_URI : String = "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"

///|
const READER_ORDER_STRICT_WORDPROCESSING_DRAWING_URI : String = "http://purl.oclc.org/ooxml/drawingml/wordprocessingDrawing"

///|
fn reader_order_element_span(element : ScannedElement) -> ReaderOrderSourceSpan {
  { byte_start: element.byte_start, byte_end: element.byte_end }
}

///|
fn reader_order_atom_span(element : ScannedElement) -> ReaderOrderSourceSpan {
  if is_wml_uri(element.uri) &&
    element.local_name == "t" &&
    element.text_map is Some(_) {
    { byte_start: element.content_start, byte_end: element.content_end }
  } else {
    reader_order_element_span(element)
  }
}
