///|
fn style(family : String, size_pt : Double) -> @paragraph.RunStyle {
  { family, size_pt, bold: false, italic: false, color: @pagelayout.black, }
}

///|
/// Mixed Latin/CJK in one run: exercises family mapping, per-character
/// fallback, run splitting, and the CJK line-height raise.
fn mixed_model() -> @pagelayout.PageModel {
  @paginate.paginate([
    @paginate.Block::paragraph({
      runs: [
        {
          text: "Hello 布局引擎 text",
          style: style("Calibri", 12),
          field: NotAField,
        },
      ],
      style: @paragraph.ParagraphStyle::default(),
    }),
  ])
}

///|
/// Justified body text over several lines, plus a bold heading.
fn article_model() -> @pagelayout.PageModel {
  let base = @paragraph.ParagraphStyle::default()
  @paginate.paginate(
    [
      @paginate.Block::paragraph(
        {
          runs: [
            {
              text: "Layout Engine",
              field: NotAField,
              style: {
                family: "Cambria",
                size_pt: 16,
                bold: true,
                italic: false,
                color: @pagelayout.black,
              },
            },
          ],
          style: { ..base, space_after_pt: 6, },
        },
        keep_next=true,
      ),
      @paginate.Block::paragraph({
        runs: [
          {
            text: "The quick brown fox jumps over the lazy dog, then does it again to fill the measure.",
            style: style("Calibri", 11),
            field: NotAField,
          },
        ],
        style: { ..base, align: AlignJustify, indent_first_pt: 18, },
      }),
    ],
    section={
      page_width_pt: 306,
      page_height_pt: 200,
      margin_top_pt: 36,
      margin_right_pt: 36,
      margin_bottom_pt: 36,
      margin_left_pt: 36,
      header_pt: 18,
      footer_pt: 18,
    },
  )
}

///|
// Reviewed snapshots; see goldens.mbt for why these are exact rather
// than semantic.

///|
test "golden: mixed-script line" {
  inspect(
    @svg.render_page(mixed_model(), 0),
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg" width="612pt" height="792pt" viewBox="0 0 612 792">
      #|  <rect x="0" y="0" width="612" height="792" fill="#ffffff"/>
      #|  <text x="72 79.477 85.447 88.201 90.955 97.283" y="85.92" font-family="Carlito" font-size="12" fill="#000000">Hello </text>
      #|  <text x="99.996 111.996 123.996 135.996" y="85.92" font-family="Noto Sans SC" font-size="12" fill="#000000">布局引擎</text>
      #|  <text x="147.996 150.709 154.729 160.699 165.896" y="85.92" font-family="Carlito" font-size="12" fill="#000000"> text</text>
      #|</svg>
      #|
    ),
  )
}

///|
test "golden: justified article page" {
  inspect(
    @svg.render_page(article_model(), 0),
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg" width="306pt" height="200pt" viewBox="0 0 306 200">
      #|  <rect x="0" y="0" width="306" height="200" fill="#ffffff"/>
      #|  <text x="36 46.672 54.672 62.672 70.672 79.57 84.898 88.898 99.57 108.469 116.469 120.914 129.813" y="50.258" font-family="Liberation Serif" font-size="16" font-weight="bold" fill="#000000">Layout Engine</text>
      #|  <text x="54 59.36 65.14 70.613 74.833 80.612 86.391 88.916 93.567 98.568 102.787 108.567 112.402 118.202 126.066 131.845 136.065 139.422 145.223 149.987 154.207 156.838 162.618 171.405 177.184 181.486 185.706 191.507 196.475 201.948 205.783 210.003 213.688 219.467 224.94 229.16 231.684 236.953 241.299 246.278 250.498 256.277 262.078 267.255" y="70.872" font-family="Carlito" font-size="11" fill="#000000">The quick brown fox jumps over the lazy dog,</text>
      #|  <text x="36 39.685 45.464 50.937 56.716 59.203 64.982 70.783 76.256 80.559 83.045 85.57 89.254 91.741 97.01 102.188 107.457 109.981 115.761 118.248 121.932 127.733 130.22 133.577 136.101 138.625 141.15 143.637 147.321 153.101 158.574 161.061 169.848 175.321 180.59 184.892 190.671 194.506 199.979" y="84.3" font-family="Carlito" font-size="11" fill="#000000">then does it again to fill the measure.</text>
      #|</svg>
      #|
    ),
  )
}
