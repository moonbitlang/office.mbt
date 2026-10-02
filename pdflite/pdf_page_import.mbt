///|
// Importing a page of another document as a Form XObject: the page's
// content and every object its resources reach are copied into the
// importing document under new object numbers, so the page can be drawn
// (scaled and placed like an image) on any page of it.

///|
fn pdf_import_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
/// A page of another document, imported as a Form XObject by
/// `PdfDocument::import_page`.
///
/// Drawn with the identity matrix, the form fills the rectangle from
/// `(0, 0)` to `(width, height)` in user space, upright: a content stream
/// draws it into a box `w` by `h` at `(x, y)` with
/// `q w/width 0 0 h/height x y cm /Name Do Q`, after adding `object` to the
/// page's `/XObject` resources under `/Name`.
pub struct PdfImportedPage {
  /// the Form XObject's object number in the importing document
  object : Int
  /// the page's width as a viewer shows it, in points
  width : Double
  /// the page's height as a viewer shows it, in points
  height : Double
} derive(Eq, Debug)

///|
/// The visible box of `page`: its crop box clipped to its media box, or
/// the media box when it has no crop box (or one outside the media box).
fn PdfDocument::pdf_import_visible_box(
  self : PdfDocument,
  page : @page.PdfPage,
) -> @geometry.PdfRectangle raise @core.PdfError {
  let media = self.parse_rectangle(page.mediabox)
  let crop = match self.lookup_direct(pdf_import_name("/CropBox"), page.rest) {
    Some(box) => Some(self.parse_rectangle(box)) catch { _ => None }
    None => None
  }
  let visible = match crop {
    Some(crop) => {
      let clipped = @geometry.PdfRectangle::{
        min_x: double_max(crop.min_x, media.min_x),
        min_y: double_max(crop.min_y, media.min_y),
        max_x: double_min(crop.max_x, media.max_x),
        max_y: double_min(crop.max_y, media.max_y),
      }
      if clipped.max_x > clipped.min_x && clipped.max_y > clipped.min_y {
        clipped
      } else {
        media
      }
    }
    None => media
  }
  let finite = (v : Double) => !(v.is_nan() || v.is_inf())
  guard finite(visible.min_x) &&
    finite(visible.min_y) &&
    finite(visible.max_x) &&
    finite(visible.max_y) &&
    visible.max_x > visible.min_x &&
    visible.max_y > visible.min_y else {
    raise BadRectangle
  }
  visible
}

///|
/// Page `page_number` (1-based) of the page tree, or
/// `BadPageSpecification` when the document has no such page.
fn PdfDocument::pdf_import_page_of_tree(
  self : PdfDocument,
  page_number : Int,
) -> @page.PdfPage raise @core.PdfError {
  let pages = self.pages_of_pagetree()
  guard page_number >= 1 && page_number <= pages.length() else {
    raise BadPageSpecification(
      "page \{page_number} of a document of \{pages.length()} pages",
    )
  }
  pages[page_number - 1]
}

///|
/// The size, in points, at which a viewer shows page `page_number`
/// (1-based): its crop box clipped to its media box (the media box when
/// it has no crop box), with width and height swapped when its `/Rotate`
/// is 90 or 270. This is the size `PdfDocument::import_page` reports.
///
/// Raises `BadPageSpecification` when the document has no such page and
/// `RectangleExpected` or `BadRectangle` when its boxes are malformed or
/// empty.
pub fn PdfDocument::page_display_size(
  self : PdfDocument,
  page_number : Int,
) -> (Double, Double) raise @core.PdfError {
  let page = self.pdf_import_page_of_tree(page_number)
  let box = self.pdf_import_visible_box(page)
  let (w, h) = (box.max_x - box.min_x, box.max_y - box.min_y)
  match page.rotate {
    Rotate90 | Rotate270 => (h, w)
    Rotate0 | Rotate180 => (w, h)
  }
}

///|
/// The form matrix that turns the page's visible box upright with its
/// lower-left corner at the origin, as a viewer applies `/Rotate`
/// (clockwise).
fn pdf_import_matrix(
  box : @geometry.PdfRectangle,
  rotate : @page.PdfPageRotation,
) -> Array[Double] {
  match rotate {
    Rotate0 => [1.0, 0.0, 0.0, 1.0, -box.min_x, -box.min_y]
    Rotate90 => [0.0, -1.0, 1.0, 0.0, -box.min_y, box.max_x]
    Rotate180 => [-1.0, 0.0, 0.0, -1.0, box.max_x, box.max_y]
    Rotate270 => [0.0, 1.0, -1.0, 0.0, box.max_y, -box.min_x]
  }
}

///|
/// `object` with indirect references renumbered through `numbers`; a
/// reference to an object that was not copied becomes `null`. Streams get
/// their raw (still encoded) data and a direct `/Length`.
fn PdfDocument::pdf_import_rewrite(
  self : PdfDocument,
  object : @syntax.PdfObject,
  numbers : Map[Int, Int],
) -> @syntax.PdfObject raise @core.PdfError {
  match object {
    PdfIndirect(number) =>
      match numbers.get(number) {
        Some(renumbered) => PdfIndirect(renumbered)
        None => PdfNull
      }
    PdfArray(items) =>
      PdfArray(items.map(item => self.pdf_import_rewrite(item, numbers)))
    PdfDictionary(entries) =>
      PdfDictionary(
        entries.map(entry => {
          (entry.0, self.pdf_import_rewrite(entry.1, numbers))
        }),
      )
    PdfStreamObject(stream) => {
      let data = object.stream_bytes()
      let length = pdf_import_name("/Length")
      let entries : Array[(@core.PdfName, @syntax.PdfObject)] = match
        self.pdf_import_rewrite(stream.dictionary, numbers) {
        PdfDictionary(entries) => entries.filter(entry => entry.0 != length)
        _ => []
      }
      entries.push((length, PdfInteger(data.length())))
      @syntax.pdf_stream(PdfDictionary(entries), StreamGot(data))
    }
    other => other
  }
}

