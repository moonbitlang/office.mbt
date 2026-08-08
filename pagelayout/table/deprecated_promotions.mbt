// Transitional shims: `#deprecated pub extend` makes the deprecated implicit
// trait-method promotion (E0079) explicit. Remove once the compiler stops
// promoting derived trait methods into methods.

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Width with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Width with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Width with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend TableLayout with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend TableLayout with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend TableLayout with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Border with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Border with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Border with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Borders with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Borders with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Borders with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend CellMargins with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend CellMargins with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend CellMargins with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend VMerge with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend VMerge with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend VMerge with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Cell with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Cell with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Cell with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Row with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Row with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Row with ToJson::{to_json}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Table with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Table with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend Table with ToJson::{to_json}
