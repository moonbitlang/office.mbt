// The serialization context (port of krilla's `serialize` module): object
// allocation, caching of shared resources, validation errors and the
// document-global objects that are only written when the document is
// finished.

///|
/// Settings for writing a document.
pub(all) struct SerializeSettings {
  /// Whether to pretty-print (accepted for API compatibility).
  pretty : Bool
  /// Whether to compress content streams.
  compress_content_streams : Bool
  /// Whether to avoid device color spaces (accepted for API compatibility;
  /// device color spaces are always used).
  no_device_cs : Bool
  /// Whether to keep the file ASCII compatible.
  ascii_compatible : Bool
  /// Whether to write XMP metadata.
  xmp_metadata : Bool
  /// The PDF version and validators.
  configuration : Configuration
  /// Whether to write a tagged document.
  enable_tagging : Bool
}

///|
pub fn SerializeSettings::default() -> SerializeSettings {
  {
    pretty: false,
    compress_content_streams: true,
    no_device_cs: false,
    ascii_compatible: false,
    xmp_metadata: true,
    configuration: Configuration::default(),
    enable_tagging: true,
  }
}

///|
pub fn SerializeSettings::pdf_version(self : SerializeSettings) -> PdfVersion {
  self.configuration.version
}

///|
pub fn SerializeSettings::validators(self : SerializeSettings) -> Validators {
  self.configuration.validators
}

///|
/// Information about a page that is known before it is serialized.
priv struct PageInfo {
  ref_ : Int
  surface_size : Size
  mut annotations : Array[(Int, Int?)]
  page_label : PageLabel
}

///|
/// An element of the parent tree.
priv enum StructParentElement {
  /// The index of the page and the number of marked content IDs present on
  /// that page.
  Page(Int, Int)
  /// An annotation.
  Annotation(AnnotationIdentifier)
}

///|
/// The serialization context.
pub struct SerializeContext {
  priv settings : SerializeSettings
  priv mut cur_ref : Int
  priv objects : Map[Int, Indirect]
  priv cache : Map[String, Int]
  priv validation_errors : Array[(ValidationError, Validators)]
  priv mut location : Location?
  priv page_infos : Array[PageInfo]
  priv page_tree_ref : Int
  priv font_containers : Array[FontContainer]
  priv named_destinations : Map[String, (Int, XyzDestination)]
  priv xyz_destinations : Array[(Int, XyzDestination)]
  priv pages : Array[(Int, InternalPage)]
  priv struct_parents : Array[StructParentElement]
  priv mut outline : Outline?
  priv mut tag_tree : TagTree?
  priv embedded_files : Map[String, Int]
  priv custom_heading_roles : Map[Int, Unit]
  priv separation_fallbacks : Array[(SeparationColorant, RegularColor)]
  priv mut metadata : Metadata?
}

///|
fn SerializeContext::new(settings : SerializeSettings) -> SerializeContext {
  // Override flags as required by the validators.
  let validators = settings.validators()
  let settings = {
    ..settings,
    enable_tagging: settings.enable_tagging || validators.requires_tagging(),
    xmp_metadata: settings.xmp_metadata || !validators.is_empty(),
  }
  {
    settings,
    cur_ref: 1,
    objects: {},
    cache: {},
    validation_errors: [],
    location: None,
    page_infos: [],
    page_tree_ref: 1,
    font_containers: [],
    named_destinations: {},
    xyz_destinations: [],
    pages: [],
    struct_parents: [],
    outline: None,
    tag_tree: None,
    embedded_files: {},
    custom_heading_roles: {},
    separation_fallbacks: [],
    metadata: None,
  }
}

///|
fn SerializeContext::new_ref(self : SerializeContext) -> Int {
  self.cur_ref += 1
  self.cur_ref
}

///|
fn SerializeContext::put(
  self : SerializeContext,
  ref_ : Int,
  obj : Obj,
) -> Unit {
  self.objects[ref_] = Plain(obj)
}

///|
/// Write a stream object, compressing its data if requested.
fn SerializeContext::put_stream(
  self : SerializeContext,
  ref_ : Int,
  dict : Array[(String, Obj)],
  data : Bytes,
  compress? : Bool = true,
) -> Unit {
  if compress && data.length() > 0 {
    let encoded = @flate.pdf_flate_encode(data)
    let dict = dict.copy()
    dict.push(("Filter", Name("FlateDecode")))
    self.objects[ref_] = Stream(dict, encoded)
  } else {
    self.objects[ref_] = Stream(dict, data)
  }
}

///|
/// Write a content stream, compressed if the settings ask for it.
fn SerializeContext::put_content_stream(
  self : SerializeContext,
  ref_ : Int,
  dict : Array[(String, Obj)],
  data : Bytes,
) -> Unit {
  self.put_stream(
    ref_,
    dict,
    data,
    compress=self.settings.compress_content_streams,
  )
}

///|
/// Look up or create a cached object.
fn SerializeContext::cached(
  self : SerializeContext,
  key : String,
  create : (Int) -> Unit,
) -> Int {
  match self.cache.get(key) {
    Some(r) => r
    None => {
      let r = self.new_ref()
      self.cache[key] = r
      create(r)
      r
    }
  }
}

///|
pub fn SerializeContext::serialize_settings(
  self : SerializeContext,
) -> SerializeSettings {
  self.settings
}