///|
/// The page's content as one stream: a single content stream keeps its
/// filters and encoded bytes; several are decoded and joined (PDF 32000-1
/// §7.8.2), then Flate-compressed.
fn PdfDocument::pdf_import_content(
  self : PdfDocument,
  page : @page.PdfPage,
) -> (Array[(@core.PdfName, @syntax.PdfObject)], Bytes) raise @core.PdfError {
  match page.content {
    [] => ([], Bytes::new(0))
    [single] =>
      match self.direct(single) {
        PdfStreamObject(stream) as object => {
          let kept = [
            pdf_import_name("/Filter"),
            pdf_import_name("/DecodeParms"),
          ]
          let entries = match stream.dictionary {
            PdfDictionary(entries) =>
              entries.filter(entry => kept.contains(entry.0))
            _ => []
          }
          (entries, object.stream_bytes())
        }
        _ => raise ParseStreamExpected
      }
    contents => {
      let merged = pdf_encode_stream_with_encoding(
        PdfStreamFlate,
        self.pdf_page_merged_content_stream(contents),
        only_if_smaller=true,
      )
      match merged {
        PdfStreamObject(stream) as object => {
          let entries = match stream.dictionary {
            PdfDictionary(entries) =>
              entries.filter(entry => entry.0 != pdf_import_name("/Length"))
            _ => []
          }
          (entries, object.stream_bytes())
        }
        _ => raise ParseStreamExpected
      }
    }
  }
}

///|
/// Import page `page_number` (1-based) of `source` into this document as a
/// Form XObject, the way Prawn's templates import a page: what is drawn is
/// the page's visible box (its crop box clipped to its media box), turned
/// upright by its `/Rotate`, with its content and resources. Annotations,
/// the structure tree and other document-level data are not imported.
///
/// The page's content stream keeps its filters and encoded bytes (several
/// content streams are joined and compressed); every object the page's
/// resources (and transparency `/Group`) reach is copied under a new
/// object number, streams with their encoded data, so the source document
/// is left as it was. A reference to a page or page tree node is not
/// followed and becomes `null`. Importing the same page twice copies it
/// twice.
///
/// Raises `BadPageSpecification` when `source` has no such page,
/// `HardError` when it is encrypted, and the reader's errors when the page
/// tree, its boxes or its content are malformed.
pub fn PdfDocument::import_page(
  self : PdfDocument,
  source : PdfDocument,
  page_number : Int,
) -> PdfImportedPage raise @core.PdfError {
  if source.is_encrypted() {
    raise HardError("cannot import a page of an encrypted document")
  }
  let page = source.pdf_import_page_of_tree(page_number)
  let box = source.pdf_import_visible_box(page)
  let (filters, data) = source.pdf_import_content(page)
  let entries : Array[(@core.PdfName, @syntax.PdfObject)] = [
    (pdf_import_name("/Type"), PdfNameObject(pdf_import_name("/XObject"))),
    (pdf_import_name("/Subtype"), PdfNameObject(pdf_import_name("/Form"))),
    (pdf_import_name("/FormType"), PdfInteger(1)),
    (
      pdf_import_name("/BBox"),
      PdfArray([
        PdfReal(box.min_x),
        PdfReal(box.min_y),
        PdfReal(box.max_x),
        PdfReal(box.max_y),
      ]),
    ),
    (
      pdf_import_name("/Matrix"),
      PdfArray(pdf_import_matrix(box, page.rotate).map(v => PdfReal(v))),
    ),
    (pdf_import_name("/Resources"), page.resources),
  ]
  match source.lookup_direct(pdf_import_name("/Group"), page.rest) {
    Some(group) => entries.push((pdf_import_name("/Group"), group))
    None => ()
  }
  entries.append(filters)
  let form = @syntax.pdf_stream(PdfDictionary(entries), StreamGot(data))
  // everything the form reaches, but not back up into a page tree
  let type_key = pdf_import_name("/Type")
  let reached = source.referenced_object_numbers(
    form,
    no_follow_entries=[pdf_import_name("/Parent"), pdf_import_name("/Length")],
    no_follow_contains=[
      (type_key, PdfNameObject(pdf_import_name("/Page"))),
      (type_key, PdfNameObject(pdf_import_name("/Pages"))),
    ],
  )
  let numbers : Map[Int, Int] = Map([])
  for number in reached {
    numbers[number] = self.add_object(PdfNull)
  }
  for number in reached {
    let copied = source.pdf_import_rewrite(
      source.lookup_object_or_null(number),
      numbers,
    )
    self.add_object_given_number(numbers[number], copied)
  }
  let object = self.add_object(source.pdf_import_rewrite(form, numbers))
  let (width, height) = match page.rotate {
    Rotate90 | Rotate270 => (box.max_y - box.min_y, box.max_x - box.min_x)
    Rotate0 | Rotate180 => (box.max_x - box.min_x, box.max_y - box.min_y)
  }
  { object, width, height, }
}
