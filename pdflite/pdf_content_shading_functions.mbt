///|
fn pdf_content_default_function() -> PdfFunction {
  { func: PdfFunctionCalculator({ operations: [] }), domain: [], range: None }
}

///|
fn PdfDocument::pdf_content_shading_function_or_default(
  self : PdfDocument,
  object : @syntax.PdfObject?,
) -> PdfFunction {
  match object {
    Some(function_object) =>
      try self.parse_function(function_object) catch {
        _ => pdf_content_default_function()
      } noraise {
        function => function
      }
    None => pdf_content_default_function()
  }
}

///|
fn PdfDocument::pdf_content_shading_functions(
  self : PdfDocument,
  shading : @syntax.PdfObject,
) -> Array[PdfFunction] raise @core.PdfError {
  match self.lookup_direct(pdf_content_shading_function_name, shading) {
    Some(PdfArray(functions)) => {
      let parsed : Array[PdfFunction] = []
      for function_object in functions {
        parsed.push(self.parse_function(function_object))
      }
      parsed
    }
    Some(function_object) => [self.parse_function(function_object)]
    None => [pdf_content_default_function()]
  }
}
