// Added for office.mbt: preserve the upstream method-call API explicitly.
// Make deprecated implicit trait-method promotions explicit on current MoonBit.

///|
pub extend ChartEx with @debug.Debug::{to_repr}

///|
pub extend ChartEx with Eq::{not_equal, equal}

///|
pub extend ChartEx with Show::{to_string, output}

///|
pub extend ChartExBody with @debug.Debug::{to_repr}

///|
pub extend ChartExBody with Eq::{not_equal, equal}

///|
pub extend ChartExBody with Show::{to_string, output}

///|
pub extend ChartExError with @debug.Debug::{to_repr}

///|
pub extend ChartExError with Eq::{not_equal, equal}

///|
pub extend ChartExError with Show::{to_string, output}

///|
pub extend ChartExKind with @debug.Debug::{to_repr}

///|
pub extend ChartExKind with Eq::{not_equal, equal}

///|
pub extend ChartExKind with Show::{to_string, output}

///|
pub extend ChartExPlotArea with @debug.Debug::{to_repr}

///|
pub extend ChartExPlotArea with Eq::{not_equal, equal}

///|
pub extend ChartExPlotArea with Show::{to_string, output}

///|
pub extend ChartExPlotAreaRegion with @debug.Debug::{to_repr}

///|
pub extend ChartExPlotAreaRegion with Eq::{not_equal, equal}

///|
pub extend ChartExPlotAreaRegion with Show::{to_string, output}

///|
pub extend ChartExSeries with @debug.Debug::{to_repr}

///|
pub extend ChartExSeries with Eq::{not_equal, equal}

///|
pub extend ChartExSeries with Show::{to_string, output}
