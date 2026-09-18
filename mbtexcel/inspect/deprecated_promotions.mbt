// Transitional shims: `#deprecated pub extend` makes the deprecated implicit
// trait-method promotion (E0079) explicit so it stays warning-clean. Remove
// once the compiler stops promoting derived trait methods into methods.

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend CellRange with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend CellRange with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend ChartSeriesMeta with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend ChartSeriesMeta with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend RangeError with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend RangeError with Show::{to_string, output}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend QueryError with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend QueryError with Show::{to_string, output}
