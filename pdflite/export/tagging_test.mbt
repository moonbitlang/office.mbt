///|
fn tagged_settings(
  version? : @export.PdfVersion = Pdf17,
  ua? : @export.Accessibility? = None,
) -> @export.SerializeSettings {
  { ..settings_with(version~, ua~), enable_tagging: true, }
}

///|
fn group(tag : @export.TagKind, children : Array[@export.Node]) -> @export.Node {
  Group(@export.TagGroup::with_children(tag, children))
}

///|
fn kind(
  name : @export.TagName,
  attrs? : Array[@export.Attr] = [],
) -> @export.TagKind {
  let k = @export.TagKind::new(name)
  for a in attrs {
    k.set(a)
  }
  k
}

///|
/// Draw a small tagged rectangle and return its identifier.
fn tagged_rect(
  s : @export.Surface,
  tag : @export.ContentTag,
) -> @export.Identifier {
  let id = s.start_tagged(tag)
  s.draw_path(rect_path(0.0, 0.0, 5.0, 5.0))
  s.end_tagged()
  id
}

///|
/// A summary of the structure tree: one line per structure element with its
/// type, the other keys and its kids (marked content IDs as numbers).
fn Parsed::struct_tree(self : Parsed) -> String raise {
  let sb = StringBuilder()
  let root = self.get(self.catalog(), "StructTreeRoot")
  let doc = self.items(self.get(root, "K"))[0]
  self.struct_elem(sb, doc, 0)
  sb.to_string()
}

///|
fn Parsed::struct_elem(
  self : Parsed,
  sb : StringBuilder,
  elem : @syntax.PdfObject,
  depth : Int,
) -> Unit raise {
  for _ in 0..<depth {
    sb.write_string("  ")
  }
  sb.write_string(self.show(self.get(elem, "S")))
  let keys = self.keys(elem)
  for k in keys {
    if k is ("Type" | "S" | "P" | "K" | "Pg") {
      continue
    }
    sb.write_string(" /\{k} \{self.show(self.get(elem, k))}")
  }
  let kids = self.get(elem, "K")
  let groups = []
  let leaves = []
  match kids {
    PdfArray(items) =>
      for kid in items {
        match self.resolve(kid) {
          PdfDictionary(_) as d =>
            if self.has(d, "S") {
              groups.push(d)
            } else {
              leaves.push(self.show(d))
            }
          other => leaves.push(self.show(other))
        }
      }
    _ => ()
  }
  if !leaves.is_empty() {
    sb.write_string(" K=[\{leaves.join(" ")}]")
  }
  sb.write_char('\n')
  for g in groups {
    self.struct_elem(sb, g, depth + 1)
  }
}

