///|
// Structural invariants of the page-model IR that the types themselves
// cannot enforce (the IR structs are pub(all) so frontends build them as
// literals). `PageModel::validate` is the seed of the reference-free
// invariant layer from the design record: layout tests assert it returns
// no violations for every model they produce.

///|
fn check_color(violations : Array[String], where_ : String, c : Color) -> Unit {
  if c.r < 0 || c.r > 255 || c.g < 0 || c.g > 255 || c.b < 0 || c.b > 255 {
    violations.push("\{where_}: color channel out of 0..=255: \{c.to_hex()}")
  }
}

///|
/// Check every structural invariant; return one human-readable message per
/// violation (empty means the model is well-formed):
///
/// - every `GlyphRun` has exactly one advance per UTF-16 code unit of its
///   text, a non-negative size, and a font index into `fonts`;
/// - every `RectItem` has non-negative extents, and its `stroke` and
///   `stroke_w_pt` agree (both present or both absent);
/// - every color channel is within 0..=255;
/// - every page has positive extents.
pub fn PageModel::validate(self : PageModel) -> Array[String] {
  let violations : Array[String] = []
  for p, page in self.pages {
    if page.width_pt <= 0 || page.height_pt <= 0 {
      violations.push("page \{p}: non-positive page size")
    }
    for i, item in page.items {
      let where_ = "page \{p} item \{i}"
      match item {
        Text(run) => {
          if run.advances_pt.length() != run.text.length() {
            violations.push(
              "\{where_}: \{run.advances_pt.length()} advances for \{run.text.length()} UTF-16 code units",
            )
          }
          if run.font < 0 || run.font >= self.fonts.length() {
            violations.push(
              "\{where_}: font index \{run.font} outside fonts[0..\{self.fonts.length()}]",
            )
          }
          if run.size_pt <= 0 {
            violations.push("\{where_}: non-positive font size")
          }
          check_color(violations, where_, run.color)
        }
        Rect(rect) => {
          if rect.w_pt < 0 || rect.h_pt < 0 {
            violations.push("\{where_}: negative rect extent")
          }
          match rect.stroke {
            Some(stroke_color) => {
              if rect.stroke_w_pt <= 0 {
                violations.push(
                  "\{where_}: stroke color with non-positive stroke width",
                )
              }
              check_color(violations, where_, stroke_color)
            }
            None =>
              if rect.stroke_w_pt != 0 {
                violations.push("\{where_}: stroke width without stroke color")
              }
          }
          match rect.fill {
            Some(fill_color) => check_color(violations, where_, fill_color)
            None => ()
          }
          if rect.fill is None && rect.stroke is None {
            violations.push("\{where_}: rect paints nothing")
          }
        }
        Image(image) => {
          if image.w_pt <= 0 || image.h_pt <= 0 {
            violations.push("\{where_}: non-positive image extent")
          }
          if image.data.length() == 0 {
            violations.push("\{where_}: empty image data")
          }
        }
        Link(link) =>
          if link.w_pt < 0 || link.h_pt < 0 {
            violations.push("\{where_}: negative link extent")
          }
      }
    }
  }
  violations
}
