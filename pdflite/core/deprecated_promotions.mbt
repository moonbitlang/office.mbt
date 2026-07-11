// Transitional shims: `#deprecated pub extend` makes the deprecated implicit
// trait-method promotion (E0079) explicit. Remove once the compiler stops
// promoting derived trait methods into methods.

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend BitStream with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend BitStream with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend BitStream with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend BitStreamPosition with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend BitStreamPosition with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend BitStreamPosition with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend BitWriter with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend BitWriter with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend BitWriter with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend ByteCursor with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend ByteCursor with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend ByteCursor with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend ByteOutput with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend ByteOutput with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend ByteOutput with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfCryptType with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfCryptType with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfCryptType with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfError with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfError with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfError with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfName with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfName with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend PdfName with ToJson::{to_json}
