// Added for office.mbt: preserve the upstream method-call API explicitly.
// Make deprecated implicit trait-method promotions explicit on current MoonBit.

///|
pub extend AppProperties with @debug.Debug::{to_repr}

///|
pub extend AppProperties with Eq::{not_equal, equal}

///|
pub extend BlankSlide with LayoutPlaceholders::{placeholders}

///|
pub extend BlankSlide with LayoutType::{layout_type}

///|
pub extend CoreProperties with @debug.Debug::{to_repr}

///|
pub extend CoreProperties with Eq::{not_equal, equal}

///|
pub extend NotesSize with @debug.Debug::{to_repr}

///|
pub extend NotesSize with Eq::{not_equal, equal}

///|
pub extend PptxError with @debug.Debug::{to_repr}

///|
pub extend PptxError with Eq::{not_equal, equal}

///|
pub extend PptxError with Show::{to_string, output}

///|
pub extend PresentationPart with @debug.Debug::{to_repr}

///|
pub extend PresentationPart with Eq::{not_equal, equal}

///|
pub extend Section with @debug.Debug::{to_repr}

///|
pub extend Section with Eq::{not_equal, equal}

///|
pub extend SectionHeader with HasBody::{body_spec}

///|
pub extend SectionHeader with HasTitle::{title_spec}

///|
pub extend SectionHeader with LayoutPlaceholders::{placeholders}

///|
pub extend SectionHeader with LayoutType::{layout_type}

///|
pub extend SlideIdRef with @debug.Debug::{to_repr}

///|
pub extend SlideIdRef with Eq::{not_equal, equal}

///|
pub extend SlideMasterIdRef with @debug.Debug::{to_repr}

///|
pub extend SlideMasterIdRef with Eq::{not_equal, equal}

///|
pub extend SlideSize with @debug.Debug::{to_repr}

///|
pub extend SlideSize with Eq::{not_equal, equal}

///|
pub extend SlideSizeKind with @debug.Debug::{to_repr}

///|
pub extend SlideSizeKind with Eq::{not_equal, equal}

///|
pub extend SlideSizeKind with Show::{to_string, output}

///|
pub extend TitleAndContent with HasBody::{body_spec}

///|
pub extend TitleAndContent with HasTitle::{title_spec}

///|
pub extend TitleAndContent with LayoutPlaceholders::{placeholders}

///|
pub extend TitleAndContent with LayoutType::{layout_type}

///|
pub extend TitleOnly with HasTitle::{title_spec}

///|
pub extend TitleOnly with LayoutPlaceholders::{placeholders}

///|
pub extend TitleOnly with LayoutType::{layout_type}

///|
pub extend TitleSlide with HasSubtitle::{subtitle_spec}

///|
pub extend TitleSlide with HasTitle::{title_spec}

///|
pub extend TitleSlide with LayoutPlaceholders::{placeholders}

///|
pub extend TitleSlide with LayoutType::{layout_type}
