///|
let formula_error_div = "#DIV/0!"

///|
let formula_error_name = "#NAME?"

///|
let formula_error_null = "#NULL!"

///|
let formula_error_na = "#N/A"

///|
let formula_error_value = "#VALUE!"

///|
let formula_error_ref = "#REF!"

///|
let formula_error_num = "#NUM!"

///|
let formula_error_spill = "#SPILL!"

///|
let formula_error_getting_data = "#GETTING_DATA"

///|
let formula_error_calc = "#CALC!"

///|
let excel_max_rows = 1048576

///|
let excel_max_cols = 16384

///|
let max_range_cells = 10000

///|
let max_financial_iterations = 128

///|
let financial_precision = 1.0e-8

///|
let rate_max_iterations = 100

///|
let rate_precision = 1.0e-6

///|
let xirr_max_iterations = 50

///|
let xirr_precision = 1.0e-10

///|
let category_weight_and_mass = 0

///|
let category_distance = 1

///|
let category_time = 2

///|
let category_pressure = 3

///|
let category_force = 4

///|
let category_energy = 5

///|
let category_power = 6

///|
let category_magnetism = 7

///|
let category_temperature = 8

///|
let category_volume_and_liquid_measure = 9

///|
let category_area = 10

///|
let category_information = 11

///|
let category_speed = 12

///|
let rand_state : @random.Rand = @random.Rand::new()

///|
priv enum FormulaValue {
  Number(Double)
  String(String)
  Bool(Bool)
  Error(String)
  Empty
  List(Array[FormulaValue])
}

///|
priv enum UnaryOp {
  Plus
  Minus
  Percent
}

///|
priv enum BinaryOp {
  Add
  Sub
  Mul
  Div
  Pow
  Concat
  Eq
  Ne
  Lt
  Le
  Gt
  Ge
}

///|
priv enum Expr {
  Number(Double)
  String(String)
  Bool(Bool)
  Cell(String, String)
  Range(String, String, String)
  Unary(UnaryOp, Expr)
  Binary(BinaryOp, Expr, Expr)
  FuncCall(String, Array[Expr])
  List(Array[Expr])
}

///|
priv enum FormulaCriteriaType {
  Unset
  Eq
  Ne
  Le
  Ge
  Lt
  Gt
  Regexp
}

///|
priv struct FormulaCriteria {
  kind : FormulaCriteriaType
  condition : FormulaValue
}

///|
priv struct CalcContext {
  visiting : Map[String, Bool]
  mut depth : Int
  max_depth : Int
  mut current_sheet : String
  mut current_ref : String
}

///|
priv struct RangeValues {
  values : Array[FormulaValue]
  rows : Int
  cols : Int
}

///|
priv struct RomanNumeral {
  n : Double
  s : String
}

///|
priv struct CellIndex {
  row : Int
  col : Int
}
