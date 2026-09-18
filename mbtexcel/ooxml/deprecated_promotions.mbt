// Transitional shims: `#deprecated pub extend` makes the deprecated implicit
// trait-method promotion (E0079) explicit so it stays warning-clean. Remove
// once the compiler stops promoting derived trait methods into methods.

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend ParseXmlError with @debug.Debug::{to_repr}
