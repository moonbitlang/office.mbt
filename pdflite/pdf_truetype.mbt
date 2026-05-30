///|
fn pdf_truetype_subset_extremes(
  subset_codepoints : ArrayView[Int],
) -> (Int, Int) raise PdfError {
  if subset_codepoints.length() == 0 {
    raise SoftError("Cpdftruetype: Refusing to create font with no characters")
  }
  let mut first = subset_codepoints[0]
  let mut last = subset_codepoints[0]
  for codepoint in subset_codepoints {
    if codepoint < first {
      first = codepoint
    }
    if codepoint > last {
      last = codepoint
    }
  }
  (first, last)
}

///|
fn pdf_truetype_parsed_subset(
  flags : Int,
  metrics : @truetype.PdfTrueTypeMetrics,
  descriptor : @truetype.PdfTrueTypeDescriptorMetrics,
  firstchar : Int,
  lastchar : Int,
  widths : Array[Int],
  subset_fontfile : PdfBytes,
  subset : Array[Int],
  tounicode : Array[(Int, PdfBytes)]?,
) -> @truetype.PdfTrueTypeParsedSubset {
  {
    flags,
    minx: metrics.minx,
    miny: metrics.miny,
    maxx: metrics.maxx,
    maxy: metrics.maxy,
    italicangle: descriptor.italicangle,
    ascent: descriptor.ascent,
    descent: descriptor.descent,
    capheight: descriptor.capheight,
    stemv: 0,
    xheight: descriptor.xheight,
    avgwidth: descriptor.avgwidth,
    maxwidth: metrics.max_width,
    firstchar,
    lastchar,
    widths,
    subset_fontfile,
    subset,
    tounicode,
  }
}

///|
/// Parse and subset a TrueType font using cpdf's simple-font split strategy.
///
/// The returned array contains the main non-symbolic subset first, followed by
/// any higher implicit-font-file subsets. This wires together the ported
/// `Cpdftruetype.parse` prerequisites: subset partitioning, width calculation,
/// subset font-file generation, descriptor metrics, and higher-subset
/// ToUnicode mappings.
pub fn pdf_truetype_parse(
  data : BytesView,
  encoding : PdfEncoding,
  subset_codepoints : ArrayView[Int],
) -> Array[@truetype.PdfTrueTypeParsedSubset] raise PdfError {
  let partition = pdf_truetype_partition_subsets(encoding, subset_codepoints)
  let (firstchar, lastchar) = pdf_truetype_subset_extremes(
    partition.main_subset,
  )
  let metrics = pdf_truetype_metrics(data)
  let descriptor = pdf_truetype_descriptor_metrics(data)
  let parsed : Array[@truetype.PdfTrueTypeParsedSubset] = [
    pdf_truetype_parsed_subset(
      descriptor.nonsymbolic_flags,
      metrics,
      descriptor,
      firstchar,
      lastchar,
      pdf_truetype_widths(
        data,
        encoding,
        firstchar,
        lastchar,
        partition.main_subset,
      ),
      pdf_truetype_subset_font(data, partition.main_subset),
      partition.main_subset,
      None,
    ),
  ]
  for subset in partition.higher_subsets {
    if subset.length() > 0 {
      parsed.push(
        pdf_truetype_parsed_subset(
          descriptor.symbolic_flags,
          metrics,
          descriptor,
          33,
          subset.length() + 32,
          pdf_truetype_widths_higher(data, 33, subset.length() + 32, subset),
          pdf_truetype_subset_font(data, subset, rewrite_cmap=true),
          subset,
          pdf_truetype_higher_tounicode(subset),
        ),
      )
    }
  }
  parsed
}
