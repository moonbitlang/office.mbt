// Transitional shims: `#deprecated pub extend` makes the deprecated implicit
// trait-method promotion (E0079) explicit. Remove once the compiler stops
// promoting derived trait methods into methods.

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeCMapGlyph with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeCMapGlyph with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeCMapGlyph with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeDescriptorMetrics with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeDescriptorMetrics with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeDescriptorMetrics with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeGlyphByteRange with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeGlyphByteRange with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeGlyphByteRange with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeMetrics with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeMetrics with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeMetrics with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeParsedSubset with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeParsedSubset with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeSubsetPartition with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeSubsetPartition with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeSubsetPartition with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeSubsetTable with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeSubsetTable with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeTableRecord with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeTableRecord with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfTrueTypeTableRecord with ToJson::{to_json}
