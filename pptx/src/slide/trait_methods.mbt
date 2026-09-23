// Added for office.mbt: preserve the upstream method-call API explicitly.
// Make deprecated implicit trait-method promotions explicit on current MoonBit.

///|
pub extend AdjAngle with @debug.Debug::{to_repr}

///|
pub extend AdjAngle with Eq::{not_equal, equal}

///|
pub extend AdjCoordinate with @debug.Debug::{to_repr}

///|
pub extend AdjCoordinate with Eq::{not_equal, equal}

///|
pub extend Anchor with @debug.Debug::{to_repr}

///|
pub extend Anchor with Eq::{not_equal, equal}

///|
pub extend AnimDirection with @debug.Debug::{to_repr}

///|
pub extend AnimDirection with Eq::{not_equal, equal}

///|
pub extend AnimEffect with @debug.Debug::{to_repr}

///|
pub extend AnimEffect with Eq::{not_equal, equal}

///|
pub extend AnimOrientation with @debug.Debug::{to_repr}

///|
pub extend AnimOrientation with Eq::{not_equal, equal}

///|
pub extend AnimStart with @debug.Debug::{to_repr}

///|
pub extend AnimStart with Eq::{not_equal, equal}

///|
pub extend AnimStep with @debug.Debug::{to_repr}

///|
pub extend AnimStep with Eq::{not_equal, equal}

///|
pub extend AutoFit with @debug.Debug::{to_repr}

///|
pub extend AutoFit with Eq::{not_equal, equal}

///|
pub extend AutoNumType with @debug.Debug::{to_repr}

///|
pub extend AutoNumType with Eq::{not_equal, equal}

///|
pub extend AutoShape with @debug.Debug::{to_repr}

///|
pub extend AutoShape with Eq::{not_equal, equal}

///|
pub extend Background with @debug.Debug::{to_repr}

///|
pub extend Background with Eq::{not_equal, equal}

///|
pub extend BackgroundProperties with @debug.Debug::{to_repr}

///|
pub extend BackgroundProperties with Eq::{not_equal, equal}

///|
pub extend BodyProperties with @debug.Debug::{to_repr}

///|
pub extend BodyProperties with Eq::{not_equal, equal}

///|
pub extend Bullet with @debug.Debug::{to_repr}

///|
pub extend Bullet with Eq::{not_equal, equal}

///|
pub extend CapsKind with @debug.Debug::{to_repr}

///|
pub extend CapsKind with Eq::{not_equal, equal}

///|
pub extend ConnectionEnd with @debug.Debug::{to_repr}

///|
pub extend ConnectionEnd with Eq::{not_equal, equal}

///|
pub extend ConnectionSite with @debug.Debug::{to_repr}

///|
pub extend ConnectionSite with Eq::{not_equal, equal}

///|
pub extend Connector with @debug.Debug::{to_repr}

///|
pub extend Connector with Eq::{not_equal, equal}

///|
pub extend CustomGeometry with @debug.Debug::{to_repr}

///|
pub extend CustomGeometry with Eq::{not_equal, equal}

///|
pub extend DateMode with @debug.Debug::{to_repr}

///|
pub extend DateMode with Eq::{not_equal, equal}

///|
pub extend EmphasisEffect with @debug.Debug::{to_repr}

///|
pub extend EmphasisEffect with Eq::{not_equal, equal}

///|
pub extend Field with @debug.Debug::{to_repr}

///|
pub extend Field with Eq::{not_equal, equal}

///|
pub extend GeomRect with @debug.Debug::{to_repr}

///|
pub extend GeomRect with Eq::{not_equal, equal}

///|
pub extend Geometry with @debug.Debug::{to_repr}

///|
pub extend Geometry with Eq::{not_equal, equal}

///|
pub extend GraphicFrame with @debug.Debug::{to_repr}

///|
pub extend GraphicFrame with Eq::{not_equal, equal}

