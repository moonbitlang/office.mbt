///|
/// A document with `n` pages of 200x100; `f` is called with the document
/// and each page before it is finished.
fn pages_doc(
  n : Int,
  f : (@export.Document, @export.Page) -> Unit raise,
  settings? : @export.SerializeSettings = plain_settings(),
  before_finish? : (@export.Document) -> Unit raise = _ => (),
) -> Bytes raise {
  let doc = @export.Document::new_with(settings)
  for _ in 0..<n {
    let page = doc.start_page_with(
      @export.PageSettings::from_wh(200.0, 100.0).unwrap(),
    )
    page.surface().finish()
    f(doc, page)
    page.finish()
  }
  before_finish(doc)
  doc.finish()
}

///|
fn link_rect() -> @export.Rect {
  @export.Rect::from_xywh(10.0, 20.0, 30.0, 10.0).unwrap()
}

///|
test "URI link annotations" {
  let p = parse(
    pages_doc(1, (_, page) => {
      page.add_annotation(
        @export.Annotation::new_link(
          @export.LinkAnnotation::new(
            link_rect(),
            Action(Link("https://example.com/a b")),
          ),
          Some("Example"),
        ),
      )
    }),
  )
  let annots = p.items(p.get(p.page(0), "Annots"))
  inspect(annots.length(), content="1")
  // The rectangle is flipped into PDF coordinates.
  inspect(
    p.show(annots[0]),
    content=(
      #|<</Type /Annot /Subtype /Link /Rect [10 70 40 80] /Border [0 0 0] /A <</Type /Action /S /URI /URI (https://example.com/a b)>> /F 4 /Contents (Example)>>
    ),
  )
  // Annotations are not tagged without tagging, so there are no tabs.
  inspect(p.has(p.page(0), "Tabs"), content="false")
}

///|
test "links to positions on pages" {
  let p = parse(
    pages_doc(2, (_, page) => {
      if page.index() == 0 {
        let dest = @export.XyzDestination::new(
          1,
          @export.Point::from_xy(5.0, 30.0),
        )
        page.add_annotation(
          @export.Annotation::new_link(
            @export.LinkAnnotation::new(link_rect(), Destination(Xyz(dest))),
            None,
          ),
        )
        // Equal destinations share an object.
        page.add_annotation(
          @export.Annotation::new_link(
            @export.LinkAnnotation::new(link_rect(), Destination(Xyz(dest))),
            None,
          ),
        )
      }
    }),
  )
  let annots = p.items(p.get(p.page(0), "Annots"))
  inspect(
    p.show(annots[0]),
    content=(
      #|<</Type /Annot /Subtype /Link /Rect [10 70 40 80] /Border [0 0 0] /Dest R /F 4>>
    ),
  )
  let dest = p.items(p.get(annots[0], "Dest"))
  inspect(
    dest.map(d => p.show(d)).join(" "),
    content=(
      #|<</Type /Page /Resources <<>> /MediaBox [0 0 200 100] /Parent R /Contents R>> /XYZ 5 70 null
    ),
  )
  // The destination points to the second page, at the flipped position.
  inspect(
    p.show(p.get(annots[0], "Dest")) == p.show(p.get(annots[1], "Dest")),
    content="true",
  )
  let pages_kids = p.items(p.path(p.catalog(), ["Pages", "Kids"]))
  inspect(p.show(dest[0]) == p.show(pages_kids[1]), content="true")
  let dest_raw = match p.resolve(p.get(annots[0], "Dest")) {
    PdfArray(items) => items[0]
    _ => PdfNull
  }
  let kids_raw = match p.path(p.catalog(), ["Pages", "Kids"]) {
    PdfArray(items) => items[1]
    _ => PdfNull
  }
  inspect(dest_raw == kids_raw, content="true")
}

