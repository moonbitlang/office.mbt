///|
fn pdf_ua_matterhorn_test_28_002() -> PdfUAMatterhornTest {
  {
    name: "28-002",
    error: "An annotation, other than of subtype Widget, Link and PrinterMark, is not a direct child of an <Annot> structure element.",
    section: "UA1:7.18.1-2",
  }
}

///|
fn pdf_ua_matterhorn_test_28_004() -> PdfUAMatterhornTest {
  {
    name: "28-004",
    error: "An annotation, other than of subtype Widget, does not have a Contents entry and does not have an alternative description (in the form of an Alt entry in the enclosing structure element).",
    section: "UA1:7.18.1-4",
  }
}

///|
fn pdf_ua_matterhorn_test_28_005() -> PdfUAMatterhornTest {
  {
    name: "28-005",
    error: "A form field does not have a TU entry and does not have an alternative description (in the form of an Alt entry in the enclosing structure element).",
    section: "UA1:7.18.1-4",
  }
}

///|
fn pdf_ua_matterhorn_test_28_006() -> PdfUAMatterhornTest {
  {
    name: "28-006",
    error: "An annotation with subtype undefined in ISO 32000 does not meet 7.18.1.",
    section: "UA1:7.18.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_007() -> PdfUAMatterhornTest {
  {
    name: "28-007",
    error: "An annotation of subtype TrapNet exists.",
    section: "UA1:7.18.2-2",
  }
}

///|
fn pdf_ua_matterhorn_test_28_008() -> PdfUAMatterhornTest {
  {
    name: "28-008",
    error: "A page containing an annotation does not contain a Tabs entry",
    section: "UA1:7.18.3-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_009() -> PdfUAMatterhornTest {
  {
    name: "28-009",
    error: "A page containing an annotation has a Tabs entry with a value other than S.",
    section: "UA1:7.18.3-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_010() -> PdfUAMatterhornTest {
  {
    name: "28-010",
    error: "A widget annotation is not nested within a <Form> tag.",
    section: "UA1:7.18.4-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_011() -> PdfUAMatterhornTest {
  {
    name: "28-011",
    error: "A link annotation is not nested within a <Link> tag.",
    section: "UA1:7.18.5-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_012() -> PdfUAMatterhornTest {
  {
    name: "28-012",
    error: "A link annotation does not include an alternate description in its Contents entry.",
    section: "UA1:7.18.5-2",
  }
}

///|
fn pdf_ua_matterhorn_test_28_014() -> PdfUAMatterhornTest {
  {
    name: "28-014",
    error: "CT entry is missing from the media clip data dictionary.",
    section: "",
  }
}

///|
fn pdf_ua_matterhorn_test_28_015() -> PdfUAMatterhornTest {
  {
    name: "28-015",
    error: "Alt entry is missing from the media clip data dictionary.",
    section: "UA1:7.18.6.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_016() -> PdfUAMatterhornTest {
  {
    name: "28-016",
    error: "File attachment annotations do not conform to 7.11.",
    section: "UA1:7.18.7-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_017() -> PdfUAMatterhornTest {
  {
    name: "28-017",
    error: "A PrinterMark annotation is included in the logical structure.",
    section: "UA1:7.18.8-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_018() -> PdfUAMatterhornTest {
  {
    name: "28-018",
    error: "The appearance stream of a PrinterMark annotation is not marked as Artifact.",
    section: "UA1:7.18.8-2",
  }
}

///|
fn pdf_ua_matterhorn_test_30_001() -> PdfUAMatterhornTest {
  {
    name: "30-001",
    error: "A reference XObject is present.",
    section: "UA1:7.2",
  }
}

///|
fn pdf_ua_matterhorn_test_30_002() -> PdfUAMatterhornTest {
  {
    name: "30-002",
    error: "Form XObject contains MCIDs and is referenced more than once.",
    section: "UA1:7.21.3.1-1",
  }
}