///|
test "tagged content gets marked content IDs" {
  let doc = @export.Document::new_with(tagged_settings())
  inspect(doc.tagging_enabled(), content="true")
  let page = doc.start_page_with(
    @export.PageSettings::from_wh(100.0, 100.0).unwrap(),
  )
  let s = page.surface()
  let p_id = tagged_rect(s, Other)
  let span_id = tagged_rect(
    s,
    Span({
      ..@export.SpanTag::empty(),
      lang: Some("de"),
      actual_text: Some("x"),
    }),
  )
  let artifact = tagged_rect(s, Artifact({ kind: Header, bbox: None, }))
  let plain_artifact = tagged_rect(s, Artifact({ kind: Other, bbox: None, }))
  s.finish()
  page.finish()
  debug_inspect(
    [p_id, span_id, artifact, plain_artifact],
    content=(
      #|[PageContent(0, 0), PageContent(0, 1), Dummy, Dummy]
    ),
  )
  let tree = @export.TagTree::new()
  tree.lang = Some("en")
  tree.push(
    group(kind(Section), [
      group(kind(P), [Leaf(p_id)]),
      group(kind(Span), [Leaf(span_id), Leaf(Dummy)]),
    ]),
  )
  doc.set_tag_tree(tree)
  let p = parse(doc.finish())
  inspect(
    p.content(p.page(0)),
    content=(
      #|/P <</MCID 0
      #|>> BDC
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|0 0 m
      #|5 0 l
      #|5 5 l
      #|0 5 l
      #|h
      #|f
      #|Q
      #|EMC
      #|/Span <</MCID 1
      #|/Lang (de)
      #|/ActualText (x)
      #|>> BDC
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|0 0 m
      #|5 0 l
      #|5 5 l
      #|0 5 l
      #|h
      #|f
      #|Q
      #|EMC
      #|/Artifact <</Attached [/Top]
      #|/Subtype /Header
      #|/Type /Pagination
      #|>> BDC
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|0 0 m
      #|5 0 l
      #|5 5 l
      #|0 5 l
      #|h
      #|f
      #|Q
      #|EMC
      #|/Artifact BMC
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|0 0 m
      #|5 0 l
      #|5 5 l
      #|0 5 l
      #|h
      #|f
      #|Q
      #|EMC
      #|
    ),
  )
  inspect(p.show(p.get(p.page(0), "StructParents")), content="0")
  inspect(
    p.show(p.get(p.catalog(), "MarkInfo")),
    content=(
      #|<</Marked true /Suspects false>>
    ),
  )
  let root = p.get(p.catalog(), "StructTreeRoot")
  inspect(
    p.show(p.resolve(root)),
    content=(
      #|<</Type /StructTreeRoot /RoleMap <</Datetime /Span /Terms /Part /Title /P /Strong /Span /Em /Span>> /K [R] /ParentTree <</Nums [0 R]>> /ParentTreeNextKey 1>>
    ),
  )
  inspect(
    p.show_deep(p.path(root, ["ParentTree", "Nums"])),
    content=(
      #|[0 [R R]]
    ),
  )
  inspect(
    p.struct_tree(),
    content=(
      #|/Document /Lang (en)
      #|  /Sect
      #|    /P K=[0]
      #|    /Span K=[1]
      #|
    ),
  )
}

///|
test "structure elements carry their attributes" {
  let doc = @export.Document::new_with(tagged_settings())
  let page = doc.start_page_with(
    @export.PageSettings::from_wh(100.0, 100.0).unwrap(),
  )
  let s = page.surface()
  let ids = [0, 1, 2, 3, 4, 5].map(_ => tagged_rect(s, Other))
  s.finish()
  page.finish()
  let tree = @export.TagTree::new()
  tree.push(
    group(kind(Hn, attrs=[HeadingLevel(2), Title("Intro"), Lang("en")]), [
      Leaf(ids[0]),
    ]),
  )
  tree.push(
    group(kind(Hn, attrs=[HeadingLevel(7), Title("Deep")]), [Leaf(ids[1])]),
  )
  tree.push(
    group(
      kind(Figure, attrs=[
        AltText("A chart"),
        BBox(0, @export.Rect::from_xywh(10.0, 10.0, 20.0, 30.0).unwrap()),
        Placement(Block),
        Width(20.0),
        Height(30.0),
      ]),
      [Leaf(ids[2])],
    ),
  )
  tree.push(
    group(kind(L, attrs=[ListNumbering(Decimal)]), [
      group(kind(LI), [
        group(kind(Lbl), [Leaf(ids[3])]),
        group(kind(LBody, attrs=[ActualText("one"), Expanded("uno")]), []),
      ]),
    ]),
  )
  tree.push(
    group(kind(Table, attrs=[Summary("Data")]), [
      group(kind(TR), [
        group(kind(TH, attrs=[Id(b"h1"), HeaderScope(Column), RowSpan(2)]), [
          Leaf(ids[4]),
        ]),
        group(
          kind(TD, attrs=[
            CellHeaders([b"h1"]),
            ColSpan(3),
            BackgroundColor({ red: 255, green: 0, blue: 0, }),
            BorderStyle(@export.Sides::uniform(Dashed)),
            BorderThickness({ before: 1.0, after: 2.0, start: 1.0, end: 1.0, }),
            TextDecorationType(Underline),
            LineHeight(CustomHeight(1.5)),
          ]),
          [Leaf(ids[5])],
        ),
      ]),
    ]),
  )
  tree.push(group(kind(Note), []))
  tree.push(group(kind(Note), []))
  tree.push(group(kind(Strong), []))
  doc.set_tag_tree(tree)
  let p = parse(doc.finish())
  inspect(
    p.struct_tree(),
    content=(
      #|/Document
      #|  /H2 /Lang (en) /T (Intro) K=[0]
      #|  /H7 /T (Deep) K=[1]
      #|  /Figure /Alt (A chart) /A [<</O /Layout /Placement /Block /BBox [10 60 30 90] /Width 20 /Height 30>>] K=[2]
      #|  /L /A [<</O /List /ListNumbering /Decimal>>]
      #|    /LI
      #|      /Lbl K=[3]
      #|      /LBody /E (uno) /ActualText (one)
      #|  /Table /A [<</O /Table /Summary (Data)>>]
      #|    /TR
      #|      /TH /ID (h1) /A [<</O /Table /Scope /Column /RowSpan 2>>] K=[4]
      #|      /TD /A [<</O /Table /Headers [(h1)] /ColSpan 3>> <</O /Layout /BackgroundColor [1 0 0] /BorderStyle /Dashed /BorderThickness [1 2 1 1] /LineHeight 1.5 /TextDecorationType /Underline>>] K=[5]
      #|  /Note /ID (Note 1)
      #|  /Note /ID (Note 2)
      #|  /Strong
      #|
    ),
  )
  let root = p.get(p.catalog(), "StructTreeRoot")
  inspect(
    p.show(p.get(root, "RoleMap")),
    content=(
      #|<</Datetime /Span /Terms /Part /Title /P /Strong /Span /Em /Span /H7 /P>>
    ),
  )
  inspect(
    p.show(p.path(root, ["IDTree", "Names"])),
    content=(
      #|[(Note 1) R (Note 2) R (h1) R]
    ),
  )
}

