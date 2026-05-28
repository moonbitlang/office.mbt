///|
let pdf_metadata_xmp_template : String =
  #|<?xpacket begin='' id='W5M0MpCehiHzreSzNTczkc9d'?>
  #|<x:xmpmeta xmlns:x="adobe:ns:meta/">
  #|
  #|<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'
  #| xmlns:iX='http://ns.adobe.com/iX/1.0/'>
  #|
  #| <rdf:Description about=''
  #|  xmlns='http://ns.adobe.com/pdf/1.3/'
  #|  xmlns:pdf='http://ns.adobe.com/pdf/1.3/'>
  #|  <pdf:CreationDate>CREATEDATE</pdf:CreationDate>
  #|  <pdf:ModDate>MODDATE</pdf:ModDate>
  #|  <pdf:Producer>PRODUCER</pdf:Producer>
  #|  <pdf:Creator>CREATOR</pdf:Creator>
  #|  <pdf:Title>TITLE</pdf:Title>
  #|  <pdf:Subject>SUBJECT</pdf:Subject>
  #|  <pdf:Author>AUTHOR</pdf:Author>
  #|  <pdf:Keywords>KEYWORDS</pdf:Keywords>
  #|  <pdf:Trapped>TRAPPED</pdf:Trapped>
  #| </rdf:Description>
  #|
  #| <rdf:Description about=''
  #|  xmlns='http://ns.adobe.com/xap/1.0/'
  #|  xmlns:xap='http://ns.adobe.com/xap/1.0/'>
  #|   <xap:CreateDate>CREATEDATE</xap:CreateDate>
  #|   <xap:CreatorTool>CREATOR</xap:CreatorTool>
  #|   <xap:ModifyDate>MODDATE</xap:ModifyDate>
  #|   <xap:MetadataDate>METADATADATE</xap:MetadataDate>
  #| </rdf:Description>
  #|
  #| <rdf:Description about=''
  #|  xmlns='http://purl.org/dc/elements/1.1/'
  #|  xmlns:dc='http://purl.org/dc/elements/1.1/'>
  #|   <dc:title>
  #|   <rdf:Alt>
  #|     <rdf:li xml:lang='x-default'>TITLE</rdf:li>
  #|   </rdf:Alt>
  #|   </dc:title>
  #| </rdf:Description>
  #|
  #|</rdf:RDF>
  #|
  #|</x:xmpmeta>
  #|
  #|<?xpacket end='r'?>

///|
fn pdf_metadata_replace_all(
  text : String,
  old : String,
  new : String,
) -> String {
  let mut output = text
  if old == "" {
    output
  } else {
    while output.contains(old) {
      output = output.replace(old~, new~)
    }
    output
  }
}

///|
fn PdfDocument::pdf_metadata_template_replacements(
  self : PdfDocument,
) -> Array[(String, String)] raise PdfError {
  let info = fn(name : String) -> String {
    self.info_utf8(pdf_metadata_name(name))
  }
  let creation_date = match info("/CreationDate") {
    "" => pdf_metadata_expand_date("now")
    value => value
  }
  let mod_date = match info("/ModDate") {
    "" => pdf_metadata_expand_date("now")
    value => value
  }
  [
    ("CREATEDATE", pdf_metadata_xmp_date(creation_date)),
    ("MODDATE", pdf_metadata_xmp_date(mod_date)),
    ("PRODUCER", info("/Producer")),
    ("CREATOR", info("/Creator")),
    ("TITLE", info("/Title")),
    ("SUBJECT", info("/Subject")),
    ("AUTHOR", info("/Author")),
    ("KEYWORDS", info("/Keywords")),
    ("TRAPPED", info("/Trapped")),
    ("METADATADATE", pdf_metadata_xmp_date(pdf_metadata_expand_date("now"))),
  ]
}
