// Transitional shims: `#deprecated pub extend` makes the deprecated implicit
// trait-method promotion (E0079) explicit. Remove once the compiler stops
// promoting derived trait methods into methods.

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataEncoding with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataEncoding with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataEncoding with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlAttribute with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlAttribute with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlAttribute with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlDocument with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlDocument with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlDocument with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlName with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlName with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlName with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlTag with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlTag with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlTag with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlTree with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlTree with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfMetadataXmlTree with ToJson::{to_json}
