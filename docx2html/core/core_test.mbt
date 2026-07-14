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
