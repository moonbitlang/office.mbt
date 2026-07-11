// Transitional shims: `#deprecated pub extend` makes the deprecated implicit
// trait-method promotion (E0079) explicit. Remove once the compiler stops
// promoting derived trait methods into methods.

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfUnicodeDataEntry with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfUnicodeDataEntry with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfUnicodeDataEntry with ToJson::{to_json}
