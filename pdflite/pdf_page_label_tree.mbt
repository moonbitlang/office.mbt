///|
fn pdf_page_label_style_of_object(
  object : PdfObject?,
) -> @label.PdfPageLabelStyle {
  match object {
    Some(PdfNameObject(name)) if name == pdf_page_label_style_decimal_name() =>
      PageLabelDecimalArabic
    Some(PdfNameObject(name)) if name == pdf_page_label_style_upper_roman_name() =>
      PageLabelUppercaseRoman
    Some(PdfNameObject(name)) if name == pdf_page_label_style_lower_roman_name() =>
      PageLabelLowercaseRoman
    Some(PdfNameObject(name)) if name ==
      pdf_page_label_style_upper_letters_name() => PageLabelUppercaseLetters
    Some(PdfNameObject(name)) if name ==
      pdf_page_label_style_lower_letters_name() => PageLabelLowercaseLetters
    _ => PageLabelNoLabelPrefixOnly
  }
}

///|
fn pdf_page_label_style_object(style : @label.PdfPageLabelStyle) -> PdfObject? {
  match style {
    PageLabelDecimalArabic =>
      Some(PdfNameObject(pdf_page_label_style_decimal_name()))
    PageLabelUppercaseRoman =>
      Some(PdfNameObject(pdf_page_label_style_upper_roman_name()))
    PageLabelLowercaseRoman =>
      Some(PdfNameObject(pdf_page_label_style_lower_roman_name()))
    PageLabelUppercaseLetters =>
      Some(PdfNameObject(pdf_page_label_style_upper_letters_name()))
    PageLabelLowercaseLetters =>
      Some(PdfNameObject(pdf_page_label_style_lower_letters_name()))
    PageLabelNoLabelPrefixOnly => None
  }
}

///|
fn PdfDocument::pdf_page_label_raw_entries(
  self : PdfDocument,
  tree : PdfObject,
) -> Array[(PdfObject, PdfObject)] raise PdfError {
  let direct = self.lookup_direct_or_else(
    pdf_tree_names_key(),
    pdf_tree_nums_key(),
    tree,
  )
  let kids_object = self.lookup_direct(pdf_tree_kids_key(), tree)
  let output : Array[(PdfObject, PdfObject)] = Array::new(
    capacity=match direct {
      Some(PdfArray(items)) => items.length() / 2
      _ =>
        match kids_object {
          Some(PdfArray(kids)) => kids.length()
          _ => 0
        }
    },
  )
  match direct {
    Some(PdfArray(items)) =>
      for i in 0..<(items.length() / 2) {
        output.push((items[i * 2], items[i * 2 + 1]))
      }
    _ =>
      match kids_object {
        Some(PdfArray(kids)) =>
          for kid in kids {
            for entry in self.pdf_page_label_raw_entries(kid) {
              output.push(entry)
            }
          }
        _ => raise PageTreeExpected
      }
  }
  output
}

///|
fn PdfDocument::pdf_page_label_of_range(
  self : PdfDocument,
  start_page_object : PdfObject,
  object : PdfObject,
) -> @label.PdfPageLabel {
  {
    label_style: pdf_page_label_style_of_object(
      self.lookup_direct(pdf_page_label_style_key(), object),
    ),
    label_prefix: match
      self.lookup_direct(pdf_page_label_prefix_key(), object) {
      Some(PdfString(prefix)) => Some(prefix)
      _ => None
    },
    start_page: match start_page_object {
      PdfInteger(start_page_zero_based) => start_page_zero_based + 1
      _ => 1
    },
    start_value: match
      self.lookup_direct(pdf_page_label_start_value_key(), object) {
      Some(PdfInteger(value)) => value
      _ => 1
    },
  }
}