///|
test "structure elements spanning pages reference other pages' content" {
  let doc = @export.Document::new_with(tagged_settings())
  let ids = []
  for _ in 0..<2 {
    let page = doc.start_page_with(
      @export.PageSettings::from_wh(100.0, 100.0).unwrap(),
    )
    let s = page.surface()
    ids.push(tagged_rect(s, Other))
    s.finish()
    page.finish()
  }
  let tree = @export.TagTree::new()
  tree.push(group(kind(P), ids.map(id => Leaf(id))))
  doc.set_tag_tree(tree)
  let p = parse(doc.finish())
  inspect(
    p.struct_tree(),
    content=(
      #|/Document
      #|  /P K=[0 <</Type /MCR /Pg R /MCID 0>>]
      #|
    ),
  )
  let root = p.get(p.catalog(), "StructTreeRoot")
  inspect(
    p.show(p.path(root, ["ParentTree", "Nums"])),
    content=(
      #|[0 R 1 R]
    ),
  )
  inspect(
    p.pages().map(page => p.show(p.get(page, "StructParents"))).join(" "),
    content=(
      #|0 1
    ),
  )
}

///|
test "tagged annotations are object references in the structure tree" {
  let doc = @export.Document::new_with(tagged_settings())
  let page = doc.start_page_with(
    @export.PageSettings::from_wh(100.0, 100.0).unwrap(),
  )
  page.surface().finish()
  let id = page.add_tagged_annotation(
    @export.Annotation::new_link(
      @export.LinkAnnotation::new(
        @export.Rect::from_xywh(0.0, 0.0, 10.0, 10.0).unwrap(),
        Action(Link("https://example.com")),
      ),
      Some("Example"),
    ),
  )
  debug_inspect(
    id,
    content=(
      #|Annotation(0, 0)
    ),
  )
  page.finish()
  let tree = @export.TagTree::new()
  tree.push(group(kind(Link), [Leaf(id)]))
  doc.set_tag_tree(tree)
  let p = parse(doc.finish())
  let annot = p.items(p.get(p.page(0), "Annots"))[0]
  inspect(
    p.show(annot),
    content=(
      #|<</Type /Annot /Subtype /Link /Rect [0 90 10 100] /Border [0 0 0] /A <</Type /Action /S /URI /URI (https://example.com)>> /F 4 /StructParent 0 /Contents (Example)>>
    ),
  )
  inspect(p.show(p.get(p.page(0), "Tabs")), content="/S")
  inspect(p.has(p.page(0), "StructParents"), content="false")
  inspect(
    p.struct_tree(),
    content=(
      #|/Document
      #|  /Link K=[<</Type /OBJR /Pg R /Obj R>>]
      #|
    ),
  )
  let root = p.get(p.catalog(), "StructTreeRoot")
  inspect(
    p.show(p.path(root, ["ParentTree", "Nums"])),
    content=(
      #|[0 R]
    ),
  )
}

