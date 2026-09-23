// Added for office.mbt: preserve the upstream method-call API explicitly.
// Make deprecated implicit trait-method promotions explicit on current MoonBit.

///|
pub extend Node with @debug.Debug::{to_repr}

///|
pub extend Node with Eq::{not_equal, equal}

///|
pub extend NodeStyle with @debug.Debug::{to_repr}

///|
pub extend NodeStyle with Eq::{not_equal, equal}

///|
pub extend SmartArt with @debug.Debug::{to_repr}

///|
pub extend SmartArt with Eq::{not_equal, equal}

///|
pub extend SmartArtError with @debug.Debug::{to_repr}

///|
pub extend SmartArtError with Eq::{not_equal, equal}

///|
pub extend SmartArtError with Show::{to_string, output}

///|
pub extend SmartArtKind with @debug.Debug::{to_repr}

///|
pub extend SmartArtKind with Eq::{not_equal, equal}