///|
fn SerializeContext::register_validation_error(
  self : SerializeContext,
  error : ValidationError,
) -> Unit {
  if self.settings.validators().prohibits(error) is Some(validators) {
    self.validation_errors.push((error, validators))
  }
}

///|
fn SerializeContext::set_location(
  self : SerializeContext,
  loc : Location,
) -> Unit {
  self.location = Some(loc)
}

///|
fn SerializeContext::reset_location(self : SerializeContext) -> Unit {
  self.location = None
}

///|
fn SerializeContext::validate_separation(
  self : SerializeContext,
  space : SeparationSpace,
) -> Unit {
  for entry in self.separation_fallbacks {
    if entry.0 == space.colorant {
      if entry.1 != space.fallback {
        self.register_validation_error(
          InconsistentSeparationFallback(space.colorant),
        )
      }
      return
    }
  }
  self.separation_fallbacks.push((space.colorant, space.fallback))
}

///|
/// Register a color space resource for a color, `None` for device color
/// spaces.
fn SerializeContext::register_colorspace(
  self : SerializeContext,
  color : Color,
) -> Int? {
  match color {
    Regular(_) => None
    Separation(_, space) => {
      self.validate_separation(space)
      let key = "sep:\{Repr(space)}"
      Some(
        self.cached(key, r => {
          let name = match space.colorant {
            AllColorants => "All"
            NoColorant => "None"
            Custom(n) => n
          }
          let (alt, comps) = match space.fallback {
            Rgb(_, _, _) => ("DeviceRGB", space.fallback.to_pdf_color())
            Luma(_) => ("DeviceGray", space.fallback.to_pdf_color())
            Cmyk(_, _, _, _) => ("DeviceCMYK", space.fallback.to_pdf_color())
          }
          // A type 2 (exponential) function from the tint (white for no
          // ink) to the fallback color (full ink).
          let c0 = if alt == "DeviceCMYK" { 0.0 } else { 1.0 }
          let range = []
          for _ in comps {
            range.push(Real(0.0))
            range.push(Real(1.0))
          }
          let func = Dict([
            ("FunctionType", Int(2)),
            ("Domain", Arr([Int(0), Int(1)])),
            ("Range", Arr(range)),
            ("C0", Arr(comps.map(_ => Real(c0)))),
            ("C1", Arr(comps.map(c => Real(c)))),
            ("N", Int(1)),
          ])
          self.put(r, Arr([Name("Separation"), Name(name), Name(alt), func]))
        }),
      )
    }
  }
}

///|
/// Register a page as struct parent of its marked content.
fn SerializeContext::register_page_struct_parent(
  self : SerializeContext,
  page_index : Int,
  num_mcids : Int,
) -> Int? {
  if self.settings.enable_tagging {
    if num_mcids == 0 {
      return None
    }
    let id = self.struct_parents.length()
    self.struct_parents.push(Page(page_index, num_mcids))
    Some(id)
  } else {
    None
  }
}

///|
fn SerializeContext::register_annotation_parent(
  self : SerializeContext,
  ai : AnnotationIdentifier,
) -> Int? {
  if self.settings.enable_tagging {
    let id = self.struct_parents.length()
    self.struct_parents.push(Annotation(ai))
    Some(id)
  } else {
    None
  }
}

///|
fn SerializeContext::register_xyz_destination(
  self : SerializeContext,
  dest : XyzDestination,
) -> Int {
  let key = "xyz:\{dest.page_index}:\{dest.point.x}:\{dest.point.y}"
  self.cached(key, r => self.xyz_destinations.push((r, dest)))
}

///|
/// Register a named destination; `None` if a different destination with
/// the same name exists.
fn SerializeContext::register_named_destination(
  self : SerializeContext,
  nd : NamedDestination,
) -> Int? {
  match self.named_destinations.get(nd.name) {
    Some((r, existing)) => if existing == nd.xyz_dest { Some(r) } else { None }
    None => {
      let r = self.register_xyz_destination(nd.xyz_dest)
      self.named_destinations[nd.name] = (r, nd.xyz_dest)
      Some(r)
    }
  }
}

///|
fn SerializeContext::register_font_container(
  self : SerializeContext,
  font : Font,
) -> FontContainer {
  for c in self.font_containers {
    if physical_equal(c.font, font) {
      return c
    }
  }
  let c = FontContainer::new(font, self.new_ref())
  self.font_containers.push(c)
  c
}

///|
/// Register an ExtGState and return its reference.
fn SerializeContext::register_ext_g_state(
  self : SerializeContext,
  state : ExtGState,
) -> Int {
  let key = "gs:\{Repr(state)}"
  self.cached(key, r => {
    let d = DictBuilder::new()
    d.set("Type", Name("ExtGState"))
    if state.non_stroking_alpha is Some(a) {
      if a != 1.0 {
        self.register_validation_error(Transparency(self.location))
      }
      d.set("ca", Real(a))
    }
    if state.stroking_alpha is Some(a) {
      if a != 1.0 {
        self.register_validation_error(Transparency(self.location))
      }
      d.set("CA", Real(a))
    }
    if state.blend_mode is Some(bm) {
      if bm != "Normal" {
        self.register_validation_error(Transparency(self.location))
      }
      d.set("BM", Name(bm))
    }
    if state.mask is Some(m) {
      self.register_validation_error(Transparency(self.location))
      d.set("SMask", Ref(m))
    }
    self.put(r, d.finish())
  })
}
