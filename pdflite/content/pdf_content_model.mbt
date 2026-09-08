///|
/// Flat representation of PDF content stream operators.
///
/// Text strings and unknown operators are stored as raw PDF bytes. Inline images
/// carry their image dictionary, optional decode parameters, and image data; the
/// parser decodes supported inline-image filters when it can do so safely.
pub(all) enum PdfContentOp {
  Op_w(Double)
  Op_J(Int)
  Op_j(Int)
  Op_M(Double)
  Op_d(Array[Double], Double)
  Op_ri(PdfName)
  Op_i(Double)
  Op_q
  Op_Q
  Op_cm(TransformMatrix)
  Op_m(Double, Double)
  Op_l(Double, Double)
  Op_c(Double, Double, Double, Double, Double, Double)
  Op_v(Double, Double, Double, Double)
  Op_y(Double, Double, Double, Double)
  Op_h
  Op_re(Double, Double, Double, Double)
  Op_S
  Op_s
  Op_f
  Op_F
  Op_fstar
  Op_B
  Op_Bstar
  Op_b
  Op_bstar
  Op_n
  Op_W
  Op_Wstar
  Op_BT
  Op_ET
  Op_Tc(Double)
  Op_Tw(Double)
  Op_Tz(Double)
  Op_TL(Double)
  Op_Tf(PdfName, Double)
  Op_Tr(Int)
  Op_Ts(Double)
  Op_Td(Double, Double)
  Op_TD(Double, Double)
  Op_Tm(TransformMatrix)
  Op_Tstar
  Op_Tj(PdfBytes)
  Op_TJ(PdfObject)
  Op_quote(PdfBytes)
  Op_double_quote(Double, Double, PdfBytes)
  Op_d0(Double, Double)
  Op_d1(Double, Double, Double, Double, Double, Double)
  Op_G(Double)
  Op_g(Double)
  Op_RG(Double, Double, Double)
  Op_rg(Double, Double, Double)
  Op_K(Double, Double, Double, Double)
  Op_k(Double, Double, Double, Double)
  Op_gs(PdfName)
  Op_CS(PdfName)
  Op_cs(PdfName)
  Op_SC(Array[Double])
  Op_sc(Array[Double])
  Op_SCN(Array[Double])
  Op_scn(Array[Double])
  Op_SCNName(PdfName, Array[Double])
  Op_scnName(PdfName, Array[Double])
  Op_sh(PdfName)
  Op_Do(PdfName)
  Op_InlineImage(PdfObject, PdfObject?, PdfBytes)
  Op_MP(PdfName)
  Op_DP(PdfName, PdfObject)
  Op_BMC(PdfName)
  Op_BDC(PdfName, PdfObject)
  Op_EMC
  Op_BX
  Op_EX
  Op_Unknown(PdfBytes)
} derive(Debug, Eq, ToJson)

///|
fn pdf_content_ascii(text : String) -> PdfBytes {
  @ascii.encode(text)
}

///|
fn pdf_content_name(text : String) -> PdfName {
  @core.pdf_name_of_bytes(pdf_content_ascii(text))
}

///|
let pdf_content_artifact_name : PdfName = pdf_content_name("/Artifact")

///|
let pdf_content_begin_artifact_name : PdfName = pdf_content_name(
  "/BeginArtifact",
)

///|
let pdf_content_end_artifact_name : PdfName = pdf_content_name("/EndArtifact")

///|
/// Return the marked-content operation that begins a PDF/UA artifact.
pub fn pdf_content_begin_artifact() -> PdfContentOp {
  Op_BMC(pdf_content_artifact_name)
}

///|
/// Return the marked-content operation that ends the current PDF/UA artifact.
pub fn pdf_content_end_artifact() -> PdfContentOp {
  Op_EMC
}

///|
/// Mark unmarked content operations as PDF/UA artifacts.
///
/// This ports `cpdftype.ml`'s `add_artifacts` pass. Existing marked-content
/// sections entered with `BDC` are preserved as real content; unmarked runs are
/// wrapped in `/Artifact BMC ... EMC`. Back-channel `/BeginArtifact` and
/// `/EndArtifact` markers are converted to ordinary artifact marked content.
pub fn pdf_content_add_artifacts(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = Array::new(capacity=ops.length() + 2)
  let mut in_content = false
  let mut in_artifact = false
  for op in ops {
    match op {
      Op_BMC(name) if name == pdf_content_begin_artifact_name => {
        in_artifact = true
        output.push(Op_BMC(pdf_content_artifact_name))
      }
      Op_BMC(name) if name == pdf_content_end_artifact_name => {
        in_artifact = false
        output.push(Op_EMC)
      }
      Op_BDC(_, _) => {
        if in_artifact {
          output.push(Op_EMC)
        }
        in_content = true
        in_artifact = false
        output.push(op)
      }
      Op_EMC => {
        in_content = false
        output.push(op)
      }
      _ => {
        if !(in_content || in_artifact) {
          in_artifact = true
          output.push(Op_BMC(pdf_content_artifact_name))
        }
        output.push(op)
      }
    }
  }
  if in_artifact {
    output.push(Op_EMC)
  }
  output
}
