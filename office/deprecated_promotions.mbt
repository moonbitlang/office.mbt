///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend DocumentFormat with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend DocumentFormat with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend DocumentFormat with Show::{to_string, output}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend OfficeError with @debug.Debug::{to_repr}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend OfficeError with Eq::{not_equal, equal}

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend OfficeError with Show::{to_string, output}

///|
pub extend SelectorError with Show::{to_string, output}
