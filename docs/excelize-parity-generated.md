# Excelize parity report (generated)

## Versions

- Excelize: `excelize@37b730a`

- mbtexcel: `e52f823`


## API name parity (normalized)

- Excelize exported funcs + `(*File)` methods: 169

- MoonBit exported names scanned from `.mbti`: 357

- Missing Excelize API names in MoonBit (by normalized name): 0


## Exported type parity (very rough)

This section compares **exported Go type names** to **exported MoonBit type names**.
It is intentionally conservative and may report false positives (e.g. types that exist but are not public, or types that are intentionally modeled differently).


- Missing exported Excelize types (filtered to key feature files): 27


### `excelize/cell.go`

- `cell_type` (Excelize `CellType`)


### `excelize/chart.go`

- `chart_dash_type` (Excelize `ChartDashType`)

- `chart_line_type` (Excelize `ChartLineType`)

- `chart_tick_label_position_type` (Excelize `ChartTickLabelPositionType`)

- `chart_type` (Excelize `ChartType`)


### `excelize/pivotTable.go`

- `pivot_table_field` (Excelize `PivotTableField`)

- `pivot_table_options` (Excelize `PivotTableOptions`)


### `excelize/slicer.go`

- `slicer_options` (Excelize `SlicerOptions`)


### `excelize/xmlChart.go`

- `chart_axis` (Excelize `ChartAxis`)

- `chart_data_label` (Excelize `ChartDataLabel`)

- `chart_data_point` (Excelize `ChartDataPoint`)

- `chart_dimension` (Excelize `ChartDimension`)

- `chart_legend` (Excelize `ChartLegend`)

- `chart_line` (Excelize `ChartLine`)

- `chart_marker` (Excelize `ChartMarker`)

- `chart_num_fmt` (Excelize `ChartNumFmt`)

- `chart_plot_area` (Excelize `ChartPlotArea`)

- `chart_series` (Excelize `ChartSeries`)

- `chart_up_down_bar` (Excelize `ChartUpDownBar`)


### `excelize/xmlDrawing.go`

- `graphic_options` (Excelize `GraphicOptions`)

- `picture` (Excelize `Picture`)

- `shape_line` (Excelize `ShapeLine`)


### `excelize/xmlSharedStrings.go`

- `rich_text_run` (Excelize `RichTextRun`)


### `excelize/xmlStyles.go`

- `alignment` (Excelize `Alignment`)


### `excelize/xmlTable.go`

- `auto_filter_options` (Excelize `AutoFilterOptions`)


### `excelize/xmlWorksheet.go`

- `conditional_format_options` (Excelize `ConditionalFormatOptions`)

- `view_options` (Excelize `ViewOptions`)
