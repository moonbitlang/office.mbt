// Added for office.mbt: preserve the upstream method-call API explicitly.
// Make deprecated implicit trait-method promotions explicit on current MoonBit.

///|
pub extend ContentTypes with @debug.Debug::{to_repr}

///|
pub extend ContentTypes with Eq::{not_equal, equal}

///|
pub extend OpcError with @debug.Debug::{to_repr}

///|
pub extend OpcError with Eq::{not_equal, equal}

///|
pub extend OpcError with Show::{to_string, output}

///|
pub extend Part with @debug.Debug::{to_repr}

///|
pub extend Part with Show::{to_string, output}

///|
pub extend Relationship with @debug.Debug::{to_repr}

///|
pub extend Relationship with Eq::{not_equal, equal}

///|
pub extend Relationship with Show::{to_string, output}

///|
pub extend Relationships with @debug.Debug::{to_repr}

///|
pub extend TargetMode with @debug.Debug::{to_repr}

///|
pub extend TargetMode with Eq::{not_equal, equal}
