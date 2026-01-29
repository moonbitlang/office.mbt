# Excelize API matrix (one-by-one)
This report is a *navigation aid* for manual parity work: it maps each exported Excelize API name
to its Go definition + Go test usage, and to MoonBit test/doc call sites.
- Excelize dir: `excelize`
- Total normalized API names: **169**
- Max refs per section: **3**

## `add_chart`

**Excelize defs**
- `AddChart` in `excelize/chart.go`

**Excelize tests**
- `AddChart` in `excelize/chart_test.go:44`
- `AddChart` in `excelize/chart_test.go:150`
- `AddChart` in `excelize/chart_test.go:153`
- (more: 18 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:785`
- `xlsx/chart_test.mbt:10`
- `xlsx/chart_test.mbt:45`
- (more: 1 additional hits)

## `add_chart_sheet`

**Excelize defs**
- `AddChartSheet` in `excelize/chart.go`

**Excelize tests**
- `AddChartSheet` in `excelize/adjust_test.go:948`
- `AddChartSheet` in `excelize/adjust_test.go:1094`
- `AddChartSheet` in `excelize/cell_test.go:619`
- (more: 5 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:811`
- `xlsx/chart_sheet_test.mbt:10`
- `xlsx/sheet_management_test.mbt:89`

## `add_comment`

**Excelize defs**
- `AddComment` in `excelize/vml.go`

**Excelize tests**
- `AddComment` in `excelize/excelize_test.go:1019`
- `AddComment` in `excelize/vml_test.go:32`
- `AddComment` in `excelize/vml_test.go:33`
- (more: 10 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:315`
- `xlsx/comment_test.mbt:22`
- `xlsx/comment_test.mbt:69`
- (more: 1 additional hits)

## `add_data_validation`

**Excelize defs**
- `AddDataValidation` in `excelize/datavalidation.go`

**Excelize tests**
- `AddDataValidation` in `excelize/adjust_test.go:1081`
- `AddDataValidation` in `excelize/adjust_test.go:1092`
- `AddDataValidation` in `excelize/adjust_test.go:1102`
- (more: 21 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:102`
- `xlsx/data_validation_test.mbt:8`
- `xlsx/data_validation_test.mbt:49`
- (more: 1 additional hits)

## `add_form_control`

**Excelize defs**
- `AddFormControl` in `excelize/vml.go`

**Excelize tests**
- `AddFormControl` in `excelize/vml_test.go:224`
- `AddFormControl` in `excelize/vml_test.go:257`
- `AddFormControl` in `excelize/vml_test.go:266`
- (more: 4 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:672`
- `mbtexcel_e2e_test.mbt:697`
- `xlsx/shape_form_control_slicer_test.mbt:213`
- (more: 3 additional hits)

## `add_header_footer_image`

**Excelize defs**
- `AddHeaderFooterImage` in `excelize/vml.go`

**Excelize tests**
- `AddHeaderFooterImage` in `excelize/vml_test.go:457`
- `AddHeaderFooterImage` in `excelize/vml_test.go:470`
- `AddHeaderFooterImage` in `excelize/vml_test.go:472`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:188`
- `xlsx/header_footer_image_test.mbt:9`
- `xlsx/header_footer_image_test.mbt:65`
- (more: 2 additional hits)

## `add_ignored_errors`

**Excelize defs**
- `AddIgnoredErrors` in `excelize/sheet.go`

**Excelize tests**
- `AddIgnoredErrors` in `excelize/sheet_test.go:869`
- `AddIgnoredErrors` in `excelize/sheet_test.go:870`
- `AddIgnoredErrors` in `excelize/sheet_test.go:871`
- (more: 9 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:603`
- `mbtexcel_e2e_test.mbt:604`
- `xlsx/ignored_errors_test.mbt:5`
- (more: 3 additional hits)

## `add_picture`

**Excelize defs**
- `AddPicture` in `excelize/picture.go`

**Excelize tests**
- `AddPicture` in `excelize/adjust_test.go:1197`
- `AddPicture` in `excelize/adjust_test.go:1198`
- `AddPicture` in `excelize/adjust_test.go:1199`
- (more: 43 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/picture_ops_test.mbt:420`
- `xlsx/picture_ops_test.mbt:437`
- `xlsx/picture_ops_test.mbt:497`

## `add_picture_from_bytes`

**Excelize defs**
- `AddPictureFromBytes` in `excelize/picture.go`

**Excelize tests**
- `AddPictureFromBytes` in `excelize/excelize_test.go:1649`
- `AddPictureFromBytes` in `excelize/picture_test.go:28`
- `AddPictureFromBytes` in `excelize/picture_test.go:76`
- (more: 10 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:826`
- `xlsx/picture_ops_test.mbt:35`
- `xlsx/picture_ops_test.mbt:77`
- (more: 16 additional hits)

## `add_pivot_table`

**Excelize defs**
- `AddPivotTable` in `excelize/pivotTable.go`

**Excelize tests**
- `AddPivotTable` in `excelize/pivotTable_test.go:50`
- `AddPivotTable` in `excelize/pivotTable_test.go:57`
- `AddPivotTable` in `excelize/pivotTable_test.go:76`
- (more: 24 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:627`
- `xlsx/pivot_test.mbt:140`

## `add_shape`

**Excelize defs**
- `AddShape` in `excelize/shape.go`

**Excelize tests**
- `AddShape` in `excelize/shape_test.go:15`
- `AddShape` in `excelize/shape_test.go:23`
- `AddShape` in `excelize/shape_test.go:25`
- (more: 10 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:787`
- `xlsx/shape_form_control_slicer_test.mbt:6`
- `xlsx/shape_form_control_slicer_test.mbt:79`
- (more: 4 additional hits)

## `add_slicer`

**Excelize defs**
- `AddSlicer` in `excelize/slicer.go`

**Excelize tests**
- `AddSlicer` in `excelize/slicer_test.go:23`
- `AddSlicer` in `excelize/slicer_test.go:30`
- `AddSlicer` in `excelize/slicer_test.go:37`
- (more: 20 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:674`
- `mbtexcel_e2e_test.mbt:699`
- `xlsx/shape_form_control_slicer_test.mbt:375`

## `add_sparkline`

**Excelize defs**
- `AddSparkline` in `excelize/sparkline.go`

**Excelize tests**
- `AddSparkline` in `excelize/sparkline_test.go:31`
- `AddSparkline` in `excelize/sparkline_test.go:37`
- `AddSparkline` in `excelize/sparkline_test.go:44`
- (more: 34 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:137`
- `xlsx/row_col_dimensions_test.mbt:75`
- `xlsx/row_col_dimensions_test.mbt:122`
- (more: 2 additional hits)

## `add_table`

**Excelize defs**
- `AddTable` in `excelize/table.go`

**Excelize tests**
- `AddTable` in `excelize/adjust_test.go:315`
- `AddTable` in `excelize/adjust_test.go:332`
- `AddTable` in `excelize/cell_test.go:811`
- (more: 38 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:136`
- `mbtexcel_e2e_test.mbt:695`
- `xlsx/row_col_dimensions_test.mbt:74`
- (more: 9 additional hits)

## `add_vba_project`

**Excelize defs**
- `AddVBAProject` in `excelize/excelize.go`

**Excelize tests**
- `AddVBAProject` in `excelize/excelize_test.go:1539`
- `AddVBAProject` in `excelize/excelize_test.go:1542`
- `AddVBAProject` in `excelize/excelize_test.go:1544`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:579`
- `xlsx/vba_project_test.mbt:50`
- `xlsx/vba_project_test.mbt:66`

## `auto_filter`

**Excelize defs**
- `AutoFilter` in `excelize/table.go`

**Excelize tests**
- `AutoFilter` in `excelize/adjust_test.go:295`
- `AutoFilter` in `excelize/adjust_test.go:301`
- `AutoFilter` in `excelize/adjust_test.go:306`
- (more: 14 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/compat_test.mbt:23`
- `xlsx/compat_test.mbt:24`

## `calc_cell_value`

**Excelize defs**
- `CalcCellValue` in `excelize/calc.go`

**Excelize tests**
- `CalcCellValue` in `excelize/adjust_test.go:960`
- `CalcCellValue` in `excelize/adjust_test.go:963`
- `CalcCellValue` in `excelize/calc_test.go:2295`
- (more: 107 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:771`
- `mbtexcel_e2e_test.mbt:773`
- `xlsx/calc_test.mbt:9`
- (more: 1832 additional hits)

## `cell_name_to_coordinates`

**Excelize defs**
- `CellNameToCoordinates` in `excelize/lib.go`

**Excelize tests**
- `CellNameToCoordinates` in `excelize/lib_test.go:169`
- `CellNameToCoordinates` in `excelize/lib_test.go:180`
- `CellNameToCoordinates` in `excelize/lib_test.go:186`

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:23`
- `xlsx/cell_ref_test.mbt:14`
- `xlsx/cell_ref_test.mbt:15`
- (more: 1 additional hits)

## `charset_transcoder`

**Excelize defs**
- `CharsetTranscoder` in `excelize/excelize.go`

**Excelize tests**
- `CharsetTranscoder` in `excelize/excelize_test.go:248`

**MoonBit calls (tests/docs)**
- `xlsx/charset_transcoder_test.mbt:67`

## `close`

**Excelize defs**
- `Close` in `excelize/file.go`

**Excelize tests**
- `Close` in `excelize/adjust_test.go:414`
- `Close` in `excelize/adjust_test.go:433`
- `Close` in `excelize/adjust_test.go:455`
- (more: 188 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:39`
- `mbtexcel_e2e_test.mbt:56`
- `xlsx/charset_transcoder_test.mbt:71`
- (more: 4 additional hits)

## `cols`

**Excelize defs**
- `Cols` in `excelize/col.go`

**Excelize tests**
- `Cols` in `excelize/adjust_test.go:452`
- `Cols` in `excelize/adjust_test.go:462`
- `Cols` in `excelize/adjust_test.go:463`
- (more: 17 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/iterators_test.mbt:86`

## `column_name_to_number`

**Excelize defs**
- `ColumnNameToNumber` in `excelize/lib.go`

**Excelize tests**
- `ColumnNameToNumber` in `excelize/lib_test.go:67`
- `ColumnNameToNumber` in `excelize/lib_test.go:77`
- `ColumnNameToNumber` in `excelize/lib_test.go:82`

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:58`
- `mbtexcel_test.mbt:60`
- `xlsx/cell_ref_test.mbt:10`
- (more: 5 additional hits)

## `column_number_to_name`

**Excelize defs**
- `ColumnNumberToName` in `excelize/lib.go`

**Excelize tests**
- `ColumnNumberToName` in `excelize/adjust_test.go:443`
- `ColumnNumberToName` in `excelize/lib_test.go:89`
- `ColumnNumberToName` in `excelize/lib_test.go:97`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:59`
- `mbtexcel_test.mbt:62`
- `xlsx/cell_ref_test.mbt:11`
- (more: 3 additional hits)

## `coordinates_to_cell_name`

**Excelize defs**
- `CoordinatesToCellName` in `excelize/lib.go`

**Excelize tests**
- `CoordinatesToCellName` in `excelize/calc_test.go:18`
- `CoordinatesToCellName` in `excelize/chart_test.go:367`
- `CoordinatesToCellName` in `excelize/excelize_test.go:562`
- (more: 11 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:6`
- `mbtexcel_test.mbt:25`
- `xlsx/cell_ref_test.mbt:20`
- (more: 2 additional hits)

## `copy_sheet`

**Excelize defs**
- `CopySheet` in `excelize/sheet.go`

**Excelize tests**
- `CopySheet` in `excelize/excelize_test.go:1042`
- `CopySheet` in `excelize/excelize_test.go:1044`
- `CopySheet` in `excelize/excelize_test.go:1046`
- (more: 1 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/sheet_management_test.mbt:55`

## `decrypt`

**Excelize defs**
- `Decrypt` in `excelize/crypt.go`

**Excelize tests**
- `Decrypt` in `excelize/crypt_test.go:42`

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:46`

## `delete_chart`

**Excelize defs**
- `DeleteChart` in `excelize/chart.go`

**Excelize tests**
- `DeleteChart` in `excelize/chart_test.go:498`
- `DeleteChart` in `excelize/chart_test.go:530`
- `DeleteChart` in `excelize/chart_test.go:533`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/chart_test.mbt:48`
- `xlsx/chart_test.mbt:50`

## `delete_comment`

**Excelize defs**
- `DeleteComment` in `excelize/vml.go`

**Excelize tests**
- `DeleteComment` in `excelize/vml_test.go:97`
- `DeleteComment` in `excelize/vml_test.go:108`
- `DeleteComment` in `excelize/vml_test.go:110`
- (more: 6 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/comment_test.mbt:29`

## `delete_data_validation`

**Excelize defs**
- `DeleteDataValidation` in `excelize/datavalidation.go`

**Excelize tests**
- `DeleteDataValidation` in `excelize/cell_test.go:101`
- `DeleteDataValidation` in `excelize/datavalidation_test.go:202`
- `DeleteDataValidation` in `excelize/datavalidation_test.go:209`
- (more: 15 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/data_validation_test.mbt:54`

## `delete_defined_name`

**Excelize defs**
- `DeleteDefinedName` in `excelize/sheet.go`

**Excelize tests**
- `DeleteDefinedName` in `excelize/sheet_test.go:318`
- `DeleteDefinedName` in `excelize/sheet_test.go:330`
- `DeleteDefinedName` in `excelize/sheet_test.go:345`

**MoonBit calls (tests/docs)**
- `xlsx/sheet_props_test.mbt:187`
- `xlsx/sheet_props_test.mbt:191`

## `delete_form_control`

**Excelize defs**
- `DeleteFormControl` in `excelize/vml.go`

**Excelize tests**
- `DeleteFormControl` in `excelize/vml_test.go:291`
- `DeleteFormControl` in `excelize/vml_test.go:292`
- `DeleteFormControl` in `excelize/vml_test.go:298`
- (more: 4 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:704`
- `xlsx/shape_form_control_slicer_test.mbt:367`

## `delete_picture`

**Excelize defs**
- `DeletePicture` in `excelize/picture.go`

**Excelize tests**
- `DeletePicture` in `excelize/picture_test.go:400`
- `DeletePicture` in `excelize/picture_test.go:406`
- `DeletePicture` in `excelize/picture_test.go:413`
- (more: 10 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/picture_ops_test.mbt:14`
- `xlsx/picture_ops_test.mbt:26`

## `delete_pivot_table`

**Excelize defs**
- `DeletePivotTable` in `excelize/pivotTable.go`

**Excelize tests**
- `DeletePivotTable` in `excelize/pivotTable_test.go:263`
- `DeletePivotTable` in `excelize/pivotTable_test.go:282`
- `DeletePivotTable` in `excelize/pivotTable_test.go:284`
- (more: 4 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/pivot_test.mbt:150`

## `delete_sheet`

**Excelize defs**
- `DeleteSheet` in `excelize/sheet.go`

**Excelize tests**
- `DeleteSheet` in `excelize/excelize_test.go:1011`
- `DeleteSheet` in `excelize/excelize_test.go:1018`
- `DeleteSheet` in `excelize/sheet_test.go:27`
- (more: 4 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:90`
- `xlsx/sheet_management_test.mbt:24`
- `xlsx/sheet_management_test.mbt:33`

## `delete_slicer`

**Excelize defs**
- `DeleteSlicer` in `excelize/slicer.go`

**Excelize tests**
- `DeleteSlicer` in `excelize/slicer_test.go:488`
- `DeleteSlicer` in `excelize/slicer_test.go:491`
- `DeleteSlicer` in `excelize/slicer_test.go:494`
- (more: 1 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:705`
- `mbtexcel_e2e_test.mbt:711`
- `xlsx/shape_form_control_slicer_test.mbt:405`

## `delete_table`

**Excelize defs**
- `DeleteTable` in `excelize/table.go`

**Excelize tests**
- `DeleteTable` in `excelize/table_test.go:115`
- `DeleteTable` in `excelize/table_test.go:116`
- `DeleteTable` in `excelize/table_test.go:118`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:703`
- `mbtexcel_e2e_test.mbt:709`
- `xlsx/table_ops_test.mbt:16`
- (more: 1 additional hits)

## `duplicate_row`

**Excelize defs**
- `DuplicateRow` in `excelize/rows.go`

**Excelize tests**
- `DuplicateRow` in `excelize/rows_test.go:452`
- `DuplicateRow` in `excelize/rows_test.go:468`
- `DuplicateRow` in `excelize/rows_test.go:505`
- (more: 4 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/duplicate_row_test.mbt:7`
- `xlsx/duplicate_row_test.mbt:38`
- `xlsx/duplicate_row_test.mbt:61`

## `duplicate_row_to`

**Excelize defs**
- `DuplicateRowTo` in `excelize/rows.go`

**Excelize tests**
- `DuplicateRowTo` in `excelize/adjust_test.go:558`
- `DuplicateRowTo` in `excelize/adjust_test.go:630`
- `DuplicateRowTo` in `excelize/rows_test.go:646`
- (more: 15 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/duplicate_row_test.mbt:20`

## `encrypt`

**Excelize defs**
- `Encrypt` in `excelize/crypt.go`

**Excelize tests**
- (none found)

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:45`

## `excel_date_to_time`

**Excelize defs**
- `ExcelDateToTime` in `excelize/date.go`

**Excelize tests**
- `ExcelDateToTime` in `excelize/date_test.go:108`
- `ExcelDateToTime` in `excelize/date_test.go:114`

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:52`
- `mbtexcel_test.mbt:97`
- `mbtexcel_test.mbt:99`
- (more: 5 additional hits)

## `get_active_sheet_index`

**Excelize defs**
- `GetActiveSheetIndex` in `excelize/sheet.go`

**Excelize tests**
- `GetActiveSheetIndex` in `excelize/excelize_test.go:183`
- `GetActiveSheetIndex` in `excelize/excelize_test.go:373`
- `GetActiveSheetIndex` in `excelize/excelize_test.go:1070`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/compat_test.mbt:13`

## `get_app_props`

**Excelize defs**
- `GetAppProps` in `excelize/docProps.go`

**Excelize tests**
- `GetAppProps` in `excelize/docProps_test.go:56`
- `GetAppProps` in `excelize/docProps_test.go:60`
- `GetAppProps` in `excelize/docProps_test.go:67`

**MoonBit calls (tests/docs)**
- `xlsx/doc_props_test.mbt:119`

## `get_base_color`

**Excelize defs**
- `GetBaseColor` in `excelize/styles.go`

**Excelize tests**
- (none found)

**MoonBit calls (tests/docs)**
- `xlsx/color_ops_test.mbt:4`
- `xlsx/color_ops_test.mbt:5`
- `xlsx/color_ops_test.mbt:6`
- (more: 3 additional hits)

## `get_calc_props`

**Excelize defs**
- `GetCalcProps` in `excelize/workbook.go`

**Excelize tests**
- `GetCalcProps` in `excelize/workbook_test.go:53`
- `GetCalcProps` in `excelize/workbook_test.go:57`
- `GetCalcProps` in `excelize/workbook_test.go:70`

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:537`
- `xlsx/compat_test.mbt:58`
- `xlsx/workbook_props_test.mbt:32`

## `get_cell_formula`

**Excelize defs**
- `GetCellFormula` in `excelize/cell.go`

**Excelize tests**
- `GetCellFormula` in `excelize/adjust_test.go:471`
- `GetCellFormula` in `excelize/adjust_test.go:562`
- `GetCellFormula` in `excelize/adjust_test.go:605`
- (more: 62 additional hits)

**MoonBit calls (tests/docs)**
- `README.mbt.md:17`
- `mbtexcel_e2e_test.mbt:117`
- `mbtexcel_e2e_test.mbt:174`
- (more: 6 additional hits)

## `get_cell_hyper_link`

**Excelize defs**
- `GetCellHyperLink` in `excelize/cell.go`

**Excelize tests**
- `GetCellHyperLink` in `excelize/adjust_test.go:523`
- `GetCellHyperLink` in `excelize/adjust_test.go:530`
- `GetCellHyperLink` in `excelize/adjust_test.go:537`
- (more: 9 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/hyperlink_test.mbt:73`

## `get_cell_rich_text`

**Excelize defs**
- `GetCellRichText` in `excelize/cell.go`

**Excelize tests**
- `GetCellRichText` in `excelize/cell_test.go:850`
- `GetCellRichText` in `excelize/cell_test.go:854`
- `GetCellRichText` in `excelize/cell_test.go:874`
- (more: 9 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/rich_text_test.mbt:40`
- `xlsx/rich_text_test.mbt:84`
- `xlsx/rich_text_test.mbt:156`
- (more: 1 additional hits)

## `get_cell_style`

**Excelize defs**
- `GetCellStyle` in `excelize/styles.go`

**Excelize tests**
- `GetCellStyle` in `excelize/cell_test.go:46`
- `GetCellStyle` in `excelize/col_test.go:361`
- `GetCellStyle` in `excelize/excelize_test.go:678`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:120`
- `xlsx/style_test.mbt:85`

## `get_cell_type`

**Excelize defs**
- `GetCellType` in `excelize/cell.go`

**Excelize tests**
- `GetCellType` in `excelize/cell_test.go:545`
- `GetCellType` in `excelize/cell_test.go:549`
- `GetCellType` in `excelize/cell_test.go:552`
- (more: 1 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/cell_value_test.mbt:78`
- `xlsx/cell_value_test.mbt:79`
- `xlsx/cell_value_test.mbt:80`
- (more: 1 additional hits)

## `get_cell_value`

**Excelize defs**
- `GetCellValue` in `excelize/cell.go`

**Excelize tests**
- `GetCellValue` in `excelize/cell_test.go:30`
- `GetCellValue` in `excelize/cell_test.go:106`
- `GetCellValue` in `excelize/cell_test.go:166`
- (more: 72 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/cell_value_test.mbt:29`
- `xlsx/cell_value_test.mbt:31`
- `xlsx/cell_value_test.mbt:44`
- (more: 9 additional hits)

## `get_col_outline_level`

**Excelize defs**
- `GetColOutlineLevel` in `excelize/col.go`

**Excelize tests**
- `GetColOutlineLevel` in `excelize/col_test.go:265`
- `GetColOutlineLevel` in `excelize/col_test.go:273`
- `GetColOutlineLevel` in `excelize/col_test.go:277`
- (more: 2 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/row_col_dimensions_test.mbt:38`

## `get_col_style`

**Excelize defs**
- `GetColStyle` in `excelize/col.go`

**Excelize tests**
- `GetColStyle` in `excelize/cell_test.go:79`
- `GetColStyle` in `excelize/col_test.go:351`
- `GetColStyle` in `excelize/col_test.go:423`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:122`
- `xlsx/col_range_test.mbt:51`
- `xlsx/col_range_test.mbt:52`
- (more: 3 additional hits)

## `get_col_visible`

**Excelize defs**
- `GetColVisible` in `excelize/col.go`

**Excelize tests**
- `GetColVisible` in `excelize/cell_test.go:91`
- `GetColVisible` in `excelize/col_test.go:206`
- `GetColVisible` in `excelize/col_test.go:212`
- (more: 9 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/row_col_dimensions_test.mbt:37`

## `get_col_width`

**Excelize defs**
- `GetColWidth` in `excelize/col.go`

**Excelize tests**
- `GetColWidth` in `excelize/adjust_test.go:410`
- `GetColWidth` in `excelize/adjust_test.go:429`
- `GetColWidth` in `excelize/adjust_test.go:445`
- (more: 11 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/col_range_test.mbt:27`
- `xlsx/col_range_test.mbt:28`
- `xlsx/col_range_test.mbt:29`
- (more: 4 additional hits)

## `get_cols`

**Excelize defs**
- `GetCols` in `excelize/col.go`

**Excelize tests**
- `GetCols` in `excelize/cell_test.go:394`
- `GetCols` in `excelize/cell_test.go:492`
- `GetCols` in `excelize/col_test.go:36`
- (more: 4 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/iterators_test.mbt:107`
- `xlsx/options_test.mbt:11`
- `xlsx/options_test.mbt:12`

## `get_comments`

**Excelize defs**
- `GetComments` in `excelize/vml.go`

**Excelize tests**
- `GetComments` in `excelize/vml_test.go:41`
- `GetComments` in `excelize/vml_test.go:44`
- `GetComments` in `excelize/vml_test.go:51`
- (more: 7 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:317`
- `xlsx/comment_test.mbt:24`
- `xlsx/comment_test.mbt:30`
- (more: 2 additional hits)

## `get_conditional_formats`

**Excelize defs**
- `GetConditionalFormats` in `excelize/styles.go`

**Excelize tests**
- `GetConditionalFormats` in `excelize/adjust_test.go:1011`
- `GetConditionalFormats` in `excelize/adjust_test.go:1036`
- `GetConditionalFormats` in `excelize/adjust_test.go:1052`
- (more: 13 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/conditional_format_test.mbt:13`

## `get_conditional_style`

**Excelize defs**
- `GetConditionalStyle` in `excelize/styles.go`

**Excelize tests**
- `GetConditionalStyle` in `excelize/styles_test.go:554`
- `GetConditionalStyle` in `excelize/styles_test.go:564`
- `GetConditionalStyle` in `excelize/styles_test.go:582`
- (more: 2 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/style_test.mbt:120`
- `xlsx/style_test.mbt:376`
- `xlsx/style_test.mbt:557`
- (more: 6 additional hits)

## `get_custom_props`

**Excelize defs**
- `GetCustomProps` in `excelize/docProps.go`

**Excelize tests**
- `GetCustomProps` in `excelize/docProps_test.go:136`
- `GetCustomProps` in `excelize/docProps_test.go:142`
- `GetCustomProps` in `excelize/docProps_test.go:149`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:425`
- `xlsx/doc_props_test.mbt:75`

## `get_data_validations`

**Excelize defs**
- `GetDataValidations` in `excelize/datavalidation.go`

**Excelize tests**
- `GetDataValidations` in `excelize/adjust_test.go:1083`
- `GetDataValidations` in `excelize/adjust_test.go:1105`
- `GetDataValidations` in `excelize/adjust_test.go:1118`
- (more: 19 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:123`
- `xlsx/data_validation_test.mbt:9`
- `xlsx/data_validation_test.mbt:55`

## `get_default_font`

**Excelize defs**
- `GetDefaultFont` in `excelize/styles.go`

**Excelize tests**
- `GetDefaultFont` in `excelize/styles_test.go:605`
- `GetDefaultFont` in `excelize/styles_test.go:611`
- `GetDefaultFont` in `excelize/styles_test.go:620`

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:546`
- `xlsx/style_test.mbt:140`

## `get_defined_name`

**Excelize defs**
- `GetDefinedName` in `excelize/sheet.go`

**Excelize tests**
- `GetDefinedName` in `excelize/adjust_test.go:1299`
- `GetDefinedName` in `excelize/adjust_test.go:1322`
- `GetDefinedName` in `excelize/adjust_test.go:1332`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/compat_test.mbt:16`

## `get_doc_props`

**Excelize defs**
- `GetDocProps` in `excelize/docProps.go`

**Excelize tests**
- `GetDocProps` in `excelize/docProps_test.go:108`
- `GetDocProps` in `excelize/docProps_test.go:112`
- `GetDocProps` in `excelize/docProps_test.go:119`

**MoonBit calls (tests/docs)**
- `xlsx/doc_props_test.mbt:98`

## `get_form_controls`

**Excelize defs**
- `GetFormControls` in `excelize/vml.go`

**Excelize tests**
- `GetFormControls` in `excelize/vml_test.go:227`
- `GetFormControls` in `excelize/vml_test.go:253`
- `GetFormControls` in `excelize/vml_test.go:262`
- (more: 15 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:675`
- `mbtexcel_e2e_test.mbt:701`
- `mbtexcel_e2e_test.mbt:707`
- (more: 3 additional hits)

## `get_header_footer`

**Excelize defs**
- `GetHeaderFooter` in `excelize/sheet.go`

**Excelize tests**
- `GetHeaderFooter` in `excelize/sheet_test.go:248`
- `GetHeaderFooter` in `excelize/sheet_test.go:252`
- `GetHeaderFooter` in `excelize/sheet_test.go:284`

**MoonBit calls (tests/docs)**
- `xlsx/sheet_props_test.mbt:72`
- `xlsx/sheet_props_test.mbt:87`

## `get_merge_cells`

**Excelize defs**
- `GetMergeCells` in `excelize/merge.go`

**Excelize tests**
- `GetMergeCells` in `excelize/merge_test.go:85`
- `GetMergeCells` in `excelize/merge_test.go:102`
- `GetMergeCells` in `excelize/merge_test.go:140`
- (more: 5 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:121`
- `xlsx/merge_cells_test.mbt:43`
- `xlsx/merge_cells_test.mbt:45`

## `get_page_layout`

**Excelize defs**
- `GetPageLayout` in `excelize/sheet.go`

**Excelize tests**
- `GetPageLayout` in `excelize/sheet_test.go:216`
- `GetPageLayout` in `excelize/sheet_test.go:238`
- `GetPageLayout` in `excelize/sheet_test.go:241`

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:473`
- `xlsx/sheet_props_test.mbt:26`

## `get_page_margins`

**Excelize defs**
- `GetPageMargins` in `excelize/sheetpr.go`

**Excelize tests**
- `GetPageMargins` in `excelize/sheetpr_test.go:27`
- `GetPageMargins` in `excelize/sheetpr_test.go:39`
- `GetPageMargins` in `excelize/sheetpr_test.go:42`

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:472`
- `xlsx/sheet_props_test.mbt:21`

## `get_panes`

**Excelize defs**
- `GetPanes` in `excelize/sheet.go`

**Excelize tests**
- `GetPanes` in `excelize/sheet_test.go:60`
- `GetPanes` in `excelize/sheet_test.go:108`
- `GetPanes` in `excelize/sheet_test.go:112`
- (more: 2 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:513`
- `xlsx/sheet_view_test.mbt:81`
- `xlsx/sheet_view_test.mbt:161`
- (more: 1 additional hits)

## `get_picture_cells`

**Excelize defs**
- `GetPictureCells` in `excelize/picture.go`

**Excelize tests**
- `GetPictureCells` in `excelize/adjust_test.go:1207`
- `GetPictureCells` in `excelize/adjust_test.go:1216`
- `GetPictureCells` in `excelize/adjust_test.go:1228`
- (more: 12 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/picture_ops_test.mbt:13`
- `xlsx/picture_ops_test.mbt:19`
- `xlsx/picture_ops_test.mbt:27`

## `get_pictures`

**Excelize defs**
- `GetPictures` in `excelize/picture.go`

**Excelize tests**
- `GetPictures` in `excelize/cell_test.go:59`
- `GetPictures` in `excelize/picture_test.go:86`
- `GetPictures` in `excelize/picture_test.go:91`
- (more: 45 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/picture_ops_test.mbt:10`
- `xlsx/picture_ops_test.mbt:16`
- `xlsx/picture_ops_test.mbt:37`

## `get_pivot_tables`

**Excelize defs**
- `GetPivotTables` in `excelize/pivotTable.go`

**Excelize tests**
- `GetPivotTables` in `excelize/pivotTable_test.go:52`
- `GetPivotTables` in `excelize/pivotTable_test.go:71`
- `GetPivotTables` in `excelize/pivotTable_test.go:147`
- (more: 9 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:635`
- `xlsx/pivot_test.mbt:147`
- `xlsx/pivot_test.mbt:151`

## `get_row_height`

**Excelize defs**
- `GetRowHeight` in `excelize/rows.go`

**Excelize tests**
- `GetRowHeight` in `excelize/rows_test.go:158`
- `GetRowHeight` in `excelize/rows_test.go:162`
- `GetRowHeight` in `excelize/rows_test.go:170`
- (more: 7 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/duplicate_row_test.mbt:39`
- `xlsx/row_col_dimensions_test.mbt:16`
- `xlsx/row_col_dimensions_test.mbt:96`
- (more: 2 additional hits)

## `get_row_outline_level`

**Excelize defs**
- `GetRowOutlineLevel` in `excelize/rows.go`

**Excelize tests**
- `GetRowOutlineLevel` in `excelize/col_test.go:299`
- `GetRowOutlineLevel` in `excelize/col_test.go:302`
- `GetRowOutlineLevel` in `excelize/col_test.go:313`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/row_col_dimensions_test.mbt:36`

## `get_row_visible`

**Excelize defs**
- `GetRowVisible` in `excelize/rows.go`

**Excelize tests**
- `GetRowVisible` in `excelize/rows_test.go:278`
- `GetRowVisible` in `excelize/rows_test.go:281`
- `GetRowVisible` in `excelize/rows_test.go:289`
- (more: 2 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/row_col_dimensions_test.mbt:35`

## `get_rows`

**Excelize defs**
- `GetRows` in `excelize/rows.go`

**Excelize tests**
- `GetRows` in `excelize/cell_test.go:386`
- `GetRows` in `excelize/cell_test.go:408`
- `GetRows` in `excelize/cell_test.go:415`
- (more: 14 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/iterators_test.mbt:105`
- `xlsx/options_test.mbt:8`
- `xlsx/options_test.mbt:10`

## `get_sheet_dimension`

**Excelize defs**
- `GetSheetDimension` in `excelize/sheet.go`

**Excelize tests**
- `GetSheetDimension` in `excelize/sheet_test.go:793`
- `GetSheetDimension` in `excelize/sheet_test.go:799`
- `GetSheetDimension` in `excelize/sheet_test.go:806`
- (more: 5 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:518`
- `xlsx/sheet_view_test.mbt:99`
- `xlsx/sheet_view_test.mbt:115`

## `get_sheet_index`

**Excelize defs**
- `GetSheetIndex` in `excelize/sheet.go`

**Excelize tests**
- `GetSheetIndex` in `excelize/excelize_test.go:185`
- `GetSheetIndex` in `excelize/sheet_test.go:25`
- `GetSheetIndex` in `excelize/sheet_test.go:32`
- (more: 1 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/compat_test.mbt:11`

## `get_sheet_list`

**Excelize defs**
- `GetSheetList` in `excelize/sheet.go`

**Excelize tests**
- `GetSheetList` in `excelize/chart_test.go:467`
- `GetSheetList` in `excelize/sheet_test.go:574`
- `GetSheetList` in `excelize/sheet_test.go:578`
- (more: 2 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:83`
- `xlsx/sheet_management_test.mbt:92`

## `get_sheet_map`

**Excelize defs**
- `GetSheetMap` in `excelize/sheet.go`

**Excelize tests**
- `GetSheetMap` in `excelize/excelize_test.go:190`
- `GetSheetMap` in `excelize/sheet_test.go:433`

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:86`
- `xlsx/sheet_management_test.mbt:95`

## `get_sheet_name`

**Excelize defs**
- `GetSheetName` in `excelize/sheet.go`

**Excelize tests**
- `GetSheetName` in `excelize/chart_test.go:15`
- `GetSheetName` in `excelize/chart_test.go:546`
- `GetSheetName` in `excelize/col_test.go:440`
- (more: 21 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/compat_test.mbt:12`

## `get_sheet_props`

**Excelize defs**
- `GetSheetProps` in `excelize/sheetpr.go`

**Excelize tests**
- `GetSheetProps` in `excelize/sheetpr_test.go:75`
- `GetSheetProps` in `excelize/sheetpr_test.go:104`
- `GetSheetProps` in `excelize/sheetpr_test.go:107`

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:355`
- `xlsx/sheet_props_test.mbt:243`
- `xlsx/sheet_props_test.mbt:274`

## `get_sheet_view`

**Excelize defs**
- `GetSheetView` in `excelize/sheetview.go`

**Excelize tests**
- `GetSheetView` in `excelize/sheetview_test.go:28`
- `GetSheetView` in `excelize/sheetview_test.go:43`
- `GetSheetView` in `excelize/sheetview_test.go:45`
- (more: 2 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:509`
- `xlsx/sheet_view_test.mbt:18`
- `xlsx/sheet_view_test.mbt:148`

## `get_sheet_visible`

**Excelize defs**
- `GetSheetVisible` in `excelize/sheet.go`

**Excelize tests**
- `GetSheetVisible` in `excelize/excelize_test.go:1032`
- `GetSheetVisible` in `excelize/sheet_test.go:636`
- `GetSheetVisible` in `excelize/sheet_test.go:644`

**MoonBit calls (tests/docs)**
- `xlsx/compat_test.mbt:14`

## `get_slicers`

**Excelize defs**
- `GetSlicers` in `excelize/slicer.go`

**Excelize tests**
- `GetSlicers` in `excelize/slicer_test.go:51`
- `GetSlicers` in `excelize/slicer_test.go:143`
- `GetSlicers` in `excelize/slicer_test.go:223`
- (more: 15 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:676`
- `mbtexcel_e2e_test.mbt:702`
- `mbtexcel_e2e_test.mbt:708`
- (more: 2 additional hits)

## `get_style`

**Excelize defs**
- `GetStyle` in `excelize/styles.go`

**Excelize tests**
- `GetStyle` in `excelize/styles_test.go:539`
- `GetStyle` in `excelize/styles_test.go:750`
- `GetStyle` in `excelize/styles_test.go:765`
- (more: 9 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/style_test.mbt:80`
- `xlsx/style_test.mbt:291`
- `xlsx/style_test.mbt:324`
- (more: 10 additional hits)

## `get_tables`

**Excelize defs**
- `GetTables` in `excelize/table.go`

**Excelize tests**
- `GetTables` in `excelize/table_test.go:31`
- `GetTables` in `excelize/table_test.go:93`
- `GetTables` in `excelize/table_test.go:97`
- (more: 2 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:146`
- `mbtexcel_e2e_test.mbt:700`
- `mbtexcel_e2e_test.mbt:706`
- (more: 3 additional hits)

## `get_workbook_props`

**Excelize defs**
- `GetWorkbookProps` in `excelize/workbook.go`

**Excelize tests**
- `GetWorkbookProps` in `excelize/workbook_test.go:21`
- `GetWorkbookProps` in `excelize/workbook_test.go:25`
- `GetWorkbookProps` in `excelize/workbook_test.go:35`

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:371`
- `xlsx/workbook_props_test.mbt:28`

## `group_sheets`

**Excelize defs**
- `GroupSheets` in `excelize/sheet.go`

**Excelize tests**
- `GroupSheets` in `excelize/sheet_test.go:356`
- `GroupSheets` in `excelize/sheet_test.go:357`
- `GroupSheets` in `excelize/sheet_test.go:359`
- (more: 1 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:722`
- `mbtexcel_e2e_test.mbt:729`
- `xlsx/sheet_management_test.mbt:128`
- (more: 1 additional hits)

## `hsl_to_rgb`

**Excelize defs**
- `HSLToRGB` in `excelize/hsl.go`

**Excelize tests**
- `HSLToRGB` in `excelize/excelize_test.go:1352`
- `HSLToRGB` in `excelize/excelize_test.go:1356`

**MoonBit calls (tests/docs)**
- `xlsx/color_convert_test.mbt:8`
- `xlsx/color_convert_test.mbt:12`

## `insert_cols`

**Excelize defs**
- `InsertCols` in `excelize/col.go`

**Excelize tests**
- `InsertCols` in `excelize/adjust_test.go:366`
- `InsertCols` in `excelize/adjust_test.go:377`
- `InsertCols` in `excelize/adjust_test.go:379`
- (more: 46 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:294`
- `xlsx/auto_filter_test.mbt:49`
- `xlsx/hyperlink_test.mbt:52`
- (more: 1 additional hits)

## `insert_page_break`

**Excelize defs**
- `InsertPageBreak` in `excelize/sheet.go`

**Excelize tests**
- `InsertPageBreak` in `excelize/sheet_test.go:376`
- `InsertPageBreak` in `excelize/sheet_test.go:377`
- `InsertPageBreak` in `excelize/sheet_test.go:378`
- (more: 11 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:399`
- `xlsx/sheet_props_test.mbt:201`
- `xlsx/sheet_props_test.mbt:202`

## `insert_rows`

**Excelize defs**
- `InsertRows` in `excelize/rows.go`

**Excelize tests**
- `InsertRows` in `excelize/adjust_test.go:367`
- `InsertRows` in `excelize/adjust_test.go:522`
- `InsertRows` in `excelize/adjust_test.go:560`
- (more: 48 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:293`
- `xlsx/hyperlink_test.mbt:44`
- `xlsx/row_col_dimensions_test.mbt:77`
- (more: 2 additional hits)

## `join_cell_name`

**Excelize defs**
- `JoinCellName` in `excelize/lib.go`

**Excelize tests**
- `JoinCellName` in `excelize/lib_test.go:139`
- `JoinCellName` in `excelize/lib_test.go:150`

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:5`
- `mbtexcel_e2e_test.mbt:10`
- `xlsx/cell_ref_test.mbt:7`
- (more: 1 additional hits)

## `merge_cell`

**Excelize defs**
- `MergeCell` in `excelize/merge.go`

**Excelize tests**
- `MergeCell` in `excelize/col_test.go:445`
- `MergeCell` in `excelize/col_test.go:470`
- `MergeCell` in `excelize/col_test.go:471`
- (more: 22 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:95`
- `xlsx/merge_cells_test.mbt:42`
- `xlsx/stream_test.mbt:98`

## `move_sheet`

**Excelize defs**
- `MoveSheet` in `excelize/sheet.go`

**Excelize tests**
- `MoveSheet` in `excelize/sheet_test.go:577`
- `MoveSheet` in `excelize/sheet_test.go:582`
- `MoveSheet` in `excelize/sheet_test.go:583`
- (more: 6 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/sheet_management_test.mbt:43`

## `new_conditional_style`

**Excelize defs**
- `NewConditionalStyle` in `excelize/styles.go`

**Excelize tests**
- `NewConditionalStyle` in `excelize/adjust_test.go:997`
- `NewConditionalStyle` in `excelize/excelize_test.go:1088`
- `NewConditionalStyle` in `excelize/excelize_test.go:1092`
- (more: 16 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/style_test.mbt:100`
- `xlsx/style_test.mbt:356`
- `xlsx/style_test.mbt:532`
- (more: 6 additional hits)

## `new_data_validation`

**Excelize defs**
- `NewDataValidation` in `excelize/datavalidation.go`

**Excelize tests**
- `NewDataValidation` in `excelize/adjust_test.go:1078`
- `NewDataValidation` in `excelize/adjust_test.go:1089`
- `NewDataValidation` in `excelize/adjust_test.go:1098`
- (more: 15 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:99`
- `mbtexcel_test.mbt:30`

## `new_file`

**Excelize defs**
- `NewFile` in `excelize/file.go`

**Excelize tests**
- `NewFile` in `excelize/adjust_test.go:16`
- `NewFile` in `excelize/adjust_test.go:282`
- `NewFile` in `excelize/adjust_test.go:290`
- (more: 422 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:21`
- `mbtexcel_test.mbt:78`

## `new_sheet`

**Excelize defs**
- `NewSheet` in `excelize/sheet.go`

**Excelize tests**
- `NewSheet` in `excelize/adjust_test.go:346`
- `NewSheet` in `excelize/adjust_test.go:484`
- `NewSheet` in `excelize/adjust_test.go:498`
- (more: 56 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/compat_test.mbt:4`

## `new_stack`

**Excelize defs**
- `NewStack` in `excelize/lib.go`

**Excelize tests**
- `NewStack` in `excelize/lib_test.go:308`

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:32`

## `new_stream_writer`

**Excelize defs**
- `NewStreamWriter` in `excelize/stream.go`

**Excelize tests**
- `NewStreamWriter` in `excelize/cell_test.go:229`
- `NewStreamWriter` in `excelize/file_test.go:113`
- `NewStreamWriter` in `excelize/stream_test.go:31`
- (more: 21 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:164`
- `xlsx/stream_test.mbt:5`
- `xlsx/stream_test.mbt:26`
- (more: 5 additional hits)

## `new_style`

**Excelize defs**
- `NewStyle` in `excelize/styles.go`

**Excelize tests**
- `NewStyle` in `excelize/calc_test.go:6546`
- `NewStyle` in `excelize/cell_test.go:41`
- `NewStyle` in `excelize/cell_test.go:253`
- (more: 85 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/stream_test.mbt:56`
- `xlsx/stream_test.mbt:93`
- `xlsx/style_test.mbt:79`
- (more: 12 additional hits)

## `open_file`

**Excelize defs**
- `OpenFile` in `excelize/excelize.go`

**Excelize tests**
- `OpenFile` in `excelize/adjust_test.go:1221`
- `OpenFile` in `excelize/adjust_test.go:1233`
- `OpenFile` in `excelize/adjust_test.go:1245`
- (more: 105 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:75`
- `xlsx/io_password_test.mbt:18`
- `xlsx/io_password_test.mbt:43`
- (more: 2 additional hits)

## `open_reader`

**Excelize defs**
- `OpenReader` in `excelize/excelize.go`

**Excelize tests**
- `OpenReader` in `excelize/chart_test.go:63`
- `OpenReader` in `excelize/chart_test.go:597`
- `OpenReader` in `excelize/crypt_test.go:84`
- (more: 9 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:42`
- `xlsx/io_password_test.mbt:15`
- `xlsx/io_test.mbt:112`

## `protect_sheet`

**Excelize defs**
- `ProtectSheet` in `excelize/sheet.go`

**Excelize tests**
- `ProtectSheet` in `excelize/excelize_test.go:1390`
- `ProtectSheet` in `excelize/excelize_test.go:1392`
- `ProtectSheet` in `excelize/excelize_test.go:1401`
- (more: 7 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:263`
- `mbtexcel_test.mbt:181`
- `xlsx/sheet_props_test.mbt:95`
- (more: 1 additional hits)

## `protect_workbook`

**Excelize defs**
- `ProtectWorkbook` in `excelize/workbook.go`

**Excelize tests**
- `ProtectWorkbook` in `excelize/excelize_test.go:1466`
- `ProtectWorkbook` in `excelize/excelize_test.go:1468`
- `ProtectWorkbook` in `excelize/excelize_test.go:1480`
- (more: 4 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:384`
- `mbtexcel_test.mbt:167`
- `xlsx/workbook_protection_test.mbt:8`

## `read_zip_reader`

**Excelize defs**
- `ReadZipReader` in `excelize/lib.go`

**Excelize tests**
- (none found)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:59`
- `xlsx/charset_transcoder_test.mbt:74`
- `xlsx/io_test.mbt:129`

## `remove_col`

**Excelize defs**
- `RemoveCol` in `excelize/col.go`

**Excelize tests**
- `RemoveCol` in `excelize/adjust_test.go:328`
- `RemoveCol` in `excelize/adjust_test.go:373`
- `RemoveCol` in `excelize/adjust_test.go:427`
- (more: 28 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/row_col_dimensions_test.mbt:61`

## `remove_page_break`

**Excelize defs**
- `RemovePageBreak` in `excelize/sheet.go`

**Excelize tests**
- `RemovePageBreak` in `excelize/sheet_test.go:389`
- `RemovePageBreak` in `excelize/sheet_test.go:393`
- `RemovePageBreak` in `excelize/sheet_test.go:394`
- (more: 7 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/sheet_props_test.mbt:212`

## `remove_row`

**Excelize defs**
- `RemoveRow` in `excelize/rows.go`

**Excelize tests**
- `RemoveRow` in `excelize/adjust_test.go:325`
- `RemoveRow` in `excelize/adjust_test.go:326`
- `RemoveRow` in `excelize/adjust_test.go:327`
- (more: 27 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/row_col_dimensions_test.mbt:48`

## `rgb_to_hsl`

**Excelize defs**
- `RGBToHSL` in `excelize/hsl.go`

**Excelize tests**
- `RGBToHSL` in `excelize/excelize_test.go:1365`
- `RGBToHSL` in `excelize/excelize_test.go:1369`
- `RGBToHSL` in `excelize/excelize_test.go:1373`
- (more: 2 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/color_convert_test.mbt:20`
- `xlsx/color_convert_test.mbt:24`
- `xlsx/color_convert_test.mbt:28`
- (more: 2 additional hits)

## `rows`

**Excelize defs**
- `Rows` in `excelize/rows.go`

**Excelize tests**
- `Rows` in `excelize/cell_test.go:63`
- `Rows` in `excelize/cell_test.go:73`
- `Rows` in `excelize/cell_test.go:1198`
- (more: 47 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/iterators_test.mbt:8`
- `xlsx/iterators_test.mbt:33`
- `xlsx/iterators_test.mbt:54`
- (more: 4 additional hits)

## `save`

**Excelize defs**
- `Save` in `excelize/file.go`

**Excelize tests**
- `Save` in `excelize/calc_test.go:2082`
- `Save` in `excelize/chart_test.go:60`
- `Save` in `excelize/crypt_test.go:56`
- (more: 15 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/io_test.mbt:92`

## `save_as`

**Excelize defs**
- `SaveAs` in `excelize/file.go`

**Excelize tests**
- `SaveAs` in `excelize/adjust_test.go:329`
- `SaveAs` in `excelize/adjust_test.go:550`
- `SaveAs` in `excelize/adjust_test.go:566`
- (more: 130 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/io_password_test.mbt:42`
- `xlsx/io_test.mbt:88`

## `search_sheet`

**Excelize defs**
- `SearchSheet` in `excelize/sheet.go`

**Excelize tests**
- `SearchSheet` in `excelize/sheet_test.go:148`
- `SearchSheet` in `excelize/sheet_test.go:151`
- `SearchSheet` in `excelize/sheet_test.go:155`
- (more: 7 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/compat_test.mbt:41`
- `xlsx/compat_test.mbt:43`

## `set_active_sheet`

**Excelize defs**
- `SetActiveSheet` in `excelize/sheet.go`

**Excelize tests**
- `SetActiveSheet` in `excelize/chart_test.go:473`
- `SetActiveSheet` in `excelize/excelize_test.go:88`
- `SetActiveSheet` in `excelize/excelize_test.go:374`
- (more: 9 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:564`
- `mbtexcel_e2e_test.mbt:567`
- `mbtexcel_e2e_test.mbt:721`
- (more: 2 additional hits)

## `set_app_props`

**Excelize defs**
- `SetAppProps` in `excelize/docProps.go`

**Excelize tests**
- `SetAppProps` in `excelize/docProps_test.go:31`
- `SetAppProps` in `excelize/docProps_test.go:42`
- `SetAppProps` in `excelize/docProps_test.go:48`

**MoonBit calls (tests/docs)**
- `xlsx/doc_props_test.mbt:118`

## `set_calc_props`

**Excelize defs**
- `SetCalcProps` in `excelize/workbook.go`

**Excelize tests**
- `SetCalcProps` in `excelize/workbook_test.go:41`
- `SetCalcProps` in `excelize/workbook_test.go:52`
- `SetCalcProps` in `excelize/workbook_test.go:61`
- (more: 2 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:534`
- `mbtexcel_test.mbt:143`
- `mbtexcel_test.mbt:151`
- (more: 3 additional hits)

## `set_cell_bool`

**Excelize defs**
- `SetCellBool` in `excelize/cell.go`

**Excelize tests**
- `SetCellBool` in `excelize/calc_test.go:6736`
- `SetCellBool` in `excelize/cell_test.go:353`
- `SetCellBool` in `excelize/cell_test.go:355`
- (more: 1 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:93`
- `xlsx/cell_value_test.mbt:72`

## `set_cell_default`

**Excelize defs**
- `SetCellDefault` in `excelize/cell.go`

**Excelize tests**
- `SetCellDefault` in `excelize/calc_test.go:6737`
- `SetCellDefault` in `excelize/excelize_test.go:58`
- `SetCellDefault` in `excelize/excelize_test.go:59`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/cell_value_test.mbt:77`

## `set_cell_float`

**Excelize defs**
- `SetCellFloat` in `excelize/cell.go`

**Excelize tests**
- `SetCellFloat` in `excelize/calc_test.go:6734`
- `SetCellFloat` in `excelize/cell_test.go:164`
- `SetCellFloat` in `excelize/cell_test.go:165`
- (more: 6 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:94`
- `xlsx/cell_value_test.mbt:75`
- `xlsx/iterators_test.mbt:64`
- (more: 4 additional hits)

## `set_cell_formula`

**Excelize defs**
- `SetCellFormula` in `excelize/cell.go`

**Excelize tests**
- `SetCellFormula` in `excelize/adjust_test.go:469`
- `SetCellFormula` in `excelize/adjust_test.go:481`
- `SetCellFormula` in `excelize/adjust_test.go:495`
- (more: 169 additional hits)

**MoonBit calls (tests/docs)**
- `README.mbt.md:13`
- `mbtexcel_e2e_test.mbt:92`
- `mbtexcel_e2e_test.mbt:764`
- (more: 1807 additional hits)

## `set_cell_hyper_link`

**Excelize defs**
- `SetCellHyperLink` in `excelize/cell.go`

**Excelize tests**
- `SetCellHyperLink` in `excelize/adjust_test.go:521`
- `SetCellHyperLink` in `excelize/adjust_test.go:543`
- `SetCellHyperLink` in `excelize/calc_test.go:6739`
- (more: 23 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/hyperlink_test.mbt:66`

## `set_cell_int`

**Excelize defs**
- `SetCellInt` in `excelize/cell.go`

**Excelize tests**
- `SetCellInt` in `excelize/calc_test.go:6732`
- `SetCellInt` in `excelize/excelize_test.go:66`
- `SetCellInt` in `excelize/excelize_test.go:69`
- (more: 10 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:90`
- `mbtexcel_e2e_test.mbt:91`
- `mbtexcel_e2e_test.mbt:135`
- (more: 1 additional hits)

## `set_cell_rich_text`

**Excelize defs**
- `SetCellRichText` in `excelize/cell.go`

**Excelize tests**
- `SetCellRichText` in `excelize/calc_test.go:6742`
- `SetCellRichText` in `excelize/calc_test.go:6744`
- `SetCellRichText` in `excelize/cell_test.go:847`
- (more: 11 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/rich_text_test.mbt:38`
- `xlsx/rich_text_test.mbt:81`
- `xlsx/rich_text_test.mbt:105`
- (more: 2 additional hits)

## `set_cell_str`

**Excelize defs**
- `SetCellStr` in `excelize/cell.go`

**Excelize tests**
- `SetCellStr` in `excelize/calc_test.go:6735`
- `SetCellStr` in `excelize/datavalidation_test.go:140`
- `SetCellStr` in `excelize/datavalidation_test.go:141`
- (more: 31 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/cell_value_test.mbt:76`
- `xlsx/value_format_test.mbt:18`

## `set_cell_style`

**Excelize defs**
- `SetCellStyle` in `excelize/styles.go`

**Excelize tests**
- `SetCellStyle` in `excelize/calc_test.go:6548`
- `SetCellStyle` in `excelize/cell_test.go:44`
- `SetCellStyle` in `excelize/cell_test.go:1021`
- (more: 39 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:98`
- `xlsx/cell_value_test.mbt:28`
- `xlsx/cell_value_test.mbt:42`
- (more: 25 additional hits)

## `set_cell_uint`

**Excelize defs**
- `SetCellUint` in `excelize/cell.go`

**Excelize tests**
- `SetCellUint` in `excelize/calc_test.go:6733`
- `SetCellUint` in `excelize/cell_test.go:210`
- `SetCellUint` in `excelize/cell_test.go:212`

**MoonBit calls (tests/docs)**
- `xlsx/cell_value_test.mbt:74`

## `set_cell_value`

**Excelize defs**
- `SetCellValue` in `excelize/cell.go`

**Excelize tests**
- `SetCellValue` in `excelize/adjust_test.go:1087`
- `SetCellValue` in `excelize/adjust_test.go:1088`
- `SetCellValue` in `excelize/calc_test.go:19`
- (more: 161 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/calc_test.mbt:5`
- `xlsx/calc_test.mbt:6`
- `xlsx/calc_test.mbt:7`
- (more: 526 additional hits)

## `set_col_outline_level`

**Excelize defs**
- `SetColOutlineLevel` in `excelize/col.go`

**Excelize tests**
- `SetColOutlineLevel` in `excelize/col_test.go:271`
- `SetColOutlineLevel` in `excelize/col_test.go:290`
- `SetColOutlineLevel` in `excelize/col_test.go:292`
- (more: 9 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/row_col_dimensions_test.mbt:12`
- `xlsx/row_col_dimensions_test.mbt:33`
- `xlsx/stream_test.mbt:60`

## `set_col_style`

**Excelize defs**
- `SetColStyle` in `excelize/col.go`

**Excelize tests**
- `SetColStyle` in `excelize/cell_test.go:77`
- `SetColStyle` in `excelize/cell_test.go:257`
- `SetColStyle` in `excelize/chart_test.go:373`
- (more: 20 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/row_col_dimensions_test.mbt:13`
- `xlsx/stream_test.mbt:59`

## `set_col_visible`

**Excelize defs**
- `SetColVisible` in `excelize/col.go`

**Excelize tests**
- `SetColVisible` in `excelize/cell_test.go:89`
- `SetColVisible` in `excelize/col_test.go:203`
- `SetColVisible` in `excelize/col_test.go:204`
- (more: 14 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:120`
- `xlsx/row_col_dimensions_test.mbt:11`
- `xlsx/row_col_dimensions_test.mbt:32`
- (more: 1 additional hits)

## `set_col_width`

**Excelize defs**
- `SetColWidth` in `excelize/col.go`

**Excelize tests**
- `SetColWidth` in `excelize/adjust_test.go:386`
- `SetColWidth` in `excelize/adjust_test.go:438`
- `SetColWidth` in `excelize/adjust_test.go:458`
- (more: 19 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/picture_ops_test.mbt:418`
- `xlsx/picture_ops_test.mbt:435`
- `xlsx/row_col_dimensions_test.mbt:10`
- (more: 3 additional hits)

## `set_conditional_format`

**Excelize defs**
- `SetConditionalFormat` in `excelize/styles.go`

**Excelize tests**
- `SetConditionalFormat` in `excelize/adjust_test.go:1008`
- `SetConditionalFormat` in `excelize/adjust_test.go:1033`
- `SetConditionalFormat` in `excelize/adjust_test.go:1034`
- (more: 40 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:332`
- `xlsx/conditional_format_test.mbt:8`
- `xlsx/conditional_format_test.mbt:43`
- (more: 13 additional hits)

## `set_custom_props`

**Excelize defs**
- `SetCustomProps` in `excelize/docProps.go`

**Excelize tests**
- `SetCustomProps` in `excelize/docProps_test.go:134`
- `SetCustomProps` in `excelize/docProps_test.go:141`
- `SetCustomProps` in `excelize/docProps_test.go:148`
- (more: 4 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:412`
- `mbtexcel_e2e_test.mbt:418`
- `xlsx/doc_props_test.mbt:52`
- (more: 6 additional hits)

## `set_default_font`

**Excelize defs**
- `SetDefaultFont` in `excelize/styles.go`

**Excelize tests**
- `SetDefaultFont` in `excelize/styles_test.go:617`
- `SetDefaultFont` in `excelize/styles_test.go:627`

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:535`
- `xlsx/style_test.mbt:126`

## `set_defined_name`

**Excelize defs**
- `SetDefinedName` in `excelize/sheet.go`

**Excelize tests**
- `SetDefinedName` in `excelize/adjust_test.go:599`
- `SetDefinedName` in `excelize/adjust_test.go:1293`
- `SetDefinedName` in `excelize/adjust_test.go:1316`
- (more: 21 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:277`
- `xlsx/calc_test.mbt:4803`
- `xlsx/calc_test.mbt:4804`
- (more: 6 additional hits)

## `set_doc_props`

**Excelize defs**
- `SetDocProps` in `excelize/docProps.go`

**Excelize tests**
- `SetDocProps` in `excelize/docProps_test.go:76`
- `SetDocProps` in `excelize/docProps_test.go:94`
- `SetDocProps` in `excelize/docProps_test.go:100`

**MoonBit calls (tests/docs)**
- `xlsx/doc_props_test.mbt:97`

## `set_header_footer`

**Excelize defs**
- `SetHeaderFooter` in `excelize/sheet.go`

**Excelize tests**
- `SetHeaderFooter` in `excelize/sheet_test.go:255`
- `SetHeaderFooter` in `excelize/sheet_test.go:257`
- `SetHeaderFooter` in `excelize/sheet_test.go:259`
- (more: 5 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:183`
- `xlsx/header_footer_image_test.mbt:5`
- `xlsx/sheet_props_test.mbt:69`
- (more: 2 additional hits)

## `set_page_layout`

**Excelize defs**
- `SetPageLayout` in `excelize/sheet.go`

**Excelize tests**
- `SetPageLayout` in `excelize/sheet_test.go:201`
- `SetPageLayout` in `excelize/sheet_test.go:215`
- `SetPageLayout` in `excelize/sheet_test.go:220`
- (more: 4 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:470`
- `xlsx/sheet_props_test.mbt:18`
- `xlsx/sheet_props_test.mbt:47`
- (more: 1 additional hits)

## `set_page_margins`

**Excelize defs**
- `SetPageMargins` in `excelize/sheetpr.go`

**Excelize tests**
- `SetPageMargins` in `excelize/sheetpr_test.go:11`
- `SetPageMargins` in `excelize/sheetpr_test.go:26`
- `SetPageMargins` in `excelize/sheetpr_test.go:31`
- (more: 1 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:469`
- `xlsx/sheet_props_test.mbt:12`

## `set_panes`

**Excelize defs**
- `SetPanes` in `excelize/sheet.go`

**Excelize tests**
- `SetPanes` in `excelize/sheet_test.go:44`
- `SetPanes` in `excelize/sheet_test.go:59`
- `SetPanes` in `excelize/sheet_test.go:66`
- (more: 8 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:506`
- `xlsx/sheet_view_test.mbt:80`
- `xlsx/sheet_view_test.mbt:146`
- (more: 2 additional hits)

## `set_row_height`

**Excelize defs**
- `SetRowHeight` in `excelize/rows.go`

**Excelize tests**
- `SetRowHeight` in `excelize/cell_test.go:933`
- `SetRowHeight` in `excelize/picture_test.go:69`
- `SetRowHeight` in `excelize/rows_test.go:156`
- (more: 7 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/duplicate_row_test.mbt:32`
- `xlsx/iterators_test.mbt:6`
- `xlsx/iterators_test.mbt:29`
- (more: 4 additional hits)

## `set_row_outline_level`

**Excelize defs**
- `SetRowOutlineLevel` in `excelize/rows.go`

**Excelize tests**
- `SetRowOutlineLevel` in `excelize/col_test.go:291`
- `SetRowOutlineLevel` in `excelize/col_test.go:293`
- `SetRowOutlineLevel` in `excelize/col_test.go:295`
- (more: 2 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/iterators_test.mbt:31`
- `xlsx/row_col_dimensions_test.mbt:8`
- `xlsx/row_col_dimensions_test.mbt:31`

## `set_row_style`

**Excelize defs**
- `SetRowStyle` in `excelize/rows.go`

**Excelize tests**
- `SetRowStyle` in `excelize/cell_test.go:258`
- `SetRowStyle` in `excelize/rows_test.go:1010`
- `SetRowStyle` in `excelize/rows_test.go:1011`
- (more: 6 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/iterators_test.mbt:32`
- `xlsx/row_col_dimensions_test.mbt:9`

## `set_row_visible`

**Excelize defs**
- `SetRowVisible` in `excelize/rows.go`

**Excelize tests**
- `SetRowVisible` in `excelize/rows_test.go:276`
- `SetRowVisible` in `excelize/rows_test.go:277`
- `SetRowVisible` in `excelize/rows_test.go:284`
- (more: 2 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:119`
- `xlsx/iterators_test.mbt:30`
- `xlsx/row_col_dimensions_test.mbt:7`
- (more: 1 additional hits)

## `set_sheet_background`

**Excelize defs**
- `SetSheetBackground` in `excelize/sheet.go`

**Excelize tests**
- `SetSheetBackground` in `excelize/excelize_test.go:526`
- `SetSheetBackground` in `excelize/excelize_test.go:527`
- `SetSheetBackground` in `excelize/excelize_test.go:536`
- (more: 4 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:221`
- `xlsx/sheet_props_test.mbt:138`

## `set_sheet_background_from_bytes`

**Excelize defs**
- `SetSheetBackgroundFromBytes` in `excelize/sheet.go`

**Excelize tests**
- `SetSheetBackgroundFromBytes` in `excelize/sheet_test.go:749`
- `SetSheetBackgroundFromBytes` in `excelize/sheet_test.go:756`
- `SetSheetBackgroundFromBytes` in `excelize/sheet_test.go:761`

**MoonBit calls (tests/docs)**
- `xlsx/compat_test.mbt:26`

## `set_sheet_col`

**Excelize defs**
- `SetSheetCol` in `excelize/cell.go`

**Excelize tests**
- `SetSheetCol` in `excelize/calc_test.go:6747`
- `SetSheetCol` in `excelize/excelize_test.go:1315`
- `SetSheetCol` in `excelize/excelize_test.go:1317`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/compat_test.mbt:6`

## `set_sheet_dimension`

**Excelize defs**
- `SetSheetDimension` in `excelize/sheet.go`

**Excelize tests**
- `SetSheetDimension` in `excelize/sheet_test.go:797`
- `SetSheetDimension` in `excelize/sheet_test.go:804`
- `SetSheetDimension` in `excelize/sheet_test.go:828`

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:507`
- `xlsx/sheet_view_test.mbt:98`
- `xlsx/sheet_view_test.mbt:113`
- (more: 1 additional hits)

## `set_sheet_name`

**Excelize defs**
- `SetSheetName` in `excelize/sheet.go`

**Excelize tests**
- `SetSheetName` in `excelize/excelize_test.go:79`
- `SetSheetName` in `excelize/sheet_test.go:477`
- `SetSheetName` in `excelize/sheet_test.go:480`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:80`
- `xlsx/sheet_management_test.mbt:6`
- `xlsx/sheet_props_test.mbt:176`

## `set_sheet_props`

**Excelize defs**
- `SetSheetProps` in `excelize/sheetpr.go`

**Excelize tests**
- `SetSheetProps` in `excelize/col_test.go:372`
- `SetSheetProps` in `excelize/excelize_test.go:1538`
- `SetSheetProps` in `excelize/rows_test.go:192`
- (more: 10 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:353`
- `xlsx/sheet_props_test.mbt:240`
- `xlsx/sheet_props_test.mbt:270`

## `set_sheet_row`

**Excelize defs**
- `SetSheetRow` in `excelize/cell.go`

**Excelize tests**
- `SetSheetRow` in `excelize/adjust_test.go:389`
- `SetSheetRow` in `excelize/adjust_test.go:954`
- `SetSheetRow` in `excelize/adjust_test.go:955`
- (more: 33 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/compat_test.mbt:5`

## `set_sheet_view`

**Excelize defs**
- `SetSheetView` in `excelize/sheetview.go`

**Excelize tests**
- `SetSheetView` in `excelize/sheetview_test.go:11`
- `SetSheetView` in `excelize/sheetview_test.go:27`
- `SetSheetView` in `excelize/sheetview_test.go:32`
- (more: 4 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:492`
- `xlsx/sheet_view_test.mbt:17`
- `xlsx/sheet_view_test.mbt:59`
- (more: 1 additional hits)

## `set_sheet_visible`

**Excelize defs**
- `SetSheetVisible` in `excelize/sheet.go`

**Excelize tests**
- `SetSheetVisible` in `excelize/excelize_test.go:1028`
- `SetSheetVisible` in `excelize/excelize_test.go:1029`
- `SetSheetVisible` in `excelize/excelize_test.go:1030`
- (more: 5 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:554`
- `xlsx/sheet_management_test.mbt:69`
- `xlsx/sheet_management_test.mbt:105`

## `set_workbook_props`

**Excelize defs**
- `SetWorkbookProps` in `excelize/workbook.go`

**Excelize tests**
- `SetWorkbookProps` in `excelize/workbook_test.go:11`
- `SetWorkbookProps` in `excelize/workbook_test.go:20`
- `SetWorkbookProps` in `excelize/workbook_test.go:31`

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:369`
- `xlsx/workbook_props_test.mbt:9`

## `set_zip_writer`

**Excelize defs**
- `SetZipWriter` in `excelize/excelize.go`

**Excelize tests**
- `SetZipWriter` in `excelize/file_test.go:48`
- `SetZipWriter` in `excelize/file_test.go:57`
- `SetZipWriter` in `excelize/file_test.go:66`
- (more: 2 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/io_test.mbt:150`

## `split_cell_name`

**Excelize defs**
- `SplitCellName` in `excelize/lib.go`

**Excelize tests**
- `SplitCellName` in `excelize/lib_test.go:115`
- `SplitCellName` in `excelize/lib_test.go:126`

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:3`
- `mbtexcel_e2e_test.mbt:8`
- `xlsx/cell_ref_test.mbt:3`
- (more: 2 additional hits)

## `theme_color`

**Excelize defs**
- `ThemeColor` in `excelize/styles.go`

**Excelize tests**
- `ThemeColor` in `excelize/styles_test.go:678`
- `ThemeColor` in `excelize/styles_test.go:679`
- `ThemeColor` in `excelize/styles_test.go:680`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:107`
- `mbtexcel_test.mbt:108`
- `mbtexcel_test.mbt:109`
- (more: 5 additional hits)

## `ungroup_sheets`

**Excelize defs**
- `UngroupSheets` in `excelize/sheet.go`

**Excelize tests**
- `UngroupSheets` in `excelize/sheet_test.go:371`

**MoonBit calls (tests/docs)**
- `mbtexcel_e2e_test.mbt:737`
- `xlsx/sheet_management_test.mbt:161`

## `unmerge_cell`

**Excelize defs**
- `UnmergeCell` in `excelize/merge.go`

**Excelize tests**
- `UnmergeCell` in `excelize/merge_test.go:180`
- `UnmergeCell` in `excelize/merge_test.go:183`
- `UnmergeCell` in `excelize/merge_test.go:194`
- (more: 5 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/merge_cells_test.mbt:44`

## `unprotect_sheet`

**Excelize defs**
- `UnprotectSheet` in `excelize/sheet.go`

**Excelize tests**
- `UnprotectSheet` in `excelize/excelize_test.go:1411`
- `UnprotectSheet` in `excelize/excelize_test.go:1413`
- `UnprotectSheet` in `excelize/excelize_test.go:1415`
- (more: 6 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:182`
- `xlsx/sheet_props_test.mbt:105`
- `xlsx/sheet_props_test.mbt:113`
- (more: 1 additional hits)

## `unprotect_workbook`

**Excelize defs**
- `UnprotectWorkbook` in `excelize/workbook.go`

**Excelize tests**
- `UnprotectWorkbook` in `excelize/excelize_test.go:1499`
- `UnprotectWorkbook` in `excelize/excelize_test.go:1500`
- `UnprotectWorkbook` in `excelize/excelize_test.go:1507`
- (more: 3 additional hits)

**MoonBit calls (tests/docs)**
- `mbtexcel_test.mbt:168`
- `xlsx/workbook_protection_test.mbt:27`
- `xlsx/workbook_protection_test.mbt:32`

## `unset_conditional_format`

**Excelize defs**
- `UnsetConditionalFormat` in `excelize/styles.go`

**Excelize tests**
- `UnsetConditionalFormat` in `excelize/styles_test.go:300`
- `UnsetConditionalFormat` in `excelize/styles_test.go:310`
- `UnsetConditionalFormat` in `excelize/styles_test.go:342`
- (more: 10 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/conditional_format_test.mbt:21`
- `xlsx/conditional_format_test.mbt:24`

## `update_linked_value`

**Excelize defs**
- `UpdateLinkedValue` in `excelize/excelize.go`

**Excelize tests**
- `UpdateLinkedValue` in `excelize/chart_test.go:485`
- `UpdateLinkedValue` in `excelize/excelize_test.go:56`
- `UpdateLinkedValue` in `excelize/excelize_test.go:1577`
- (more: 2 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/compat_test.mbt:56`

## `write`

**Excelize defs**
- `Write` in `excelize/file.go`

**Excelize tests**
- `Write` in `excelize/chart_test.go:61`
- `Write` in `excelize/chart_test.go:592`
- `Write` in `excelize/chart_test.go:594`
- (more: 10 additional hits)

**MoonBit calls (tests/docs)**
- `README.mbt.md:14`
- `mbtexcel_e2e_test.mbt:35`
- `mbtexcel_e2e_test.mbt:40`
- (more: 210 additional hits)

## `write_to`

**Excelize defs**
- `WriteTo` in `excelize/file.go`

**Excelize tests**
- `WriteTo` in `excelize/excelize_test.go:362`
- `WriteTo` in `excelize/file_test.go:50`
- `WriteTo` in `excelize/file_test.go:60`
- (more: 4 additional hits)

**MoonBit calls (tests/docs)**
- `xlsx/io_test.mbt:179`

## `write_to_buffer`

**Excelize defs**
- `WriteToBuffer` in `excelize/file.go`

**Excelize tests**
- `WriteToBuffer` in `excelize/file_test.go:45`
- `WriteToBuffer` in `excelize/file_test.go:152`
- `WriteToBuffer` in `excelize/file_test.go:170`

**MoonBit calls (tests/docs)**
- `xlsx/io_password_test.mbt:31`
- `xlsx/io_test.mbt:105`
- `xlsx/io_test.mbt:122`
- (more: 3 additional hits)
