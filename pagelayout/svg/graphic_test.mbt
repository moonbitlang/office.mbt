///|
test "a graphic renders as nested groups, clips, paths and gradients" {
  let model = @pagelayout.PageModel::new()
  let page = @pagelayout.Page::{ width_pt: 100, height_pt: 50, items: [], }
  let gradient = @pagelayout.Gradient::{
    radial: false,
    x1: 0,
    y1: 0,
    r1: 0,
    x2: 10,
    y2: 0,
    r2: 0,
    stops: [
      { offset: 0, color: @pagelayout.Color::rgb(255, 255, 255), },
      { offset: 1, color: @pagelayout.Color::rgb(0, 0, 0), },
    ],
    transform: @pagelayout.identity,
  }
  page.items.push(
    Graphic({
      x_pt: 10,
      y_pt: 5,
      ops: [
        Save,
        Transform({ a: 2, b: 0, c: 0, d: 2, e: 0, f: 0, }),
        Clip([Rectangle(0, 0, 20, 10)], NonZero),
        Alpha(0.5, 1),
        Path({
          segments: [MoveTo(0, 0), LineTo(10, 0), LineTo(10, 10), Close],
          fill: Some(GradientPaint(gradient)),
          fill_rule: EvenOdd,
          stroke: Some(Solid(@pagelayout.Color::rgb(255, 0, 0))),
          stroke_style: { ..@pagelayout.StrokeStyle::default(), dash: [2, 1], },
        }),
        Restore,
      ],
    }),
  )
  model.pages.push(page)
  inspect(
    @svg.render_page(model, 0),
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg" width="100pt" height="50pt" viewBox="0 0 100 50">
      #|  <rect x="0" y="0" width="100" height="50" fill="#ffffff"/>
      #|  <g transform="translate(10 5)">
      #|  <g transform="matrix(2 0 0 2 0 0)">
      #|  <clipPath id="c1"><path d="M0 10h20v-10h-20Z" clip-rule="nonzero"/></clipPath>
      #|  <g clip-path="url(#c1)">
      #|  <linearGradient id="g2" gradientUnits="userSpaceOnUse" gradientTransform="matrix(1 0 0 1 0 0)" x1="0" y1="0" x2="10" y2="0">
      #|    <stop offset="0" stop-color="#ffffff"/>
      #|    <stop offset="1" stop-color="#000000"/>
      #|  </linearGradient>
      #|  <path d="M0 0L10 0L10 10Z" fill="url(#g2)" fill-rule="evenodd" fill-opacity="0.5" stroke="#ff0000" stroke-width="1" stroke-miterlimit="10" stroke-dasharray="2 1"/>
      #|  </g>
      #|  </g>
      #|  </g>
      #|</svg>
      #|
    ),
  )
}