///|
test "quad points are only written from PDF 1.6 on" {
  let quads = [
    [
      @export.Point::from_xy(0.0, 0.0),
      @export.Point::from_xy(10.0, 0.0),
      @export.Point::from_xy(10.0, 5.0),
      @export.Point::from_xy(0.0, 5.0),
    ],
  ]
  let link = @export.LinkAnnotation::new_with_quad_points(
    quads,
    Action(Link("x")),
  )
  // The rectangle is the bounding box of the quads, slightly expanded.
  debug_inspect(
    link.rect,
    content=(
      #|{ left: -0.001, top: -0.001, right: 10.001, bottom: 5.001 }
    ),
  )
  let annot = (version : @export.PdfVersion) => {
    let p = parse(
      pages_doc(
        1,
        (_, page) => {
          page.add_annotation(@export.Annotation::new_link(link, Some("x")))
        },
        settings=settings_with(version~),
      ),
    )
    p.show(p.items(p.get(p.page(0), "Annots"))[0])
  }
  inspect(
    annot(Pdf15),
    content=(
      #|<</Type /Annot /Subtype /Link /Rect [-0.001 94.999 10.001 100.001] /Border [0 0 0] /A <</Type /Action /S /URI /URI (x)>> /F 4 /Contents (x)>>
    ),
  )
  inspect(
    annot(Pdf16),
    content=(
      #|<</Type /Annot /Subtype /Link /Rect [-0.001 94.999 10.001 100.001] /Border [0 0 0] /QuadPoints [0 100 10 100 10 95 0 95] /A <</Type /Action /S /URI /URI (x)>> /F 4 /Contents (x)>>
    ),
  )
}

///|
test "named destinations" {
  let p = parse(
    pages_doc(2, (doc, page) => {
      if page.index() == 1 {
        let nd = @export.NamedDestination::new(
          "intro",
          @export.XyzDestination::new(1, @export.Point::from_xy(0.0, 10.0)),
        )
        inspect(doc.register_named_destination(nd) is Some(_), content="true")
        // Registering the same destination again is fine.
        inspect(doc.register_named_destination(nd) is Some(_), content="true")
        // A different destination with the same name is not.
        inspect(
          doc.register_named_destination({
            ..nd,
            xyz_dest: { ..nd.xyz_dest, page_index: 0, },
          })
          is None,
          content="true",
        )
        let other = @export.NamedDestination::new(
          "appendix",
          @export.XyzDestination::new(0, @export.Point::from_xy(0.0, 0.0)),
        )
        page.add_annotation(
          @export.Annotation::new_link(
            @export.LinkAnnotation::new(link_rect(), Destination(Named(other))),
            None,
          ),
        )
      }
    }),
  )
  // Named destinations are sorted by name.
  let names = p.items(p.path(p.catalog(), ["Names", "Dests", "Names"]))
  inspect(
    names.map(n => p.show(n)).join(" "),
    content=(
      #|(appendix) [R /XYZ 0 100 null] (intro) [R /XYZ 0 90 null]
    ),
  )
  let annot = p.items(p.get(p.page(1), "Annots"))[0]
  inspect(
    p.show(p.get(annot, "Dest")),
    content=(
      #|(appendix)
    ),
  )
  // pdflite resolves the name tree.
  let dests = p.path(p.catalog(), ["Names", "Dests"])
  let intro = p.doc.name_tree_lookup(b"intro", dests)
  inspect(
    p.show(p.resolve(intro.unwrap())),
    content=(
      #|[R /XYZ 0 90 null]
    ),
  )
}

///|
test "a link to a named destination that conflicts raises" {
  inspect(
    export_result(() => {
      pages_doc(1, (doc, page) => {
        doc.register_named_destination(
          @export.NamedDestination::new(
            "a",
            @export.XyzDestination::new(0, @export.Point::from_xy(0.0, 0.0)),
          ),
        )
        |> ignore
        page.add_annotation(
          @export.Annotation::new_link(
            @export.LinkAnnotation::new(
              link_rect(),
              Destination(
                Named(
                  @export.NamedDestination::new(
                    "a",
                    @export.XyzDestination::new(
                      0,
                      @export.Point::from_xy(1.0, 0.0),
                    ),
                  ),
                ),
              ),
            ),
            None,
          ),
        )
      })
    }),
    content=(
      #|DuplicateNamedDestination: a
    ),
  )
}

