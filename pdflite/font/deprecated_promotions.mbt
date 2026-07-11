// Transitional shims: `#deprecated pub extend` makes the deprecated implicit
// trait-method promotion (E0079) explicit. Remove once the compiler stops
// promoting derived trait methods into methods.

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfFontListEntry with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfFontListEntry with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfFontListEntry with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfFontTableEntry with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfFontTableEntry with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfFontTableEntry with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMissingFontEntry with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMissingFontEntry with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMissingFontEntry with ToJson::{to_json}