///|
test "without tagging nothing is marked" {
  let doc = @export.Document::new_with(plain_settings())
  inspect(doc.tagging_enabled(), content="false")
  let page = doc.start_page_with(
    @export.PageSettings::from_wh(100.0, 100.0).unwrap(),
  )
  let s = page.surface()
  debug_inspect(tagged_rect(s, Other), content="Dummy")
  s.finish()
  let annot_id = page.add_tagged_annotation(
    @export.Annotation::new_link(
      @export.LinkAnnotation::new(
        @export.Rect::from_xywh(0.0, 0.0, 10.0, 10.0).unwrap(),
        Action(Link("x")),
      ),
      None,
    ),
  )
  debug_inspect(annot_id, content="Dummy")
  page.finish()
  doc.set_tag_tree(@export.TagTree::new())
  let p = parse(doc.finish())
  inspect(p.has(p.catalog(), "StructTreeRoot"), content="false")
  inspect(p.has(p.catalog(), "MarkInfo"), content="false")
  inspect(contains(p.content(p.page(0)), "BDC"), content="false")
}

///|
test "artifacts in older PDF versions" {
  let doc = @export.Document::new_with(tagged_settings(version=Pdf14))
  let page = doc.start_page_with(
    @export.PageSettings::from_wh(100.0, 100.0).unwrap(),
  )
  let s = page.surface()
  tagged_rect(
    s,
    Artifact({
      kind: Header,
      bbox: Some(@export.Rect::from_xywh(0.0, 0.0, 100.0, 10.0).unwrap()),
    }),
  )
  |> ignore
  tagged_rect(s, Artifact({ kind: Background, bbox: None, })) |> ignore
  s.finish()
  page.finish()
  doc.set_tag_tree(@export.TagTree::new())
  let p = parse(doc.finish())
  inspect(
    p.content(p.page(0)),
    content=(
      #|/Artifact <</BBox [0 90 100 100]
      #|/Type /Pagination
      #|>> BDC
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|0 0 m
      #|5 0 l
      #|5 5 l
      #|0 5 l
      #|h
      #|f
      #|Q
      #|EMC
      #|/Artifact BMC
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|0 0 m
      #|5 0 l
      #|5 5 l
      #|0 5 l
      #|h
      #|f
      #|Q
      #|EMC
      #|
    ),
  )
  // PDF 1.4 has no `/Suspects`.
  inspect(p.show(p.get(p.catalog(), "MarkInfo")), content="<</Marked true>>")
}

///|
test "tag tree errors" {
  let build = (tree : @export.TagTree) => {
    export_result(() => {
      let doc = @export.Document::new_with(tagged_settings())
      let page = doc.start_page_with(
        @export.PageSettings::from_wh(100.0, 100.0).unwrap(),
      )
      page.surface().finish()
      page.finish()
      doc.set_tag_tree(tree)
      doc.finish()
    })
  }
  let dup = @export.TagTree::new()
  dup.push(group(kind(P, attrs=[Id(b"x")]), []))
  dup.push(group(kind(P, attrs=[Id(b"x")]), []))
  inspect(
    build(dup),
    content=(
      #|DuplicateTagId: x
    ),
  )
  let unknown = @export.TagTree::new()
  unknown.push(group(kind(TD, attrs=[CellHeaders([b"missing"])]), []))
  inspect(
    build(unknown),
    content=(
      #|UnknownTagId: missing
    ),
  )
}