///|
test "outlines" {
  let outline = @export.Outline::new()
  let chapter = @export.OutlineNode::new(
    "Chapter 1",
    @export.XyzDestination::new(0, @export.Point::from_xy(0.0, 0.0)),
  )
  let section = @export.OutlineNode::new(
    "Section 1.1",
    @export.XyzDestination::new(0, @export.Point::from_xy(0.0, 50.0)),
  )
  section.push_child(
    @export.OutlineNode::new(
      "Détails",
      @export.XyzDestination::new(1, @export.Point::from_xy(0.0, 0.0)),
    ),
  )
  chapter.push_child(section)
  outline.push_child(chapter)
  outline.push_child(
    @export.OutlineNode::new(
      "Chapter 2",
      @export.XyzDestination::new(1, @export.Point::from_xy(0.0, 0.0)),
    ),
  )
  let p = parse(
    pages_doc(2, (_, _) => (), before_finish=doc => doc.set_outline(outline)),
  )
  let root = p.get(p.catalog(), "Outlines")
  inspect(
    p.show(p.resolve(root)),
    content=(
      #|<</Type /Outlines /First R /Last R /Count 2>>
    ),
  )
  let first = p.get(root, "First")
  inspect(
    p.show(p.resolve(first)),
    content=(
      #|<</Parent R /Next R /First R /Last R /Count -2 /Title (Chapter 1) /Dest R>>
    ),
  )
  let sect = p.get(first, "First")
  inspect(
    p.show(p.resolve(sect)),
    content=(
      #|<</Parent R /First R /Last R /Count -1 /Title (Section 1.1) /Dest R>>
    ),
  )
  inspect(
    p.show(p.path(sect, ["First", "Title"])),
    content=(
      #|<FEFF004400E9007400610069006C0073>
    ),
  )
  inspect(
    p.show(p.path(first, ["Next", "Title"])),
    content=(
      #|(Chapter 2)
    ),
  )
  inspect(
    p.show_deep(p.get(first, "Dest")),
    content=(
      #|[<</Type /Page /Resources <<>> /MediaBox [0 0 200 100] /Parent R /Contents R>> /XYZ 0 100 null]
    ),
  )
  // pdflite reads the outline back as bookmarks.
  let marks = @pdflite.pdf_read_bookmarks(p.doc)
  debug_inspect(
    marks.map(m => (m.level, latin1(m.text))),
    content=(
      #|[
      #|  (0, "Chapter 1"),
      #|  (1, "Section 1.1"),
      #|  (2, "þÿ\u{00}D\u{00}é\u{00}t\u{00}a\u{00}i\u{00}l\u{00}s"),
      #|  (0, "Chapter 2"),
      #|]
    ),
  )
}

///|
test "empty outlines are omitted" {
  let p = parse(
    pages_doc(1, (_, _) => (), before_finish=doc => {
      doc.set_outline(@export.Outline::new())
    }),
  )
  inspect(p.has(p.catalog(), "Outlines"), content="false")
  // ... unless a validator requires an outline.
  let p = parse(
    pages_doc(1, (_, _) => (), settings=settings_with(ua=Some(UA1)), before_finish=doc => {
      doc.set_outline(@export.Outline::new())
      doc.set_metadata(@export.Metadata::new().title("T").language("en"))
      doc.set_tag_tree(@export.TagTree::new())
    }),
  )
  inspect(
    p.show(p.path(p.catalog(), ["Outlines"])),
    content=(
      #|<</Type /Outlines>>
    ),
  )
}

///|
test "annotation alt text is required by PDF/UA" {
  inspect(
    export_result(() => {
      pages_doc(
        1,
        (_, page) => {
          page.add_tagged_annotation(
            @export.Annotation::new_link(
              @export.LinkAnnotation::new(link_rect(), Action(Link("x"))),
              Some(""),
              location=Some(3UL),
            ),
          )
          |> ignore
        },
        settings=settings_with(ua=Some(UA1)),
      )
    }),
    content=(
      #|Validation: MissingDocumentOutline by PDF/UA-1; MissingAnnotationAltText by PDF/UA-1; MissingTagging by PDF/UA-1; NoDocumentTitle by PDF/UA-1
    ),
  )
}
