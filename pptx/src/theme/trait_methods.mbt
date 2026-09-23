// Added for office.mbt: preserve the upstream method-call API explicitly.
// Make deprecated implicit trait-method promotions explicit on current MoonBit.

///|
pub extend ColorScheme with @debug.Debug::{to_repr}

///|
pub extend ColorScheme with Eq::{not_equal, equal}

///|
pub extend FontCollection with @debug.Debug::{to_repr}

///|
pub extend FontCollection with Eq::{not_equal, equal}

///|
pub extend FontScheme with @debug.Debug::{to_repr}

///|
pub extend FontScheme with Eq::{not_equal, equal}

///|
pub extend ScriptFont with @debug.Debug::{to_repr}

///|
pub extend ScriptFont with Eq::{not_equal, equal}

///|
pub extend ScriptFont with Show::{to_string, output}

///|
pub extend ScriptSlot with @debug.Debug::{to_repr}

///|
pub extend ScriptSlot with Eq::{not_equal, equal}

///|
pub extend Theme with @debug.Debug::{to_repr}

///|
pub extend Theme with Eq::{not_equal, equal}

///|
pub extend ThemeError with @debug.Debug::{to_repr}

///|
pub extend ThemeError with Eq::{not_equal, equal}

///|
pub extend ThemeError with Show::{to_string, output}

///|
pub extend ThemeFontRef with @debug.Debug::{to_repr}

///|
pub extend ThemeFontRef with Eq::{not_equal, equal}
