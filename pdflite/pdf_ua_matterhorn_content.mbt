///|
fn pdf_ua_matterhorn_is_form_stream(
  document : PdfDocument,
  object : PdfObject,
) -> Bool {
  match document.lookup_direct(pdf_ua_subtype_key(), object) {
    Some(PdfNameObject(subtype)) => subtype == pdf_ua_matterhorn_form()
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_stream_resources(
  self : PdfDocument,
  stream : PdfObject,
) -> PdfObject {
  match self.lookup_direct(pdf_ua_matterhorn_resources_key(), stream) {
    Some(resources) => resources
    None => PdfDictionary([])
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_all_ops(
  self : PdfDocument,
  xobjects? : Bool = true,
) -> Array[Array[PdfContentOp]] raise PdfError {
  let output : Array[Array[PdfContentOp]] = []
  if xobjects {
    for entry in self.stream_object_entries() {
      let stream = PdfStreamObject(entry.2)
      if pdf_ua_matterhorn_is_form_stream(self, stream) {
        let resources = self.pdf_ua_matterhorn_stream_resources(stream)
        output.push(self.parse_content_ops_with_resources(resources, [stream]))
      }
    }
  }
  for page in self.pages_of_pagetree() {
    output.push(
      self.parse_content_ops_with_resources(page.resources, page.content),
    )
  }
  output
}

///|
fn pdf_ua_matterhorn_artifact_in_content_ops(
  ops : ArrayView[PdfContentOp],
) -> Bool {
  let mut in_content = false
  let mut in_artifact = false
  for op in ops {
    match op {
      Op_BDC(_, _) => in_content = true
      Op_BMC(name) if name == pdf_ua_matterhorn_artifact() =>
        if in_content {
          return true
        } else {
          in_artifact = true
        }
      Op_EMC =>
        if in_content && in_artifact {
          return true
        } else if in_content {
          in_content = false
        } else {
          in_artifact = false
        }
      _ => ()
    }
  }
  false
}

///|
fn pdf_ua_matterhorn_content_in_artifact_ops(
  ops : ArrayView[PdfContentOp],
) -> Bool {
  let mut in_content = false
  let mut in_artifact = false
  for op in ops {
    match op {
      Op_BDC(_, _) => if in_artifact { return true } else { in_content = true }
      Op_BMC(name) if name == pdf_ua_matterhorn_artifact() => in_artifact = true
      Op_EMC =>
        if in_content && in_artifact {
          return true
        } else if in_content {
          in_content = false
        } else {
          in_artifact = false
        }
      _ => ()
    }
  }
  false
}

///|
fn pdf_ua_matterhorn_real_op(op : PdfContentOp) -> Bool {
  match op {
    Op_m(_, _)
    | Op_l(_, _)
    | Op_c(_, _, _, _, _, _)
    | Op_v(_, _, _, _)
    | Op_y(_, _, _, _)
    | Op_h
    | Op_re(_, _, _, _)
    | Op_S
    | Op_s
    | Op_f
    | Op_F
    | Op_fstar
    | Op_B
    | Op_Bstar
    | Op_b
    | Op_bstar
    | Op_W
    | Op_Wstar
    | Op_Tj(_)
    | Op_TJ(_)
    | Op_quote(_)
    | Op_double_quote(_, _, _)
    | Op_sh(_)
    | Op_InlineImage(_, _, _)
    | Op_Do(_) => true
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_path_construction_op(op : PdfContentOp) -> Bool {
  match op {
    Op_m(_, _)
    | Op_l(_, _)
    | Op_c(_, _, _, _, _, _)
    | Op_v(_, _, _, _)
    | Op_y(_, _, _, _)
    | Op_h
    | Op_re(_, _, _, _) => true
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_bdc_context(
  tag : PdfName,
  properties : PdfObject,
) -> PdfUAMatterhornContext {
  match properties {
    PdfDictionary(_) if properties.lookup_immediate(
        pdf_ua_matterhorn_mcid_key(),
      )
      is Some(_) => PdfUAMatterhornContent
    _ =>
      if tag == pdf_ua_matterhorn_artifact() {
        PdfUAMatterhornArtifact
      } else {
        PdfUAMatterhornOther
      }
  }
}

///|
fn pdf_ua_matterhorn_bmc_context(tag : PdfName) -> PdfUAMatterhornContext {
  if tag == pdf_ua_matterhorn_span() || tag == pdf_ua_matterhorn_artifact() {
    PdfUAMatterhornArtifact
  } else {
    PdfUAMatterhornOther
  }
}

///|
fn pdf_ua_matterhorn_stack_has_marking(
  stack : ArrayView[PdfUAMatterhornContext],
) -> Bool {
  for context in stack {
    match context {
      PdfUAMatterhornArtifact | PdfUAMatterhornContent => return true
      PdfUAMatterhornOther => ()
    }
  }
  false
}

///|
fn pdf_ua_matterhorn_naked_ops(
  ops : ArrayView[PdfContentOp],
) -> (Array[PdfContentOp], Json?) {
  let naked : Array[PdfContentOp] = []
  let stack : Array[PdfUAMatterhornContext] = []
  for op in ops {
    match op {
      Op_BDC(tag, properties) =>
        stack.push(pdf_ua_matterhorn_bdc_context(tag, properties))
      Op_BMC(tag) => stack.push(pdf_ua_matterhorn_bmc_context(tag))
      Op_EMC =>
        if stack.length() == 0 {
          return ([], Some(Json::string("empty stack")))
        } else {
          ignore(stack.pop())
        }
      _ =>
        if !pdf_ua_matterhorn_stack_has_marking(stack) &&
          pdf_ua_matterhorn_real_op(op) {
          naked.push(op)
        }
    }
  }
  (naked, None)
}

///|
fn pdf_ua_matterhorn_unfiltered_real_op(
  naked : ArrayView[PdfContentOp],
) -> Bool {
  let reversed = naked.rev()
  let mut index = 0
  while index < reversed.length() {
    match reversed[index] {
      Op_W | Op_Wstar => {
        index += 1
        while index < reversed.length() &&
              pdf_ua_matterhorn_path_construction_op(reversed[index]) {
          index += 1
        }
      }
      op => {
        if pdf_ua_matterhorn_real_op(op) {
          return true
        }
        index += 1
      }
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_01_003(
  self : PdfDocument,
) -> Json? raise PdfError {
  for ops in self.pdf_ua_matterhorn_all_ops() {
    if pdf_ua_matterhorn_artifact_in_content_ops(ops) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_01_004(
  self : PdfDocument,
) -> Json? raise PdfError {
  for ops in self.pdf_ua_matterhorn_all_ops() {
    if pdf_ua_matterhorn_content_in_artifact_ops(ops) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_01_005(
  self : PdfDocument,
) -> Json? raise PdfError {
  for ops in self.pdf_ua_matterhorn_all_ops(xobjects=false) {
    let (naked, error) = pdf_ua_matterhorn_naked_ops(ops)
    match error {
      Some(extra) => return Some(extra)
      None =>
        if pdf_ua_matterhorn_unfiltered_real_op(naked) {
          return Some(Json::null())
        }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_01_007(self : PdfDocument) -> Json? {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_ua_markinfo_key(),
      pdf_ua_matterhorn_suspects_key(),
    ]) {
    Some(PdfBoolean(true)) => Some(Json::null())
    _ => None
  }
}