///|
pub extend GraphicFrameContent with @debug.Debug::{to_repr}

///|
pub extend GraphicFrameContent with Eq::{not_equal, equal}

///|
pub extend GroupShape with @debug.Debug::{to_repr}

///|
pub extend GroupShape with Eq::{not_equal, equal}

///|
pub extend HyperlinkTarget with @debug.Debug::{to_repr}

///|
pub extend HyperlinkTarget with Eq::{not_equal, equal}

///|
pub extend HyperlinkTarget with Show::{to_string, output}

///|
pub extend ListStyle with @debug.Debug::{to_repr}

///|
pub extend ListStyle with Eq::{not_equal, equal}

///|
pub extend MediaInfo with @debug.Debug::{to_repr}

///|
pub extend MediaInfo with Eq::{not_equal, equal}

///|
pub extend MediaKind with @debug.Debug::{to_repr}

///|
pub extend MediaKind with Eq::{not_equal, equal}

///|
pub extend MotionCommand with @debug.Debug::{to_repr}

///|
pub extend MotionCommand with Eq::{not_equal, equal}

///|
pub extend MotionPath with @debug.Debug::{to_repr}

///|
pub extend MotionPath with Eq::{not_equal, equal}

///|
pub extend MotionPoint with @debug.Debug::{to_repr}

///|
pub extend MotionPoint with Eq::{not_equal, equal}

///|
pub extend Paragraph with @debug.Debug::{to_repr}

///|
pub extend Paragraph with Eq::{not_equal, equal}

///|
pub extend ParagraphContent with @debug.Debug::{to_repr}

///|
pub extend ParagraphContent with Eq::{not_equal, equal}

///|
pub extend ParagraphProperties with @debug.Debug::{to_repr}

///|
pub extend ParagraphProperties with Eq::{not_equal, equal}

///|
pub extend Path with @debug.Debug::{to_repr}

///|
pub extend Path with Eq::{not_equal, equal}

///|
pub extend PathCommand with @debug.Debug::{to_repr}

///|
pub extend PathCommand with Eq::{not_equal, equal}

///|
pub extend PathFillMode with @debug.Debug::{to_repr}

///|
pub extend PathFillMode with Eq::{not_equal, equal}

///|
pub extend PathPoint with @debug.Debug::{to_repr}

///|
pub extend PathPoint with Eq::{not_equal, equal}

///|
pub extend Picture with @debug.Debug::{to_repr}

///|
pub extend Picture with Eq::{not_equal, equal}

///|
pub extend Placeholder with @debug.Debug::{to_repr}

///|
pub extend Placeholder with Eq::{not_equal, equal}

///|
pub extend PlaceholderType with @debug.Debug::{to_repr}

///|
pub extend PlaceholderType with Eq::{not_equal, equal}

///|
pub extend Point with @debug.Debug::{to_repr}

///|
pub extend Point with Eq::{not_equal, equal}

///|
pub extend PresetShape with @debug.Debug::{to_repr}

///|
pub extend PresetShape with Eq::{not_equal, equal}

///|
pub extend ResolvedFonts with @debug.Debug::{to_repr}

///|
pub extend ResolvedFonts with Eq::{not_equal, equal}

///|
pub extend Run with @debug.Debug::{to_repr}

///|
pub extend Run with Eq::{not_equal, equal}

///|
pub extend RunProperties with @debug.Debug::{to_repr}

///|
pub extend RunProperties with Eq::{not_equal, equal}

///|
pub extend Shape with @debug.Debug::{to_repr}

///|
pub extend Shape with Eq::{not_equal, equal}

///|
pub extend ShapeAdjustValue with @debug.Debug::{to_repr}

///|
pub extend ShapeAdjustValue with Eq::{not_equal, equal}

///|
pub extend ShapeHyperlink with @debug.Debug::{to_repr}

