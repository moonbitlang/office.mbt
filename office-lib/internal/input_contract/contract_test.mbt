///|
fn canonical_test_core(id : String, value : Double) -> @input_contract.Core {
  {
    id,
    summary: "Canonical \{id}",
    consumed_by: ["office probe"],
    envelope: @input_contract.contract_envelope(
      [("schema", "literal(\{id})"), ("value", "finite-number")],
      ["schema", "value"],
    ),
    definitions: [
      @input_contract.contract_type("finite-number", "number", constraints=[
        "NaN and infinities are rejected",
      ]),
    ],
    operations: [],
    constraints: ["unknown members are rejected"],
    limits: Json::object({ "max": Json::number(value) }),
    examples: [
      Json::object({ "schema": Json::string(id), "value": Json::number(value) }),
    ],
  }
}

///|
test "canonical contract JSON and SHA-256 are backend invariant" {
  let first = canonical_test_core("probe/1", 42.0)
  let second = canonical_test_core("other/1", 7.0)
  inspect(
    @input_contract.core_json(first).stringify(),
    content=(
      #|{"id":"probe/1","summary":"Canonical probe/1","consumed_by":["office probe"],"envelope":{"name":"envelope","type":"object","members":{"schema":"literal(probe/1)","value":"finite-number"},"required":["schema","value"],"additional_members":false,"constraints":[]},"definitions":[{"name":"finite-number","type":"number","constraints":["NaN and infinities are rejected"]}],"operations":[],"constraints":["unknown members are rejected"],"limits":{"max":42},"examples":[{"schema":"probe/1","value":42}]}
    ),
  )
  inspect(
    @input_contract.fingerprint(first),
    content=(
      #|sha256:a5dbcc5b6519a57d328fe28fe11afc6a3b708fb8097570640b44032138363235
    ),
  )
  inspect(
    @input_contract.inventory([first, second]).stringify(),
    content=(
      #|{"schema":"office.input-contracts/1","fingerprint":"sha256:15e88c26bceab9f28f625aaef2448501f9ade064084aa81593d4973a9cfb14db","contracts":[{"id":"probe/1","fingerprint":"sha256:a5dbcc5b6519a57d328fe28fe11afc6a3b708fb8097570640b44032138363235","summary":"Canonical probe/1","consumed_by":["office probe"]},{"id":"other/1","fingerprint":"sha256:6a94f74b5bc47e621363fab13b9e644ed12f1953ef1f9a499d44d9001cb0aed6","summary":"Canonical other/1","consumed_by":["office probe"]}]}
    ),
  )
}
