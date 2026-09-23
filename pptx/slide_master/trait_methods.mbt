// Added for office.mbt: preserve the upstream method-call API explicitly.
// Make deprecated implicit trait-method promotions explicit on current MoonBit.

///|
pub extend ClrMapOverride with @debug.Debug::{to_repr}

///|
pub extend ClrMapOverride with Eq::{not_equal, equal}

///|
pub extend ColorMapping with @debug.Debug::{to_repr}

///|
pub extend ColorMapping with Eq::{not_equal, equal}

///|
pub extend SlideLayout with @debug.Debug::{to_repr}

///|
pub extend SlideLayout with Eq::{not_equal, equal}

///|
pub extend SlideLayoutRef with @debug.Debug::{to_repr}

///|
pub extend SlideLayoutRef with Eq::{not_equal, equal}

///|
pub extend SlideLayoutType with @debug.Debug::{to_repr}

///|
pub extend SlideLayoutType with Eq::{not_equal, equal}

///|
pub extend SlideMaster with @debug.Debug::{to_repr}

///|
pub extend SlideMaster with Eq::{not_equal, equal}

///|
pub extend SlideMasterError with @debug.Debug::{to_repr}

///|
pub extend SlideMasterError with Eq::{not_equal, equal}

///|
pub extend SlideMasterError with Show::{to_string, output}
