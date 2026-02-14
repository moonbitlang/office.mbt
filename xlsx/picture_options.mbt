///|
pub(all) enum PicturePositioning {
  OneCell
  TwoCell
  Absolute
} derive(Show)

///|
pub struct GraphicOptions {
  mut offset_x : Int?
  mut offset_y : Int?
  mut scale_x : Double?
  mut scale_y : Double?
  mut hyperlink : String?
  mut hyperlink_type : HyperlinkType?
  mut name : String?
  mut alt_text : String?
  mut lock_aspect_ratio : Bool?
  mut auto_fit : Bool?
  mut auto_fit_ignore_aspect : Bool?
  mut print_object : Bool?
  mut locked : Bool?
  mut positioning : PicturePositioning?
} derive(Show)

///|
pub fn GraphicOptions::new() -> GraphicOptions {
  {
    offset_x: None,
    offset_y: None,
    scale_x: None,
    scale_y: None,
    hyperlink: None,
    hyperlink_type: None,
    name: None,
    alt_text: None,
    lock_aspect_ratio: None,
    auto_fit: None,
    auto_fit_ignore_aspect: None,
    print_object: None,
    locked: None,
    positioning: None,
  }
}

///|
pub fn GraphicOptions::with_values(
  offset_x? : Int,
  offset_y? : Int,
  scale_x? : Double,
  scale_y? : Double,
  hyperlink? : String,
  hyperlink_type? : HyperlinkType,
  name? : String,
  alt_text? : String,
  lock_aspect_ratio? : Bool,
  auto_fit? : Bool,
  auto_fit_ignore_aspect? : Bool,
  print_object? : Bool,
  locked? : Bool,
  positioning? : PicturePositioning,
) -> GraphicOptions {
  let opts = GraphicOptions::new()
  match offset_x {
    Some(value) => opts.offset_x = Some(value)
    None => ()
  }
  match offset_y {
    Some(value) => opts.offset_y = Some(value)
    None => ()
  }
  match scale_x {
    Some(value) => opts.scale_x = Some(value)
    None => ()
  }
  match scale_y {
    Some(value) => opts.scale_y = Some(value)
    None => ()
  }
  match hyperlink {
    Some(value) => opts.hyperlink = Some(value)
    None => ()
  }
  match hyperlink_type {
    Some(value) => opts.hyperlink_type = Some(value)
    None => ()
  }
  match name {
    Some(value) => opts.name = Some(value)
    None => ()
  }
  match alt_text {
    Some(value) => opts.alt_text = Some(value)
    None => ()
  }
  match lock_aspect_ratio {
    Some(value) => opts.lock_aspect_ratio = Some(value)
    None => ()
  }
  match auto_fit {
    Some(value) => opts.auto_fit = Some(value)
    None => ()
  }
  match auto_fit_ignore_aspect {
    Some(value) => opts.auto_fit_ignore_aspect = Some(value)
    None => ()
  }
  match print_object {
    Some(value) => opts.print_object = Some(value)
    None => ()
  }
  match locked {
    Some(value) => opts.locked = Some(value)
    None => ()
  }
  match positioning {
    Some(value) => opts.positioning = Some(value)
    None => ()
  }
  opts
}

///|
pub type Picture = Image
