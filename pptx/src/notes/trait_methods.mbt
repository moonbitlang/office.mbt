// Added for office.mbt: preserve the upstream method-call API explicitly.
// Make deprecated implicit trait-method promotions explicit on current MoonBit.

///|
pub extend NotesError with @debug.Debug::{to_repr}

///|
pub extend NotesError with Eq::{not_equal, equal}

///|
pub extend NotesError with Show::{to_string, output}

///|
pub extend NotesSlide with @debug.Debug::{to_repr}

///|
pub extend NotesSlide with Eq::{not_equal, equal}