///|
pub extend ShapeHyperlink with Eq::{not_equal, equal}

///|
pub extend Size with @debug.Debug::{to_repr}

///|
pub extend Size with Eq::{not_equal, equal}

///|
pub extend Slide with @debug.Debug::{to_repr}

///|
pub extend Slide with Eq::{not_equal, equal}

///|
pub extend SlideError with @debug.Debug::{to_repr}

///|
pub extend SlideError with Eq::{not_equal, equal}

///|
pub extend SlideError with Show::{to_string, output}

///|
pub extend StrikeKind with @debug.Debug::{to_repr}

///|
pub extend StrikeKind with Eq::{not_equal, equal}

///|
pub extend Table with @debug.Debug::{to_repr}

///|
pub extend Table with Eq::{not_equal, equal}

///|
pub extend TableCell with @debug.Debug::{to_repr}

///|
pub extend TableCell with Eq::{not_equal, equal}

///|
pub extend TableCellProperties with @debug.Debug::{to_repr}

///|
pub extend TableCellProperties with Eq::{not_equal, equal}

///|
pub extend TableProperties with @debug.Debug::{to_repr}

///|
pub extend TableProperties with Eq::{not_equal, equal}

///|
pub extend TableRow with @debug.Debug::{to_repr}

///|
pub extend TableRow with Eq::{not_equal, equal}

///|
pub extend TableStylePreset with @debug.Debug::{to_repr}

///|
pub extend TableStylePreset with Eq::{not_equal, equal}

///|
pub extend TextAlignment with @debug.Debug::{to_repr}

///|
pub extend TextAlignment with Eq::{not_equal, equal}

///|
pub extend TextBody with @debug.Debug::{to_repr}

///|
pub extend TextBody with Eq::{not_equal, equal}

///|
pub extend TextSpacing with @debug.Debug::{to_repr}

///|
pub extend TextSpacing with Eq::{not_equal, equal}

///|
pub extend Timeline with @debug.Debug::{to_repr}

///|
pub extend Timeline with Eq::{not_equal, equal}

///|
pub extend Transform with @debug.Debug::{to_repr}

///|
pub extend Transform with Eq::{not_equal, equal}

///|
pub extend Transition with @debug.Debug::{to_repr}

///|
pub extend Transition with Eq::{not_equal, equal}

///|
pub extend TransitionCorner with @debug.Debug::{to_repr}

///|
pub extend TransitionCorner with Eq::{not_equal, equal}

///|
pub extend TransitionDirection with @debug.Debug::{to_repr}

///|
pub extend TransitionDirection with Eq::{not_equal, equal}

///|
pub extend TransitionInOut with @debug.Debug::{to_repr}

///|
pub extend TransitionInOut with Eq::{not_equal, equal}

///|
pub extend TransitionKind with @debug.Debug::{to_repr}

///|
pub extend TransitionKind with Eq::{not_equal, equal}

///|
pub extend TransitionOrientation with @debug.Debug::{to_repr}

///|
pub extend TransitionOrientation with Eq::{not_equal, equal}

///|
pub extend TransitionSide with @debug.Debug::{to_repr}

///|
pub extend TransitionSide with Eq::{not_equal, equal}

///|
pub extend TransitionSpeed with @debug.Debug::{to_repr}

///|
pub extend TransitionSpeed with Eq::{not_equal, equal}

///|
pub extend UnderlineKind with @debug.Debug::{to_repr}

///|
pub extend UnderlineKind with Eq::{not_equal, equal}

///|
pub extend VerticalText with @debug.Debug::{to_repr}

///|
pub extend VerticalText with Eq::{not_equal, equal}

///|
pub extend VisualEffect with @debug.Debug::{to_repr}

///|
pub extend VisualEffect with Eq::{not_equal, equal}

///|
pub extend WrapKind with @debug.Debug::{to_repr}

///|
pub extend WrapKind with Eq::{not_equal, equal}
