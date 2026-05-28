///|
fn pdf_fun_number_array_object(values : ArrayView[Double]) -> PdfObject {
  PdfArray([ for value in values => PdfReal(value) ])
}

///|
fn PdfFunction::pdf_fun_function_type(self : PdfFunction) -> Int {
  match self.func {
    PdfFunctionSampled(_) => 0
    PdfFunctionInterpolation(_) => 2
    PdfFunctionStitching(_) => 3
    PdfFunctionCalculator(_) => 4
  }
}

///|
/// Build a PDF object for a parsed function.
///
/// Interpolation functions are written as dictionaries. Stitching functions add
/// child function objects to this document and reference them from the returned
/// dictionary. Sampled and calculator variants currently write only the common
/// function dictionary fields and do not recreate their stream data.
pub fn PdfDocument::pdf_object_of_function(
  self : PdfDocument,
  function : PdfFunction,
) -> PdfObject {
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_fun_function_type_key(), PdfInteger(function.pdf_fun_function_type())),
    (pdf_fun_domain_key(), pdf_fun_number_array_object(function.domain)),
  ]
  match function.range {
    Some(range) =>
      entries.push((pdf_fun_range_key(), pdf_fun_number_array_object(range)))
    None => ()
  }
  match function.func {
    PdfFunctionInterpolation(interpolation) => {
      entries.push(
        (pdf_fun_c0_key(), pdf_fun_number_array_object(interpolation.c0)),
      )
      entries.push(
        (pdf_fun_c1_key(), pdf_fun_number_array_object(interpolation.c1)),
      )
      entries.push((pdf_fun_n_key(), PdfReal(interpolation.n)))
    }
    PdfFunctionStitching(stitching) => {
      let function_refs : Array[PdfObject] = []
      for child in stitching.functions {
        function_refs.push(
          PdfIndirect(self.add_object(self.pdf_object_of_function(child))),
        )
      }
      entries.push((pdf_fun_functions_key(), PdfArray(function_refs)))
      entries.push(
        (pdf_fun_bounds_key(), pdf_fun_number_array_object(stitching.bounds)),
      )
      entries.push(
        (
          pdf_fun_encode_key(),
          pdf_fun_number_array_object(stitching.stitch_encode),
        ),
      )
    }
    PdfFunctionSampled(_) | PdfFunctionCalculator(_) => ()
  }
  PdfDictionary(entries)
}

///|
/// Compatibility wrapper for `PdfDocument::pdf_object_of_function`.
pub fn pdf_object_of_function(
  document : PdfDocument,
  function : PdfFunction,
) -> PdfObject {
  document.pdf_object_of_function(function)
}
