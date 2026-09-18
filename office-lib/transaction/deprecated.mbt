///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend TransactionError with Show::{to_string, output}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend TransactionMode with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend TransactionMode with Eq::{not_equal, equal}
