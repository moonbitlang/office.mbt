///|
priv enum PdfUAMatterhornContext {
  PdfUAMatterhornArtifact
  PdfUAMatterhornContent
  PdfUAMatterhornOther
}

///|
priv struct PdfUAMatterhornTest {
  name : String
  error : String
  section : String
}

///|
priv struct PdfUAMatterhornFailure {
  name : String
  error : String
  section : String
  extra : Json
}

///|
priv struct PdfUAMatterhornStructNode {
  name : PdfName
  attrs : Array[PdfName]
  children : Array[PdfUAMatterhornStructNode]
}

///|
fn pdf_ua_matterhorn_failure(
  check : PdfUAMatterhornTest,
  extra : Json,
) -> PdfUAMatterhornFailure {
  { name: check.name, error: check.error, section: check.section, extra }
}

///|
fn PdfUAMatterhornFailure::to_json(self : PdfUAMatterhornFailure) -> Json {
  Json::object(
    Map([
      ("name", Json::string(self.name)),
      ("section", Json::string(self.section)),
      ("error", Json::string(self.error)),
      ("extra", self.extra),
    ]),
  )
}