///|
test "PDF/UA requirements" {
  let build = (
    title : String?,
    tree : @export.TagTree,
    version : @export.PdfVersion,
  ) => {
    export_result(() => {
      let doc = @export.Document::new_with(
        tagged_settings(ua=Some(UA1), version~),
      )
      let page = doc.start_page_with(
        @export.PageSettings::from_wh(100.0, 100.0).unwrap(),
      )
      let s = page.surface()
      let id = tagged_rect(s, Other)
      tagged_rect(s, Artifact({ kind: Footer, bbox: None, })) |> ignore
      s.finish()
      page.finish()
      let mut m = @export.Metadata::new().language("en")
      if title is Some(t) {
        m = m.title(t)
      }
      doc.set_metadata(m)
      doc.set_outline(@export.Outline::new())
      tree.push(group(kind(P), [Leaf(id)]))
      doc.set_tag_tree(tree)
      doc.finish()
    })
  }
  inspect(build(Some("Doc"), @export.TagTree::new(), Pdf17), content="ok")
  let tree = @export.TagTree::new()
  tree.push(group(kind(Figure), []))
  tree.push(group(kind(Formula, attrs=[AltText("")]), []))
  tree.push(group(kind(Hn), []))
  inspect(
    build(None, tree, Pdf17),
    content=(
      #|Validation: MissingAltText by PDF/UA-1; MissingHeadingTitle by PDF/UA-1; NoDocumentTitle by PDF/UA-1
    ),
  )
  inspect(
    build(Some("Doc"), @export.TagTree::new(), Pdf14),
    content=(
      #|Validation: RequiresNewerPdfVersion(HeaderFooterArtifactSubtypes) by PDF/UA-1
    ),
  )
}

///|
test "a PDF/UA document" {
  let doc = @export.Document::new_with(tagged_settings(ua=Some(UA1)))
  let page = doc.start_page_with(
    @export.PageSettings::from_wh(100.0, 100.0).unwrap(),
  )
  let s = page.surface()
  let id = tagged_rect(s, Other)
  s.finish()
  page.finish()
  doc.set_metadata(@export.Metadata::new().title("Accessible").language("en"))
  doc.set_outline(@export.Outline::new())
  let tree = @export.TagTree::new()
  tree.push(group(kind(P), [Leaf(id)]))
  doc.set_tag_tree(tree)
  let p = parse(doc.finish())
  inspect(
    p.keys(p.catalog()).join(" "),
    content=(
      #|Type Pages Metadata Lang StructTreeRoot MarkInfo ViewerPreferences Outlines
    ),
  )
  inspect(
    p.show(p.get(p.catalog(), "ViewerPreferences")),
    content=(
      #|<</DisplayDocTitle true>>
    ),
  )
  inspect(p.show(p.get(p.page(0), "Tabs")), content="/S")
  let xmp = latin1(p.stream_data(p.get(p.catalog(), "Metadata")))
  inspect(contains(xmp, "<pdfuaid:part>1</pdfuaid:part>"), content="true")
}

///|
test "TagKind attributes are kept sorted and unique" {
  let k = @export.TagKind::new(Hn)
  inspect(k.heading_level(), content="1")
  k.set(Title("T"))
  k.set(Lang("en"))
  k.set(HeadingLevel(3))
  k.set(Lang("fr"))
  let k = k.with_attr(Id(b"h"))
  inspect(k.heading_level(), content="3")
  debug_inspect(
    (k.get_lang(), k.get_id(), k.alt_text()),
    content=(
      #|(Some("fr"), Some(<Bytes: [0x68]>), None)
    ),
  )
  k.remove_like(Lang(""))
  debug_inspect(k.get_lang(), content="None")
  // Id < Lang < AltText < ... < Title < HeadingLevel.
  inspect(
    k.attrs
    .map(a => {
      match a {
        Id(_) => "Id"
        Title(_) => "Title"
        HeadingLevel(_) => "HeadingLevel"
        _ => "other"
      }
    })
    .join(" "),
    content=(
      #|Id Title HeadingLevel
    ),
  )
}

///|
test "panic marked content missing from the tag tree" {
  let doc = @export.Document::new_with(tagged_settings())
  let page = doc.start_page_with(
    @export.PageSettings::from_wh(100.0, 100.0).unwrap(),
  )
  let s = page.surface()
  tagged_rect(s, Other) |> ignore
  s.finish()
  page.finish()
  doc.set_tag_tree(@export.TagTree::new())
  doc.finish() |> ignore
}
