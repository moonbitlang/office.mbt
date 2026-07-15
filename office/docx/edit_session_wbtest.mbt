///|
test "typed resource failures outrank document-controlled diagnostic text" {
  let resource_error = @docxcore.contextual_docx_xml_resource_limit_error(
    DocxXmlTokens,
    "splicing 'word/overlap.xml' exceeded XML resource limits: XML token budget exceeded",
  )
  match mapped_plan_failure(resource_error) {
    TransactionError(code~, ..) => assert_eq(code, "office.docx.resource_limit")
  }
}
