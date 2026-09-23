// Added for office.mbt: preserve the upstream method-call API explicitly.
// Make deprecated implicit trait-method promotions explicit on current MoonBit.

///|
pub extend Angle with @debug.Debug::{to_repr}

///|
pub extend Angle with Eq::{not_equal, equal}

///|
pub extend Angle with Show::{to_string, output}

///|
pub extend Cm with @debug.Debug::{to_repr}

///|
pub extend Cm with Eq::{not_equal, equal}

///|
pub extend Cm with Show::{to_string, output}

///|
pub extend ColorTransform with @debug.Debug::{to_repr}

///|
pub extend ColorTransform with Eq::{not_equal, equal}

///|
pub extend ColorTransform with Show::{to_string, output}

///|
pub extend Emu with @debug.Debug::{to_repr}

///|
pub extend Emu with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend Emu with Eq::{not_equal, equal}

///|
pub extend Emu with Show::{to_string, output}

///|
pub extend HslColor with @debug.Debug::{to_repr}

///|
pub extend HslColor with Eq::{not_equal, equal}

///|
pub extend HslColor with Show::{to_string, output}

///|
pub extend Inch with @debug.Debug::{to_repr}

///|
pub extend Inch with Eq::{not_equal, equal}

///|
pub extend Inch with Show::{to_string, output}

///|
pub extend Percentage with @debug.Debug::{to_repr}

///|
pub extend Percentage with Eq::{not_equal, equal}

///|
pub extend Percentage with Show::{to_string, output}

///|
pub extend Pt with @debug.Debug::{to_repr}

///|
pub extend Pt with Eq::{not_equal, equal}

///|
pub extend Pt with Show::{to_string, output}

///|
pub extend RgbColor with @debug.Debug::{to_repr}

///|
pub extend RgbColor with Eq::{not_equal, equal}

///|
pub extend RgbColor with Show::{to_string, output}

///|
pub extend SchemeColor with @debug.Debug::{to_repr}

///|
pub extend SchemeColor with Show::{to_string, output}

///|
pub extend ThemeColor with @debug.Debug::{to_repr}

///|
pub extend ThemeColor with Eq::{not_equal, equal}

///|
pub extend ThemeColor with Show::{to_string, output}

///|
pub extend UnitsError with @debug.Debug::{to_repr}

///|
pub extend UnitsError with Eq::{not_equal, equal}

///|
pub extend UnitsError with Show::{to_string, output}
