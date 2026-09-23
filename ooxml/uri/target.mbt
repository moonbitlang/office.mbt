///|
/// Returns whether an internal relationship target starts with a URI scheme.
fn target_has_uri_scheme(target : String) -> Bool {
  let mut index = 0
  for character in target {
    if character == ':' {
      return index > 0
    }
    if character == '/' || character == '?' || character == '#' {
      return false
    }
    let valid = if index == 0 {
      character.is_ascii_alphabetic()
    } else {
      character.is_ascii_alphabetic() ||
      character.is_ascii_digit() ||
      character == '+' ||
      character == '-' ||
      character == '.'
    }
    if !valid {
      return false
    }
    index += 1
  }
  false
}

///|
/// RFC 3986 `path-noscheme` forbids a colon in the first relative segment.
/// Prefixing that segment with `./` is the unambiguous spelling and remains
/// valid (`./1:document.xml`).
fn target_has_ambiguous_first_segment_colon(target : String) -> Bool {
  if target.has_prefix("/") {
    return false
  }
  for character in target {
    if character == '/' {
      return false
    }
    if character == ':' {
      return true
    }
  }
  false
}

///|
/// Resolves one internal relationship target against an archive-directory
/// base. Package-rooted targets (`/word/media/x.png`) and relative targets use
/// the same dot-segment normalization. Empty segments, URI schemes,
/// query/fragment text, backslashes, empty results, and any traversal above
/// the package root fail closed instead of being silently clamped.
pub fn resolve_target(base : String, target : String) -> String? {
  if target == "" ||
    target.has_prefix("//") ||
    target.contains("\\") ||
    target.contains("?") ||
    target.contains("#") ||
    target_has_ambiguous_first_segment_colon(target) ||
    target_has_uri_scheme(target) {
    return None
  }
  let segments : Array[String] = []
  if !target.has_prefix("/") && base != "" {
    if base.has_prefix("/") {
      return None
    }
    let normalized_base = if base.has_suffix("/") {
      base[:base.length() - 1]
    } else {
      base
    }
    if normalized_base != "" {
      for segment in normalized_base.split("/") {
        if segment == "" || segment == "." || segment == ".." {
          return None
        }
        segments.push(segment.to_owned())
      }
    }
  }
  let path = if target.has_prefix("/") { target[1:] } else { target }
  for segment in path.split("/") {
    match segment {
      "" => return None
      "." => ()
      ".." =>
        if segments.length() > 0 {
          let _ = segments.pop()
        } else {
          return None
        }
      other => segments.push(other.to_owned())
    }
  }
  if segments.length() == 0 {
    None
  } else {
    Some(segments.join("/"))
  }
}
