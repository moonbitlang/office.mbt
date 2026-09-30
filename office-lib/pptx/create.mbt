///|
/// Creates a one-slide presentation through the shared atomic transaction.
/// Optional title text is limited to 4096 UTF-16 code units. This operation
/// creates a fresh package; it does not rewrite an existing presentation.
pub async fn create_presentation(
  options : @transaction.CreateTransactionOptions,
  title? : String = "",
) -> @transaction.TransactionReport {
  guard options.output_path.to_lower().has_suffix(".pptx") else {
    raise @transaction.transaction_failure(
      "office.invalid_arguments", "PPTX creation requires a .pptx destination",
    )
  }
  guard title.length() <= 4096 else {
    raise @transaction.transaction_failure(
      "office.pptx.resource_limit", "PPTX title exceeds 4096 UTF-16 code units",
    )
  }
  @transaction.transact_create(options, Pptx, budget => {
    let presentation = @presentation.Presentation::new()
    presentation.add_slide_mut(0) |> ignore
    if title != "" {
      let slide = presentation
        .slide_at(0)
        .with_shape(
          AutoShape(
            @slide.AutoShape::textbox(
              id=2,
              name="Title",
              x=@units.Inch(0.5).to_emu(),
              y=@units.Inch(0.5).to_emu(),
              cx=@units.Inch(8.0).to_emu(),
              cy=@units.Inch(1.0).to_emu(),
              title,
            ),
          ),
        )
      presentation.update_slide_mut(0, slide)
    }
    // Construction is fixed-size apart from the bounded title. The shared
    // transaction additionally checks the serialized candidate and ZIP limits.
    let bytes = Bytes::from_array(presentation.save())
    if bytes.length() > budget.max_candidate_package_bytes() {
      raise @transaction.transaction_failure(
        "office.pptx.resource_limit", "PPTX candidate exceeds the transaction budget",
      )
    }
    read_presentation(bytes) |> ignore
    @transaction.transaction_mutation(bytes)
  })
}
