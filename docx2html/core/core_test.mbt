///|
test "message deduplication is order-preserving and kind-sensitive" {
  let messages = [
    @core.warning("same"),
    @core.warning("same"),
    @core.error("same"),
    @core.error("other"),
    @core.error("same"),
  ]
  debug_inspect(
    @core.dedupe_messages(messages),
    content=(
      #|[Warning("same"), Error("same"), Error("other")]
    ),
  )
}

///|
fn diagnostic_hash_clustered_texts(
  count : Int,
  bucket_mask : Int,
) -> Array[String] {
  let texts : Array[String] = []
  let mut candidate = 0
  while texts.length() < count {
    let text = "diagnostic-\{candidate}"
    if (text.hash() & bucket_mask) == 0 {
      texts.push(text)
    }
    candidate += 1
  }
  texts
}

///|
test "message deduplication ignores deterministic string-hash clustering" {
  let texts = diagnostic_hash_clustered_texts(256, 0x3FF)
  let messages : Array[@core.Message] = []
  for text in texts {
    assert_eq(text.hash() & 0x3FF, 0)
    messages.push(@core.warning(text))
    messages.push(@core.warning(text))
  }
  let deduped = @core.dedupe_messages(messages)
  assert_eq(deduped.length(), texts.length())
  for index, text in texts {
    assert_eq(deduped[index], @core.warning(text))
  }
}

///|
test "XML resource errors retain a machine discriminator through context" {
  let direct = @core.docx_xml_resource_limit_error(DocxXmlTokens)
  assert_eq(direct.description(), "XML token budget exceeded")
  debug_inspect(direct.xml_resource_limit(), content="Some(DocxXmlTokens)")
  let contextual = @core.contextual_docx_xml_resource_limit_error(
    DocxXmlTokens,
    "splicing document.xml exceeded XML resource limits",
  )
  assert_eq(
    contextual.description(),
    "splicing document.xml exceeded XML resource limits",
  )
  debug_inspect(contextual.xml_resource_limit(), content="Some(DocxXmlTokens)")
  let forged = @core.Unsupported(message="XML token budget exceeded")
  assert_true(forged.xml_resource_limit() is None)
}
