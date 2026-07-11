// The `capabilities` command: print the machine-readable `xlsx.batch/1` op
// catalog this build supports, so an agent can check its needed ops are
// present before generating a script (forward-compat discovery).

///|
async fn run_capabilities(_m : @argparse.Matches) -> Unit {
  println(@batch.capabilities().stringify(indent=2))
}
