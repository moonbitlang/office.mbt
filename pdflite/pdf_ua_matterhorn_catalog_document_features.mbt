///|
fn pdf_ua_matterhorn_test_20_001() -> PdfUAMatterhornTest {
  {
    name: "20-001",
    error: "Name entry is missing or has an empty string as its value in an Optional Content Configuration Dictionary in the Configs entry in the OCProperties entry in the Catalog dictionary.",
    section: "UA1:7.10-1",
  }
}

///|
fn pdf_ua_matterhorn_test_20_002() -> PdfUAMatterhornTest {
  {
    name: "20-002",
    error: "Name entry is missing or has an empty string as its value in an Optional Content Configuration Dictionary that is the value of the D entry in the OCProperties entry in the Catalog dictionary.",
    section: "UA1:7.10-1",
  }
}

///|
fn pdf_ua_matterhorn_test_20_003() -> PdfUAMatterhornTest {
  {
    name: "20-003",
    error: "An AS entry appears in an Optional Content Configuration Dictionary.",
    section: "UA1:7.10-2",
  }
}

///|
fn pdf_ua_matterhorn_test_21_001() -> PdfUAMatterhornTest {
  {
    name: "21-001",
    error: "The file specification dictionary for an embedded file does not contain F and UF entries.",
    section: "UA1:7.11-1",
  }
}

///|
fn pdf_ua_matterhorn_test_25_001() -> PdfUAMatterhornTest {
  {
    name: "25-001",
    error: "File contains the dynamicRender element with value “required”.",
    section: "UA1:7.15-1",
  }
}

///|
fn pdf_ua_matterhorn_test_26_001() -> PdfUAMatterhornTest {
  {
    name: "26-001",
    error: "The file is encrypted but does not contain a P entry in its encryption dictionary.",
    section: "UA1:7.16-1",
  }
}

///|
fn pdf_ua_matterhorn_test_26_002() -> PdfUAMatterhornTest {
  {
    name: "26-002",
    error: "The file is encrypted and does contain a P entry but the 10th bit position of the P entry is false.",
    section: "UA1:7.16-1",
  }
}
