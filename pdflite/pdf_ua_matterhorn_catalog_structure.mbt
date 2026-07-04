///|
fn pdf_ua_matterhorn_test_09_004() -> PdfUAMatterhornTest {
  {
    name: "09-004",
    error: "A table-related structure element is used in a way that does not conform to the syntax defined in ISO 32000-1, Table 337.",
    section: "UA1-7.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_09_005() -> PdfUAMatterhornTest {
  {
    name: "09-005",
    error: "A list-related structure element is used in a way that does not conform to Table 336 in ISO 32000-1.",
    section: "UA1-7.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_09_006() -> PdfUAMatterhornTest {
  {
    name: "09-006",
    error: "A TOC-related structure element is used in a way that does not conform to Table 333 in ISO 32000-1.",
    section: "UA1-7.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_09_007() -> PdfUAMatterhornTest {
  {
    name: "09-007",
    error: "A Ruby-related structure element is used in a way that does not conform to Table 338 in ISO 32000-1.",
    section: "UA1-7.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_09_008() -> PdfUAMatterhornTest {
  {
    name: "09-008",
    error: "A Warichu-related structure element is used in a way that does not conform to Table 338 in ISO 32000-1.",
    section: "UA1-7.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_10_001() -> PdfUAMatterhornTest {
  {
    name: "10-001",
    error: "Character code cannot be mapped to Unicode.",
    section: "UA1:7.2-2",
  }
}

///|
fn pdf_ua_matterhorn_test_11_001() -> PdfUAMatterhornTest {
  {
    name: "11-001",
    error: "Natural language for text in page content cannot be determined.",
    section: "UA1:7.2-3",
  }
}

///|
fn pdf_ua_matterhorn_test_11_002() -> PdfUAMatterhornTest {
  {
    name: "11-002",
    error: "Natural language for text in Alt, ActualText and E attributes cannot be determined.",
    section: "UA1:7.2-3",
  }
}

///|
fn pdf_ua_matterhorn_test_11_003() -> PdfUAMatterhornTest {
  {
    name: "11-003",
    error: "Natural language in the Outline entries cannot be determined.",
    section: "UA1:7.2-3",
  }
}

///|
fn pdf_ua_matterhorn_test_11_004() -> PdfUAMatterhornTest {
  {
    name: "11-004",
    error: "Natural language in the Contents entry for annotations cannot be determined.",
    section: "UA1:7.2-3",
  }
}

///|
fn pdf_ua_matterhorn_test_11_005() -> PdfUAMatterhornTest {
  {
    name: "11-005",
    error: "Natural language in the TU entry for form fields cannot be determined.",
    section: "UA1:7.2-3",
  }
}

///|
fn pdf_ua_matterhorn_test_11_006() -> PdfUAMatterhornTest {
  {
    name: "11-006",
    error: "Natural language for document metadata cannot be determined.",
    section: "UA1:7.2-3",
  }
}

///|
fn pdf_ua_matterhorn_test_13_004() -> PdfUAMatterhornTest {
  {
    name: "13-004",
    error: "<Figure> tag alternative or replacement text missing.",
    section: "UA1:7.3-3",
  }
}

///|
fn pdf_ua_matterhorn_test_14_002() -> PdfUAMatterhornTest {
  {
    name: "14-002",
    error: "Does use numbered headings, but the first heading tag is not <H1>.",
    section: "UA1:7.4.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_14_003() -> PdfUAMatterhornTest {
  {
    name: "14-003",
    error: "Numbered heading levels in descending sequence are skipped (Example: <H3> follows directly after <H1>).",
    section: "UA1:7.4-1",
  }
}

///|
fn pdf_ua_matterhorn_test_14_006() -> PdfUAMatterhornTest {
  {
    name: "14-006",
    error: "A node contains more than one <H> tag.",
    section: "UA1:7.4.4-1",
  }
}

///|
fn pdf_ua_matterhorn_test_14_007() -> PdfUAMatterhornTest {
  {
    name: "14-007",
    error: "Document uses both <H> and <H#> tags.",
    section: "UA1:7.4.4-3",
  }
}

///|
fn pdf_ua_matterhorn_test_15_003() -> PdfUAMatterhornTest {
  {
    name: "15-003",
    error: "In a table not organized with Headers attributes and IDs, a <TH> cell does not contain a Scope attribute.",
    section: "UA1:7.5-2",
  }
}

///|
fn pdf_ua_matterhorn_test_17_002() -> PdfUAMatterhornTest {
  {
    name: "17-002",
    error: "<Formula> tag is missing an Alt attribute.",
    section: "UA1:7.7-1",
  }
}

///|
fn pdf_ua_matterhorn_test_17_003() -> PdfUAMatterhornTest {
  {
    name: "17-003",
    error: "Unicode mapping requirements are not met.",
    section: "UA1:7.7-2",
  }
}

///|
fn pdf_ua_matterhorn_test_19_003() -> PdfUAMatterhornTest {
  {
    name: "19-003",
    error: "ID entry of the <Note> tag is not present.",
    section: "UA1:7.9-2",
  }
}

///|
fn pdf_ua_matterhorn_test_19_004() -> PdfUAMatterhornTest {
  {
    name: "19-004",
    error: "ID entry of the <Note> tag is non-unique.",
    section: "UA1:7.9-2",
  }
}
