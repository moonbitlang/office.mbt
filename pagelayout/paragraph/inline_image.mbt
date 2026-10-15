///|
/// An inline image replaces one U+FFFC code unit in a paragraph's text.
/// Offsets are relative to the concatenated runs and dimensions are points.
pub(all) struct InlineImage {
  offset_utf16 : Int32
  width_pt : Double
  height_pt : Double
  data : Bytes
  mime : String
} derive(Eq, Debug, ToJson)

///|
#deprecated("call via the trait")
pub extend InlineImage with @debug.Debug::{to_repr}

///|
#deprecated("call via the trait")
pub extend InlineImage with Eq::{equal, not_equal}

///|
#deprecated("call via the trait")
pub extend InlineImage with ToJson::{to_json}

///|
/// Image coordinates relative to the paragraph, including space before.
pub(all) struct PlacedInlineImage {
  line : Int32
  x_pt : Double
  y_pt : Double
  width_pt : Double
  height_pt : Double
  data : Bytes
  mime : String
}

///|
/// Text line boxes and the images sharing those lines.
pub(all) struct InlineParagraphLayout {
  layout : ParagraphLayout
  images : Array[PlacedInlineImage]
}
