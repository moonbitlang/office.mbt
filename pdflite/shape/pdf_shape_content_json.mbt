///|
fn pdf_path_point_content_json(point : Point2) -> Json {
  Json::object(
    Map([("x", Json::number(point.x)), ("y", Json::number(point.y))]),
  )
}

///|
/// Return cpdfcontent's JSON shape for one path segment.
pub fn PdfPathSegment::content_json(self : PdfPathSegment) -> Json {
  match self {
    PdfPathStraight(start, finish) =>
      Json::object(
        Map([
          (
            "line",
            Json::array([
              pdf_path_point_content_json(start),
              pdf_path_point_content_json(finish),
            ]),
          ),
        ]),
      )
    PdfPathBezier(start, control1, control2, finish) =>
      Json::object(
        Map([
          (
            "bezier",
            Json::array([
              pdf_path_point_content_json(start),
              pdf_path_point_content_json(control1),
              pdf_path_point_content_json(control2),
              pdf_path_point_content_json(finish),
            ]),
          ),
        ]),
      )
  }
}

///|
/// Compatibility wrapper for `PdfPathSegment::content_json`.
pub fn pdf_path_segment_content_json(segment : PdfPathSegment) -> Json {
  segment.content_json()
}

///|
/// Return cpdfcontent's JSON shape for one subpath.
///
/// The hole flag is intentionally not emitted, matching `cpdfcontent.ml`.
pub fn PdfPathSubpath::content_json(self : PdfPathSubpath) -> Json {
  Json::object(
    Map([
      ("closed", Json::boolean(self.closure == PdfPathClosed)),
      (
        "segments",
        Json::array([ for segment in self.segments => segment.content_json() ]),
      ),
    ]),
  )
}

///|
/// Compatibility wrapper for `PdfPathSubpath::content_json`.
pub fn pdf_path_subpath_content_json(subpath : PdfPathSubpath) -> Json {
  subpath.content_json()
}

///|
fn pdf_path_winding_rule_content_string(rule : PdfPathWindingRule) -> String {
  match rule {
    PdfPathEvenOdd => "even-odd"
    PdfPathNonZero => "non-zero"
  }
}

///|
/// Return cpdfcontent's JSON shape for a drawn path.
pub fn PdfDrawnPath::content_json(self : PdfDrawnPath) -> Json {
  Json::object(
    Map([
      (
        "winding",
        Json::string(
          pdf_path_winding_rule_content_string(self.path.winding_rule),
        ),
      ),
      (
        "subpaths",
        Json::array(
          [
            for subpath in self.path.subpaths => subpath.content_json()
          ],
        ),
      ),
      ("stroked", Json::boolean(self.stroked)),
      ("filled", Json::boolean(self.filled)),
    ]),
  )
}

///|
/// Compatibility wrapper for `PdfDrawnPath::content_json`.
pub fn pdf_drawn_path_content_json(path : PdfDrawnPath) -> Json {
  path.content_json()
}
