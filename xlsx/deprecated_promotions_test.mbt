// Transitional shim (blackbox test package): keep the deprecated implicit
// promotion of MemWriter's Writer impl explicit. Remove with the others.

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend MemWriter with @async/io.Writer::{write_once, write}
