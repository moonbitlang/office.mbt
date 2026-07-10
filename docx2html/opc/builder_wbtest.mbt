///|
/// White-box: reach build()-time validation directly (the public setters
/// already reject these states, and the fields are private outside the
/// package — this pins the authoritative-revalidation layer itself).
test "build revalidates duplicate relationship ids from raw state" {
  let builder : PackageBuilder = {
    parts: [("word/document.xml", b"<d/>")],
    defaults: {
      "rels": "application/vnd.openxmlformats-package.relationships+xml",
      "xml": "application/xml",
    },
    overrides: Map([]),
    relationships: {
      "": [
        {
          id: "rId1",
          relationship_type: "t",
          target: "word/document.xml",
          external: false,
        },
        {
          id: "rId1",
          relationship_type: "t",
          target: "word/document.xml",
          external: false,
        },
      ],
    },
  }
  try builder.build() catch {
    PackageBuildError(message) =>
      inspect(
        message.has_prefix("duplicate relationship Id 'rId1' for source ''"),
        content="true",
      )
  } noraise {
    _ => fail("expected build-time duplicate-id rejection")
  }
}

///|
test "build revalidates part names from raw state" {
  let builder : PackageBuilder = {
    parts: [("word/document.xml", b"<d/>"), ("word/document.xml", b"<d/>")],
    defaults: { "xml": "application/xml" },
    overrides: Map([]),
    relationships: Map([]),
  }
  try builder.build() catch {
    PackageBuildError(message) =>
      inspect(
        message.has_prefix("duplicate part name: word/document.xml"),
        content="true",
      )
  } noraise {
    _ => fail("expected build-time duplicate-part rejection")
  }
}