///|
fn pdf_page_label_object(label : @label.PdfPageLabel) -> PdfObject {
  let entries : Array[(PdfName, PdfObject)] = Array::new(capacity=3)
  match pdf_page_label_style_object(label.label_style) {
    Some(style) => entries.push((pdf_page_label_style_key(), style))
    None => ()
  }
  match label.label_prefix {
    Some(prefix) =>
      entries.push((pdf_page_label_prefix_key(), PdfString(prefix)))
    None => ()
  }
  if label.start_value != 1 {
    entries.push(
      (pdf_page_label_start_value_key(), PdfInteger(label.start_value)),
    )
  }
  PdfDictionary(entries)
}

///|
fn PdfDocument::pdf_page_label_catalog(
  self : PdfDocument,
) -> PdfObject raise PdfError {
  self.catalog()
}

///|
/// Read the document catalog `/PageLabels` number tree.
///
/// The returned `start_page` values are converted from PDF's zero-based page
/// indexes to the public 1-based page numbering used by this module. Documents
/// without page labels return an empty array.
pub fn PdfDocument::read_page_labels(
  self : PdfDocument,
) -> Array[@label.PdfPageLabel] raise PdfError {
  let root = self.pdf_page_label_catalog()
  match self.lookup_direct(pdf_page_label_page_labels_key(), root) {
    Some(label_tree) => {
      let raw_entries = self.pdf_page_label_raw_entries(label_tree)
      let output : Array[@label.PdfPageLabel] = Array::new(
        capacity=raw_entries.length(),
      )
      for entry in raw_entries {
        output.push(self.pdf_page_label_of_range(entry.0, entry.1))
      }
      output
    }
    None => []
  }
}

///|
/// Compatibility wrapper for `PdfDocument::read_page_labels`.
pub fn pdf_read_page_labels(
  document : PdfDocument,
) -> Array[@label.PdfPageLabel] raise PdfError {
  document.read_page_labels()
}

///|
fn PdfDocument::pdf_page_label_has_labels(
  self : PdfDocument,
) -> Bool raise PdfError {
  let root = self.pdf_page_label_catalog()
  self.lookup_direct(pdf_page_label_page_labels_key(), root) is Some(_)
}

///|
/// Return a copy of the document with catalog `/PageLabels` removed.
///
/// The original document is not mutated; the returned document has a new root
/// object and trailer root reference.
pub fn PdfDocument::remove_page_labels(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let root = self.pdf_page_label_catalog()
  let pdf = self.copy()
  let root_without_labels = root.remove_dict_entry(
    pdf_page_label_page_labels_key(),
  )
  let new_root = pdf.add_object(root_without_labels)
  pdf.set_root(new_root)
  pdf.set_trailer_dict(
    pdf
    .trailer_dict()
    .add_dict_entry(pdf_page_label_root_key(), PdfIndirect(new_root)),
  )
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::remove_page_labels`.
pub fn pdf_remove_page_labels(
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_page_labels()
}

///|
/// Return a copy of the document with catalog `/PageLabels` replaced.
///
/// Public `start_page` values are written as zero-based PDF number-tree keys.
/// Passing an empty label list removes any existing page-label tree.
pub fn PdfDocument::write_page_labels(
  self : PdfDocument,
  labels : ArrayView[@label.PdfPageLabel],
) -> PdfDocument raise PdfError {
  if labels.length() == 0 {
    self.remove_page_labels()
  } else {
    let root = self.pdf_page_label_catalog()
    let pdf = self.copy()
    let entries : Array[(Int, PdfObject)] = Array::new(capacity=labels.length())
    for label in labels {
      entries.push((label.start_page - 1, pdf_page_label_object(label)))
    }
    let new_root = pdf.add_object(
      root.add_dict_entry(
        pdf_page_label_page_labels_key(),
        pdf.build_number_tree(entries),
      ),
    )
    pdf.set_root(new_root)
    pdf.set_trailer_dict(
      pdf
      .trailer_dict()
      .add_dict_entry(pdf_page_label_root_key(), PdfIndirect(new_root)),
    )
    pdf
  }
}

///|
/// Compatibility wrapper for `PdfDocument::write_page_labels`.
pub fn pdf_write_page_labels(
  document : PdfDocument,
  labels : ArrayView[@label.PdfPageLabel],
) -> PdfDocument raise PdfError {
  document.write_page_labels(labels)
}
