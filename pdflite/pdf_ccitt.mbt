///|
priv struct PdfCCITTCode {
  bits : Int
  width : Int
  run : Int
  makeup : Bool
}

///|
priv struct PdfCCITTMode {
  bits : Int
  width : Int
  mode : PdfCCITTModeKind
}

///|
priv enum PdfCCITTModeKind {
  CCITTPass
  CCITTHorizontal
  CCITTVertical(Int)
  CCITTUncompressed
  CCITTEOFB
}

///|
priv struct PdfCCITTRun {
  run : Int
  makeup : Bool
}

///|
priv struct PdfCCITTParams {
  k : Int
  end_of_line : Bool
  encoded_byte_align : Bool
  columns : Int
  rows : Int
  end_of_block : Bool
  black_is_1 : Bool
  damaged_rows_before_error : Int
}

///|
fn pdf_ccitt_default_params() -> PdfCCITTParams {
  {
    k: 0,
    end_of_line: false,
    encoded_byte_align: false,
    columns: 1728,
    rows: 0,
    end_of_block: true,
    black_is_1: false,
    damaged_rows_before_error: 0,
  }
}
