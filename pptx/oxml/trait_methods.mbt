// Added for office.mbt: preserve the upstream method-call API explicitly.
// Make deprecated implicit trait-method promotions explicit on current MoonBit.

///|
pub extend ArrowEnd with @debug.Debug::{to_repr}

///|
pub extend ArrowEnd with Eq::{not_equal, equal}

///|
pub extend ArrowSize with @debug.Debug::{to_repr}

///|
pub extend ArrowSize with Eq::{not_equal, equal}

///|
pub extend ArrowType with @debug.Debug::{to_repr}

///|
pub extend ArrowType with Eq::{not_equal, equal}

///|
pub extend BlipFill with @debug.Debug::{to_repr}

///|
pub extend BlipFill with Eq::{not_equal, equal}

///|
pub extend BlipFillMode with @debug.Debug::{to_repr}

///|
pub extend BlipFillMode with Eq::{not_equal, equal}

///|
pub extend Blur with @debug.Debug::{to_repr}

///|
pub extend Blur with Eq::{not_equal, equal}

///|
pub extend Color with @debug.Debug::{to_repr}

///|
pub extend Color with Eq::{not_equal, equal}

///|
pub extend Color with Show::{to_string, output}

///|
pub extend ColorBase with @debug.Debug::{to_repr}

///|
pub extend ColorBase with Eq::{not_equal, equal}

///|
pub extend ColorBase with Show::{to_string, output}

///|
pub extend ColorError with @debug.Debug::{to_repr}

///|
pub extend ColorError with Eq::{not_equal, equal}

///|
pub extend ColorError with Show::{output}

///|
pub extend CompoundLine with @debug.Debug::{to_repr}

///|
pub extend CompoundLine with Eq::{not_equal, equal}

///|
pub extend DashStyle with @debug.Debug::{to_repr}

///|
pub extend DashStyle with Eq::{not_equal, equal}

///|
pub extend EffectError with @debug.Debug::{to_repr}

///|
pub extend EffectError with Eq::{not_equal, equal}

///|
pub extend EffectError with Show::{to_string, output}

///|
pub extend EffectList with @debug.Debug::{to_repr}

///|
pub extend EffectList with Eq::{not_equal, equal}

///|
pub extend Fill with @debug.Debug::{to_repr}

///|
pub extend Fill with Eq::{not_equal, equal}

///|
pub extend FillError with @debug.Debug::{to_repr}

///|
pub extend FillError with Eq::{not_equal, equal}

///|
pub extend FillError with Show::{output}

///|
pub extend FillRect with @debug.Debug::{to_repr}

///|
pub extend FillRect with Eq::{not_equal, equal}

///|
pub extend Glow with @debug.Debug::{to_repr}

///|
pub extend Glow with Eq::{not_equal, equal}

///|
pub extend Gradient with @debug.Debug::{to_repr}

///|
pub extend Gradient with Eq::{not_equal, equal}

///|
pub extend GradientDirection with @debug.Debug::{to_repr}

///|
pub extend GradientDirection with Eq::{not_equal, equal}

///|
pub extend GradientStop with @debug.Debug::{to_repr}

///|
pub extend GradientStop with Eq::{not_equal, equal}

///|
pub extend ImageDimensions with @debug.Debug::{to_repr}

///|
pub extend ImageDimensions with Eq::{not_equal, equal}

///|
pub extend ImageDimensions with Show::{to_string, output}

///|
pub extend ImageFormat with @debug.Debug::{to_repr}

///|
pub extend ImageFormat with Eq::{not_equal, equal}

///|
pub extend ImageFormat with Show::{to_string, output}

///|
pub extend InnerShadow with @debug.Debug::{to_repr}

///|
pub extend InnerShadow with Eq::{not_equal, equal}

///|
pub extend LineCap with @debug.Debug::{to_repr}

///|
pub extend LineCap with Eq::{not_equal, equal}

///|
pub extend LineJoin with @debug.Debug::{to_repr}

///|
pub extend LineJoin with Eq::{not_equal, equal}

///|
pub extend MediaFormat with @debug.Debug::{to_repr}

///|
pub extend MediaFormat with Eq::{not_equal, equal}

///|
pub extend MediaFormat with Show::{to_string, output}

///|
pub extend OuterShadow with @debug.Debug::{to_repr}

///|
pub extend OuterShadow with Eq::{not_equal, equal}

///|
pub extend Pattern with @debug.Debug::{to_repr}

///|
pub extend Pattern with Eq::{not_equal, equal}

///|
pub extend PenAlignment with @debug.Debug::{to_repr}

///|
pub extend PenAlignment with Eq::{not_equal, equal}

///|
pub extend PresetShadow with @debug.Debug::{to_repr}

///|
pub extend PresetShadow with Eq::{not_equal, equal}

///|
pub extend RectAlignment with @debug.Debug::{to_repr}

///|
pub extend RectAlignment with Eq::{not_equal, equal}

///|
pub extend Reflection with @debug.Debug::{to_repr}

///|
pub extend Reflection with Eq::{not_equal, equal}

///|
pub extend SoftEdge with @debug.Debug::{to_repr}

///|
pub extend SoftEdge with Eq::{not_equal, equal}

///|
pub extend SrcRect with @debug.Debug::{to_repr}

///|
pub extend SrcRect with Eq::{not_equal, equal}

///|
pub extend Stroke with @debug.Debug::{to_repr}

///|
pub extend Stroke with Eq::{not_equal, equal}

///|
pub extend StrokeError with @debug.Debug::{to_repr}

///|
pub extend StrokeError with Eq::{not_equal, equal}

///|
pub extend StrokeError with Show::{to_string, output}

///|
pub extend SysColor with @debug.Debug::{to_repr}

///|
pub extend SysColor with Eq::{not_equal, equal}

///|
pub extend SysColor with Show::{to_string, output}

///|
pub extend TileAlignment with @debug.Debug::{to_repr}

///|
pub extend TileAlignment with Eq::{not_equal, equal}

///|
pub extend TileFlip with @debug.Debug::{to_repr}

///|
pub extend TileFlip with Eq::{not_equal, equal}

///|
pub extend TileSpec with @debug.Debug::{to_repr}

///|
pub extend TileSpec with Eq::{not_equal, equal}

///|
pub extend Utf8Error with @debug.Debug::{to_repr}

///|
pub extend Utf8Error with Eq::{not_equal, equal}

///|
pub extend Utf8Error with Show::{to_string, output}

///|
pub extend XmlReadError with @debug.Debug::{to_repr}

///|
pub extend XmlReadError with Eq::{not_equal, equal}

///|
pub extend XmlReadError with Show::{output}
