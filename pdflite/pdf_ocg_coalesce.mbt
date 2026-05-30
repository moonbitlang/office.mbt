///|
fn pdf_ocg_representative_number(
  representatives : ArrayView[(PdfBytes, Int)],
  name : PdfBytes,
) -> Int? {
  for representative in representatives {
    if representative.0 == name {
      break Some(representative.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_ocg_changed_number(changes : ArrayView[(Int, Int)], number : Int) -> Int {
  for change in changes {
    if change.0 == number {
      break change.1
    }
  } nobreak {
    number
  }
}

///|
fn pdf_ocg_push_unique_number(output : Array[Int], number : Int) -> Unit {
  if !output.contains(number) {
    output.push(number)
  }
}

///|
fn pdf_ocg_coalesce_numbers(
  changes : ArrayView[(Int, Int)],
  numbers : ArrayView[Int],
) -> Array[Int] {
  let output : Array[Int] = []
  for number in numbers {
    pdf_ocg_push_unique_number(output, pdf_ocg_changed_number(changes, number))
  }
  output
}

///|
fn pdf_ocg_coalesce_order(
  changes : ArrayView[(Int, Int)],
  order : ArrayView[(PdfBytes?, Array[Int])],
) -> Array[(PdfBytes?, Array[Int])] {
  let output : Array[(PdfBytes?, Array[Int])] = []
  let seen : Array[Int] = []
  for item in order {
    let numbers : Array[Int] = []
    for number in item.1 {
      let changed = pdf_ocg_changed_number(changes, number)
      if !seen.contains(changed) {
        seen.push(changed)
        numbers.push(changed)
      }
    }
    if numbers.length() > 0 {
      output.push((item.0, numbers))
    }
  }
  output
}

///|
fn pdf_ocg_coalesce_appdict(
  changes : ArrayView[(Int, Int)],
  appdict : @ocg.PdfOcgAppDict,
) -> @ocg.PdfOcgAppDict {
  { ..appdict, ocgs: pdf_ocg_coalesce_numbers(changes, appdict.ocgs) }
}

///|
fn pdf_ocg_coalesce_config(
  changes : ArrayView[(Int, Int)],
  config : @ocg.PdfOcgConfig,
) -> @ocg.PdfOcgConfig {
  {
    ..config,
    on: pdf_ocg_coalesce_numbers(changes, config.on),
    off: pdf_ocg_coalesce_numbers(changes, config.off),
    usage_applications: [
      for appdict in config.usage_applications => {
        pdf_ocg_coalesce_appdict(changes, appdict)
      }
    ],
    order: match config.order {
      Some(order) => Some(pdf_ocg_coalesce_order(changes, order))
      None => None
    },
    radio_button_groups: match config.radio_button_groups {
      Some(groups) =>
        Some(
          [
            for group in groups => pdf_ocg_coalesce_numbers(changes, group)
          ],
        )
      None => None
    },
    locked: pdf_ocg_coalesce_numbers(changes, config.locked),
  }
}

///|
fn pdf_ocg_coalesce_content(
  content : @ocg.PdfOptionalContent,
) -> (@ocg.PdfOptionalContent, Array[(Int, Int)]) {
  let representatives : Array[(PdfBytes, Int)] = []
  let ocgs : Array[(Int, @ocg.PdfOcg)] = []
  let changes : Array[(Int, Int)] = []
  for entry in content.ocgs {
    let (number, ocg) = entry
    match pdf_ocg_representative_number(representatives, ocg.name) {
      Some(representative) =>
        if representative != number {
          changes.push((number, representative))
        }
      None => {
        representatives.push((ocg.name, number))
        ocgs.push((number, pdf_ocg_copy_ocg(ocg)))
      }
    }
  }
  (
    {
      ocgs,
      default_config: pdf_ocg_coalesce_config(changes, content.default_config),
      configs: [
        for config in content.configs => {
          pdf_ocg_coalesce_config(changes, config)
        }
      ],
    },
    changes,
  )
}

///|
/// Return a copy with same-named optional-content groups coalesced.
///
/// The first group for each raw PDF name is kept. Duplicate group references in
/// optional-content metadata and parsed document objects are rewritten to the
/// kept object number, and duplicate OCG objects are removed.
pub fn PdfDocument::ocg_coalesce(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  match self.read_optional_content_groups() {
    None => self.copy()
    Some(content) => {
      let (coalesced, changes) = pdf_ocg_coalesce_content(content)
      if changes.length() == 0 {
        self.copy()
      } else {
        let pdf = self.write_optional_content_groups(coalesced)
        pdf.pdf_page_renumber_references(changes)
        for change in changes {
          pdf.remove_object(change.0)
        }
        pdf
      }
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::ocg_coalesce`.
pub fn pdf_ocg_coalesce(document : PdfDocument) -> PdfDocument raise PdfError {
  document.ocg_coalesce()
}
