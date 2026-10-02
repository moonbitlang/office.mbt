// Resource dictionaries, graphics states and content streams (port of
// krilla's `resource`, `graphics::graphics_state` and `stream` modules).

///|
/// The kind of a resource.
priv enum ResourceKind {
  ExtGState
  ColorSpace
  Pattern
  Shading
  XObject
  Font
} derive(Eq)

///|
fn ResourceKind::prefix(self : ResourceKind) -> String {
  match self {
    ExtGState => "g"
    ColorSpace => "c"
    Pattern => "p"
    Shading => "s"
    XObject => "x"
    Font => "f"
  }
}

///|
fn ResourceKind::dict_key(self : ResourceKind) -> String {
  match self {
    ExtGState => "ExtGState"
    ColorSpace => "ColorSpace"
    Pattern => "Pattern"
    Shading => "Shading"
    XObject => "XObject"
    Font => "Font"
  }
}

///|
/// The resources used by a content stream.
pub struct ResourceDictionary {
  priv entries : Array[(ResourceKind, Int, String)]
}

///|
fn ResourceDictionary::new() -> ResourceDictionary {
  { entries: [] }
}

///|
/// Register a resource and return its name.
fn ResourceDictionary::register(
  self : ResourceDictionary,
  kind : ResourceKind,
  ref_ : Int,
) -> String {
  let mut count = 0
  for e in self.entries {
    if e.0 == kind {
      if e.1 == ref_ {
        return e.2
      }
      count += 1
    }
  }
  let name = "\{kind.prefix()}\{count}"
  self.entries.push((kind, ref_, name))
  name
}

///|
/// The resource dictionary object.
fn ResourceDictionary::to_pdf(self : ResourceDictionary) -> Obj {
  let d = DictBuilder::new()
  for kind in [ExtGState, ColorSpace, Pattern, Shading, XObject, Font] {
    let sub = []
    for e in self.entries {
      if e.0 == kind {
        sub.push((e.2, Ref(e.1)))
      }
    }
    if !sub.is_empty() {
      d.set(kind.dict_key(), Dict(sub))
    }
  }
  d.finish()
}

///|
/// An external graphics state.
pub(all) struct ExtGState {
  non_stroking_alpha : Double?
  stroking_alpha : Double?
  blend_mode : String?
  mask : Int?
} derive(Eq, Show)

///|
fn ExtGState::new() -> ExtGState {
  { non_stroking_alpha: None, stroking_alpha: None, blend_mode: None, mask: None }
}

///|
fn ExtGState::empty(self : ExtGState) -> Bool {
  self.mask is None &&
  self.stroking_alpha is None &&
  self.non_stroking_alpha is None &&
  self.blend_mode is None
}

///|
fn ExtGState::combine(self : ExtGState, other : ExtGState) -> ExtGState {
  {
    non_stroking_alpha: opt_or(other.non_stroking_alpha, self.non_stroking_alpha),
    stroking_alpha: opt_or(other.stroking_alpha, self.stroking_alpha),
    blend_mode: opt_or(other.blend_mode, self.blend_mode),
    mask: opt_or(other.mask, self.mask),
  }
}

///|
priv struct GraphicsState {
  ext_g_state : ExtGState
  ctm : Transform
}

///|
/// A stack of graphics states.
priv struct GraphicsStates {
  states : Array[GraphicsState]
}

///|
fn GraphicsStates::new() -> GraphicsStates {
  { states: [{ ext_g_state: ExtGState::new(), ctm: Transform::identity() }] }
}

///|
fn GraphicsStates::cur(self : GraphicsStates) -> GraphicsState {
  self.states[self.states.length() - 1]
}

///|
fn GraphicsStates::save_state(self : GraphicsStates) -> Unit {
  self.states.push(self.cur())
}

///|
fn GraphicsStates::restore_state(self : GraphicsStates) -> Unit {
  self.states.pop() |> ignore
}

///|
fn GraphicsStates::combine(self : GraphicsStates, other : ExtGState) -> Unit {
  let cur = self.cur()
  self.states[self.states.length() - 1] = {
    ..cur,
    ext_g_state: cur.ext_g_state.combine(other),
  }
}

///|
fn GraphicsStates::transform(self : GraphicsStates, ts : Transform) -> Unit {
  let cur = self.cur()
  self.states[self.states.length() - 1] = { ..cur, ctm: cur.ctm.pre_concat(ts) }
}

///|
fn GraphicsStates::transform_bbox(self : GraphicsStates, bbox : Rect) -> Rect {
  bbox.transform(self.cur().ctm)
}

///|
/// A finished content stream with its resources.
pub struct Stream {
  priv content : Bytes
  priv bbox : Rect
  priv validation_errors : Array[ValidationError]
  priv resources : ResourceDictionary
  priv uses_mask : Bool
}

///|
pub fn Stream::empty() -> Stream {
  {
    content: Bytes::default(),
    bbox: { left: 0.0, top: 0.0, right: 1.0, bottom: 1.0 },
    validation_errors: [],
    resources: ResourceDictionary::new(),
    uses_mask: false,
  }
}

///|
pub fn Stream::is_empty(self : Stream) -> Bool {
  self.content.length() == 0
}

///|
fn[T] opt_or(a : T?, b : T?) -> T? {
  match a {
    Some(_) => a
    None => b
  }
}
