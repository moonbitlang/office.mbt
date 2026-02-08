///|
fn median_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let numbers : Array[Double] = []
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      Error(err) => return Error(err)
      Number(num) => numbers.push(num)
      Bool(flag) => numbers.push(if flag { 1.0 } else { 0.0 })
      String(text) =>
        match parse_double_opt(text) {
          Some(num) => numbers.push(num)
          None => return Error(formula_error_value)
        }
      Empty => ()
      List(_) => ()
    }
  }
  if numbers.length() == 0 {
    return Error(formula_error_num)
  }
  numbers.sort()
  let count = numbers.length()
  if count % 2 == 0 {
    let left = numbers[count / 2 - 1]
    let right = numbers[count / 2]
    Number((left + right) / 2.0)
  } else {
    Number(numbers[count / 2])
  }
}

///|
fn list_from_value(value : FormulaValue) -> Array[FormulaValue] {
  match value {
    List(list) => list
    _ => [value]
  }
}

///|
fn index_of_double(values : ArrayView[Double], target : Double) -> Int {
  for i in 0..<values.length() {
    if values[i] == target {
      return i
    }
  }
  -1
}

///|
fn avedev_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let avg_value = average_values(values)
  let avg = match avg_value {
    Number(num) => num
    _ => return Error(formula_error_value)
  }
  let mut sum = 0.0
  let mut count = 0
  for value in values {
    match value {
      List(list) =>
        for cell in list {
          match value_as_number(cell) {
            Ok(num) => {
              sum = sum + Double::abs(num - avg)
              count = count + 1
            }
            Err(_) => return Error(formula_error_value)
          }
        }
      _ =>
        match value_as_number(value) {
          Ok(num) => {
            sum = sum + Double::abs(num - avg)
            count = count + 1
          }
          Err(_) => return Error(formula_error_value)
        }
    }
  }
  if count == 0 {
    Error(formula_error_value)
  } else {
    Number(round_significant_digits(sum / Double::from_int(count), 15))
  }
}

///|
fn devsq_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let numbers : Array[Double] = []
  for value in values {
    match value {
      List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            Number(num) => numbers.push(num)
            _ => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          Number(num) => numbers.push(num)
          _ => ()
        }
    }
  }
  if numbers.length() == 0 {
    return Error(formula_error_na)
  }
  let mut sum = 0.0
  for num in numbers {
    sum = sum + num
  }
  let mean = sum / Double::from_int(numbers.length())
  let mut total = 0.0
  for num in numbers {
    let delta = num - mean
    total = total + delta * delta
  }
  Number(round_significant_digits(total, 15))
}

///|
fn geomean_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut product = 1.0
  let mut count = 0
  for value in values {
    match value {
      List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            Number(num) => {
              if num <= 0.0 {
                return Error(formula_error_num)
              }
              product = product * num
              count = count + 1
            }
            Error(err) => return Error(err)
            _ => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          Number(num) => {
            if num <= 0.0 {
              return Error(formula_error_num)
            }
            product = product * num
            count = count + 1
          }
          Bool(flag) => {
            let num = if flag { 1.0 } else { 0.0 }
            if num <= 0.0 {
              return Error(formula_error_num)
            }
            product = product * num
            count = count + 1
          }
          String(text) =>
            match parse_double_opt(text) {
              Some(num) => {
                if num <= 0.0 {
                  return Error(formula_error_num)
                }
                product = product * num
                count = count + 1
              }
              None => return Error(formula_error_value)
            }
          Error(err) => return Error(err)
          Empty => ()
          List(_) => ()
        }
    }
  }
  if count == 0 {
    return Error(formula_error_num)
  }
  let result = @math.pow(product, 1.0 / Double::from_int(count))
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn harmean_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut total = 0.0
  let mut count = 0
  for value in values {
    match value {
      List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            Number(num) => {
              if num <= 0.0 {
                return Error(formula_error_na)
              }
              total = total + 1.0 / num
              count = count + 1
            }
            Error(err) => return Error(err)
            _ => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          Number(num) => {
            if num <= 0.0 {
              return Error(formula_error_na)
            }
            total = total + 1.0 / num
            count = count + 1
          }
          Bool(flag) => {
            let num = if flag { 1.0 } else { 0.0 }
            if num <= 0.0 {
              return Error(formula_error_na)
            }
            total = total + 1.0 / num
            count = count + 1
          }
          String(text) =>
            match parse_double_opt(text) {
              Some(num) => {
                if num <= 0.0 {
                  return Error(formula_error_na)
                }
                total = total + 1.0 / num
                count = count + 1
              }
              None => ()
            }
          Error(err) => return Error(err)
          Empty => ()
          List(_) => ()
        }
    }
  }
  if count == 0 {
    return Error(formula_error_na)
  }
  let result = 1.0 / (total / Double::from_int(count))
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn kurt_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let numbers : Array[Double] = []
  for value in values {
    match value {
      List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            Number(num) => numbers.push(num)
            String(text) =>
              match parse_double_opt(text) {
                Some(num) => numbers.push(num)
                None => ()
              }
            Bool(flag) => numbers.push(if flag { 1.0 } else { 0.0 })
            _ => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          Number(num) => numbers.push(num)
          String(text) =>
            match parse_double_opt(text) {
              Some(num) => numbers.push(num)
              None => ()
            }
          Bool(flag) => numbers.push(if flag { 1.0 } else { 0.0 })
          _ => ()
        }
    }
  }
  if numbers.length() < 4 {
    return Error(formula_error_div)
  }
  let mut sum_numbers = 0.0
  for num in numbers {
    sum_numbers = sum_numbers + num
  }
  let count = Double::from_int(numbers.length())
  let mean = sum_numbers / count
  let stdev = match sample_stdev(numbers) {
    Some(num) => num
    None => return Error(formula_error_div)
  }
  if stdev <= 0.0 {
    return Error(formula_error_div)
  }
  let mut sum = 0.0
  for num in numbers {
    let scaled = (num - mean) / stdev
    sum = sum + scaled * scaled * scaled * scaled
  }
  let term1 = sum *
    (count * (count + 1.0) / ((count - 1.0) * (count - 2.0) * (count - 3.0)))
  let term2 = 3.0 *
    @math.pow(count - 1.0, 2.0) /
    ((count - 2.0) * (count - 3.0))
  number_or_num_error(round_significant_digits(term1 - term2, 15))
}

///|
fn skew_values(name : String, values : ArrayView[FormulaValue]) -> FormulaValue {
  let numbers : Array[Double] = []
  for value in values {
    match value {
      List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            Error(err) => return Error(err)
            Number(num) => numbers.push(num)
            _ => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          Number(num) => numbers.push(num)
          String(text) =>
            match parse_double_opt(text) {
              Some(num) => numbers.push(num)
              None => return Error(formula_error_value)
            }
          Bool(flag) => numbers.push(if flag { 1.0 } else { 0.0 })
          Error(err) => return Error(err)
          Empty => ()
          List(_) => ()
        }
    }
  }
  if numbers.length() <= 2 {
    return Error(formula_error_div)
  }
  let mut sum = 0.0
  for num in numbers {
    sum = sum + num
  }
  let count = Double::from_int(numbers.length())
  let mean = sum / count
  let stdev = if name == "SKEW" {
    match sample_stdev(numbers) {
      Some(num) => num
      None => return Error(formula_error_div)
    }
  } else {
    let mut sum_sq = 0.0
    for num in numbers {
      let delta = num - mean
      sum_sq = sum_sq + delta * delta
    }
    @math.pow(sum_sq / count, 0.5)
  }
  if stdev <= 0.0 {
    return Error(formula_error_div)
  }
  let mut sum_scaled = 0.0
  for num in numbers {
    let scaled = (num - mean) / stdev
    sum_scaled = sum_scaled + scaled * scaled * scaled
  }
  let result = if name == "SKEW" {
    sum_scaled * (count / ((count - 1.0) * (count - 2.0)))
  } else {
    sum_scaled / count
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn standardize_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let stddev = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if stddev <= 0.0 {
    return Error(formula_error_na)
  }
  let result = (x - mean) / stddev
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn kth_values(
  name : String,
  array_value : FormulaValue,
  k_value : FormulaValue,
) -> FormulaValue {
  let k_raw = match value_as_number(k_value) {
    Ok(num) => num
    Err(err) => return err
  }
  let k = k_raw.to_int()
  if k < 1 {
    return Error(formula_error_num)
  }
  let values = list_from_value(array_value)
  let numbers : Array[Double] = []
  for value in values {
    match normalize_scalar(value) {
      Number(num) => numbers.push(num)
      _ => ()
    }
  }
  if numbers.length() < k {
    return Error(formula_error_num)
  }
  numbers.sort()
  let result = if name == "LARGE" {
    numbers[numbers.length() - k]
  } else {
    numbers[k - 1]
  }
  Number(result)
}

///|
fn mode_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let numbers : Array[Double] = []
  for value in values {
    match value {
      List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            Number(num) => numbers.push(num)
            Bool(flag) => numbers.push(if flag { 1.0 } else { 0.0 })
            _ => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          Number(num) => numbers.push(num)
          Bool(flag) => numbers.push(if flag { 1.0 } else { 0.0 })
          Error(err) => return Error(err)
          _ => return Error(formula_error_value)
        }
    }
  }
  if numbers.length() == 0 {
    return Error(formula_error_na)
  }
  numbers.sort()
  let mut mode_count = 0
  let mut mode = 0.0
  for i in 0..<numbers.length() {
    let mut count = 0
    for j in 0..<numbers.length() {
      if i != j && numbers[j] == numbers[i] {
        count = count + 1
      }
    }
    if count > mode_count {
      mode_count = count
      mode = numbers[i]
    }
  }
  if mode_count == 0 {
    Error(formula_error_na)
  } else {
    Number(mode)
  }
}

///|
fn mode_mult_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let numbers : Array[Double] = []
  for value in values {
    match value {
      List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            Number(num) => numbers.push(num)
            Bool(flag) => numbers.push(if flag { 1.0 } else { 0.0 })
            _ => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          Number(num) => numbers.push(num)
          Bool(flag) => numbers.push(if flag { 1.0 } else { 0.0 })
          Error(err) => return Error(err)
          _ => return Error(formula_error_value)
        }
    }
  }
  if numbers.length() == 0 {
    return Error(formula_error_na)
  }
  numbers.sort()
  let mut mode_count = 0
  let mut modes : Array[FormulaValue] = []
  for i in 0..<numbers.length() {
    let mut count = 0
    for j in (i + 1)..<numbers.length() {
      if numbers[i] == numbers[j] {
        count = count + 1
      }
    }
    if count > mode_count {
      mode_count = count
      modes = [Number(numbers[i])]
    } else if count == mode_count {
      modes.push(Number(numbers[i]))
    }
  }
  if mode_count == 0 {
    Error(formula_error_na)
  } else {
    List(modes)
  }
}

///|
fn percentile_values(
  array_value : FormulaValue,
  k : Double,
  exclusive : Bool,
  error_on_error : Bool,
) -> FormulaValue {
  let values = list_from_value(array_value)
  let numbers : Array[Double] = []
  for value in values {
    match normalize_scalar(value) {
      Error(err) =>
        return if error_on_error {
          Error(formula_error_num)
        } else {
          Error(err)
        }
      Number(num) => numbers.push(num)
      _ => ()
    }
  }
  if numbers.length() == 0 {
    return Error(formula_error_num)
  }
  numbers.sort()
  let count = numbers.length()
  if exclusive {
    let idx = k * Double::from_int(count + 1)
    let base = @math.floor(idx)
    let base_index = base.to_int()
    let next_index = base_index - 1
    if next_index < 0 || base_index >= count {
      return Error(formula_error_num)
    }
    let proportion = idx - base
    let result = numbers[next_index] +
      (numbers[base_index] - numbers[next_index]) * proportion
    return Number(round_significant_digits(result, 15))
  }
  let idx = k * Double::from_int(count - 1)
  let base = @math.floor(idx)
  if idx == base {
    return Number(numbers[base.to_int()])
  }
  let base_index = base.to_int()
  let next_index = base_index + 1
  let proportion = idx - base
  let result = numbers[base_index] +
    (numbers[next_index] - numbers[base_index]) * proportion
  Number(round_significant_digits(result, 15))
}

///|
fn percentrank_values(
  name : String,
  array_value : FormulaValue,
  x : Double,
  significance : Double,
) -> FormulaValue {
  if significance < 1.0 {
    return Error(formula_error_num)
  }
  let values = list_from_value(array_value)
  let numbers : Array[Double] = []
  for value in values {
    match normalize_scalar(value) {
      Error(_) => return Error(formula_error_na)
      Number(num) => numbers.push(num)
      _ => ()
    }
  }
  if numbers.length() == 0 {
    return Error(formula_error_na)
  }
  numbers.sort()
  let count = numbers.length()
  if x < numbers[0] || x > numbers[count - 1] {
    return Error(formula_error_na)
  }
  let mut pos = Double::from_int(index_of_double(numbers, x))
  if pos < 0.0 {
    let mut idx = 0.0
    let mut cmp = numbers[0]
    while cmp < x {
      idx = idx + 1.0
      cmp = numbers[idx.to_int()]
    }
    idx = idx - 1.0
    pos = idx + (x - numbers[idx.to_int()]) / (cmp - numbers[idx.to_int()])
  }
  let pow = @math.pow(10.0, significance)
  let digit = if name == "PERCENTRANK.EXC" {
    pow * (pos + 1.0) / (Double::from_int(count) + 1.0)
  } else {
    pow * pos / (Double::from_int(count) - 1.0)
  }
  let result = @math.floor(digit) / pow
  Number(round_significant_digits(result, 15))
}

///|
fn quartile_values(
  name : String,
  array_value : FormulaValue,
  quart : Double,
  exclusive : Bool,
) -> FormulaValue {
  if exclusive {
    if quart <= 0.0 || quart >= 4.0 {
      return Error(formula_error_num)
    }
  } else if quart < 0.0 || quart > 4.0 {
    return Error(formula_error_num)
  }
  let k = quart / 4.0
  let error_on_error = name == "QUARTILE.EXC"
  percentile_values(array_value, k, exclusive, error_on_error)
}

///|
fn rank_values(
  num_value : FormulaValue,
  array_value : FormulaValue,
  order : Double?,
) -> FormulaValue {
  let num = match value_as_number(num_value) {
    Ok(num) => num
    Err(err) => return err
  }
  let values = list_from_value(array_value)
  let numbers : Array[Double] = []
  for value in values {
    match normalize_scalar(value) {
      Number(num) => numbers.push(num)
      _ => ()
    }
  }
  if numbers.length() == 0 {
    return Error(formula_error_na)
  }
  numbers.sort()
  let order_value = match order {
    Some(num) => num
    None => 0.0
  }
  if order_value == 0.0 {
    numbers.rev_in_place()
  }
  let idx = index_of_double(numbers, num)
  if idx < 0 {
    Error(formula_error_na)
  } else {
    Number(Double::from_int(idx + 1))
  }
}

///|
fn sample_stdev(numbers : ArrayView[Double]) -> Double? {
  if numbers.length() < 2 {
    return None
  }
  let mut sum = 0.0
  for num in numbers {
    sum = sum + num
  }
  let mean = sum / Double::from_int(numbers.length())
  let mut sum_sq = 0.0
  for num in numbers {
    let delta = num - mean
    sum_sq = sum_sq + delta * delta
  }
  let denom = Double::from_int(numbers.length() - 1)
  Some(@math.pow(sum_sq / denom, 0.5))
}

///|
fn correl_values(
  left_value : FormulaValue,
  right_value : FormulaValue,
) -> FormulaValue {
  let left = list_from_value(left_value)
  let right = list_from_value(right_value)
  if left.length() != right.length() {
    return Error(formula_error_na)
  }
  let xs : Array[Double] = []
  let ys : Array[Double] = []
  for i in 0..<left.length() {
    let x = sumx_number(left[i])
    let y = sumx_number(right[i])
    if x != 0.0 && y != 0.0 {
      xs.push(x)
      ys.push(y)
    }
  }
  if xs.length() < 2 {
    return Error(formula_error_div)
  }
  let stdev_x = match sample_stdev(xs) {
    Some(num) => num
    None => return Error(formula_error_div)
  }
  let stdev_y = match sample_stdev(ys) {
    Some(num) => num
    None => return Error(formula_error_div)
  }
  if stdev_x == 0.0 || stdev_y == 0.0 {
    return Error(formula_error_div)
  }
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  for num in xs {
    sum_x = sum_x + num
  }
  for num in ys {
    sum_y = sum_y + num
  }
  let mean_x = sum_x / Double::from_int(xs.length())
  let mean_y = sum_y / Double::from_int(ys.length())
  let mut sum = 0.0
  for i in 0..<xs.length() {
    sum = sum + (xs[i] - mean_x) * (ys[i] - mean_y)
  }
  let denom = Double::from_int(xs.length() - 1)
  let result = sum / denom / stdev_x / stdev_y
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn covar_values(
  name : String,
  left_value : FormulaValue,
  right_value : FormulaValue,
) -> FormulaValue {
  let left = list_from_value(left_value)
  let right = list_from_value(right_value)
  if left.length() != right.length() {
    return Error(formula_error_na)
  }
  let mut sum_left = 0.0
  let mut count_left = 0
  for value in left {
    match value_as_number_opt(value) {
      Some(num) => {
        sum_left = sum_left + num
        count_left = count_left + 1
      }
      None => ()
    }
  }
  let mut sum_right = 0.0
  let mut count_right = 0
  for value in right {
    match value_as_number_opt(value) {
      Some(num) => {
        sum_right = sum_right + num
        count_right = count_right + 1
      }
      None => ()
    }
  }
  if count_left == 0 || count_right == 0 {
    return Error(formula_error_div)
  }
  let mean_left = sum_left / Double::from_int(count_left)
  let mean_right = sum_right / Double::from_int(count_right)
  let mut sum = 0.0
  let mut count = 0
  for i in 0..<left.length() {
    match (value_as_number_opt(left[i]), value_as_number_opt(right[i])) {
      (Some(lhs), Some(rhs)) => {
        sum = sum + (lhs - mean_left) * (rhs - mean_right)
        count = count + 1
      }
      _ => ()
    }
  }
  let denom = if name == "COVARIANCE.S" { count - 1 } else { count }
  if denom <= 0 {
    return Error(formula_error_div)
  }
  let result = sum / Double::from_int(denom)
  Number(round_significant_digits(result, 15))
}

///|
fn pearson_product_values(
  name : String,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if values.length() != 2 && values.length() != 3 {
    return Error(formula_error_value)
  }
  let mut array1 = list_from_value(values[values.length() - 1])
  let mut array2 = list_from_value(values[0])
  let mut fx = 0.0
  if values.length() == 3 {
    fx = match value_as_number(values[0]) {
      Ok(num) => num
      Err(err) => return err
    }
    array2 = list_from_value(values[1])
    array1 = list_from_value(values[2])
  }
  if name == "PEARSON" || name == "RSQ" {
    let tmp = array1
    array1 = array2
    array2 = tmp
  }
  if array1.length() != array2.length() {
    return Error(formula_error_na)
  }
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  let mut count = 0
  for i in 0..<array1.length() {
    match (normalize_scalar(array1[i]), normalize_scalar(array2[i])) {
      (Number(x), Number(y)) => {
        sum_x = sum_x + x
        sum_y = sum_y + y
        count = count + 1
      }
      _ => ()
    }
  }
  if count == 0 {
    return Error(formula_error_div)
  }
  let mean_x = sum_x / Double::from_int(count)
  let mean_y = sum_y / Double::from_int(count)
  let mut sum = 0.0
  let mut delta_x = 0.0
  let mut delta_y = 0.0
  for i in 0..<array1.length() {
    match (normalize_scalar(array1[i]), normalize_scalar(array2[i])) {
      (Number(x), Number(y)) => {
        let dx = x - mean_x
        let dy = y - mean_y
        sum = sum + dx * dy
        delta_x = delta_x + dx * dx
        delta_y = delta_y + dy * dy
      }
      _ => ()
    }
  }
  if sum * delta_x * delta_y == 0.0 {
    return Error(formula_error_div)
  }
  let result = match name {
    "FORECAST" | "FORECAST.LINEAR" => mean_y + sum / delta_x * (fx - mean_x)
    "INTERCEPT" => mean_y - sum / delta_x * mean_x
    "PEARSON" => sum / @math.pow(delta_x * delta_y, 0.5)
    "RSQ" => @math.pow(sum / @math.pow(delta_x * delta_y, 0.5), 2.0)
    _ => sum / delta_x
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn steyx_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return Error(formula_error_value)
  }
  let array_x = list_from_value(values[1])
  let array_y = list_from_value(values[0])
  if array_x.length() != array_y.length() {
    return Error(formula_error_na)
  }
  let mut count = 0.0
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  let mut square_x = 0.0
  let mut square_y = 0.0
  let mut sigma_xy = 0.0
  for i in 0..<array_x.length() {
    match (normalize_scalar(array_x[i]), normalize_scalar(array_y[i])) {
      (Number(x), Number(y)) => {
        sum_x = sum_x + x
        sum_y = sum_y + y
        square_x = square_x + x * x
        square_y = square_y + y * y
        sigma_xy = sigma_xy + x * y
        count = count + 1.0
      }
      _ => ()
    }
  }
  if count < 3.0 {
    return Error(formula_error_div)
  }
  let dx = sum_x / count
  let dy = sum_y / count
  let sigma1 = square_y - 2.0 * dy * sum_y + count * dy * dy
  let sigma2 = sigma_xy - dy * sum_x - sum_y * dx + count * dy * dx
  let sigma3 = square_x - 2.0 * dx * sum_x + count * dx * dx
  let result = @math.pow(
    (sigma1 - sigma2 * sigma2 / sigma3) / (count - 2.0),
    0.5,
  )
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn trend_growth_values(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() < 1 {
    return Error(formula_error_value)
  }
  if values.length() > 4 {
    return Error(formula_error_value)
  }
  let know_y_range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let know_y = match number_matrix_from_range(know_y_range, false) {
    Ok(matrix) => matrix
    Err(err) => return err
  }
  let mut know_x : Array[Array[Double]] = []
  if values.length() >= 2 {
    let know_x_range = range_from_expr_or_value(
      workbook,
      sheet_name,
      args[1],
      values[1],
      ctx,
    )
    know_x = match number_matrix_from_range(know_x_range, false) {
      Ok(matrix) => matrix
      Err(err) => return err
    }
  }
  let mut new_x : Array[Array[Double]] = []
  if values.length() >= 3 {
    let new_x_range = range_from_expr_or_value(
      workbook,
      sheet_name,
      args[2],
      values[2],
      ctx,
    )
    let base = match number_matrix_from_range(new_x_range, false) {
      Ok(matrix) => matrix
      Err(err) => return err
    }
    new_x = transpose_number_matrix(base)
  }
  let mut constant = true
  if values.length() == 4 {
    constant = match value_as_bool(values[3]) {
      Ok(flag) => flag
      Err(err) => return err
    }
  }
  let is_growth = name == "GROWTH"
  let result = match
    calc_trend_growth(know_y, know_x, new_x, constant, is_growth) {
    Ok(matrix) => matrix
    Err(err) => return err
  }
  for col in 0..<result.length() {
    for row in 0..<result[col].length() {
      result[col][row] = round_significant_digits(result[col][row], 15)
    }
  }
  List(matrix_values(result))
}

///|
fn min_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut min = None
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      Error(err) => return Error(err)
      Number(num) =>
        min = Some(
          match min {
            Some(current) => if num < current { num } else { current }
            None => num
          },
        )
      Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        min = Some(
          match min {
            Some(current) => if num < current { num } else { current }
            None => num
          },
        )
      }
      String(text) =>
        if text == "TRUE" || text == "FALSE" {
          ()
        } else {
          match parse_double_opt(text) {
            Some(num) =>
              min = Some(
                match min {
                  Some(current) => if num < current { num } else { current }
                  None => num
                },
              )
            None => ()
          }
        }
      Empty => ()
      List(_) => ()
    }
  }
  match min {
    Some(value) => Number(value)
    None => Number(0.0)
  }
}

///|
fn mina_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut min : Double? = None
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      Error(err) => return Error(err)
      Number(num) =>
        min = Some(
          match min {
            Some(current) => if num < current { num } else { current }
            None => num
          },
        )
      Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        min = Some(
          match min {
            Some(current) => if num < current { num } else { current }
            None => num
          },
        )
      }
      String(text) =>
        if text == "" {
          ()
        } else if text == "TRUE" || text == "FALSE" {
          let num = if text == "TRUE" { 1.0 } else { 0.0 }
          min = Some(
            match min {
              Some(current) => if num < current { num } else { current }
              None => num
            },
          )
        } else {
          match parse_double_opt(text) {
            Some(num) =>
              min = Some(
                match min {
                  Some(current) => if num < current { num } else { current }
                  None => num
                },
              )
            None => ()
          }
        }
      Empty => ()
      List(_) => ()
    }
  }
  match min {
    Some(value) => Number(value)
    None => Number(0.0)
  }
}

///|
fn max_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut max = None
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      Error(err) => return Error(err)
      Number(num) =>
        max = Some(
          match max {
            Some(current) => if num > current { num } else { current }
            None => num
          },
        )
      Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        max = Some(
          match max {
            Some(current) => if num > current { num } else { current }
            None => num
          },
        )
      }
      String(text) =>
        if text == "TRUE" || text == "FALSE" {
          ()
        } else {
          match parse_double_opt(text) {
            Some(num) =>
              max = Some(
                match max {
                  Some(current) => if num > current { num } else { current }
                  None => num
                },
              )
            None => ()
          }
        }
      Empty => ()
      List(_) => ()
    }
  }
  match max {
    Some(value) => Number(value)
    None => Number(0.0)
  }
}

///|
fn maxa_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut max : Double? = None
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      Error(err) => return Error(err)
      Number(num) =>
        max = Some(
          match max {
            Some(current) => if num > current { num } else { current }
            None => num
          },
        )
      Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        max = Some(
          match max {
            Some(current) => if num > current { num } else { current }
            None => num
          },
        )
      }
      String(text) =>
        if text == "" {
          ()
        } else if text == "TRUE" || text == "FALSE" {
          let num = if text == "TRUE" { 1.0 } else { 0.0 }
          max = Some(
            match max {
              Some(current) => if num > current { num } else { current }
              None => num
            },
          )
        } else {
          match parse_double_opt(text) {
            Some(num) =>
              max = Some(
                match max {
                  Some(current) => if num > current { num } else { current }
                  None => num
                },
              )
            None => ()
          }
        }
      Empty => ()
      List(_) => ()
    }
  }
  match max {
    Some(value) => Number(value)
    None => Number(0.0)
  }
}

///|
fn count_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut count = 0
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      Error(err) => return Error(err)
      Number(_) => count = count + 1
      Bool(_) => count = count + 1
      String(text) =>
        match parse_double_opt(text) {
          Some(_) => count = count + 1
          None => ()
        }
      Empty => ()
      List(_) => ()
    }
  }
  Number(Double::from_int(count))
}

///|
fn counta_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut count = 0
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      Number(_) => count = count + 1
      Bool(_) => count = count + 1
      String(text) => if text != "" { count = count + 1 }
      Error(_) => ()
      Empty => ()
      List(_) => ()
    }
  }
  Number(Double::from_int(count))
}

///|
fn subtotal_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 2 {
    return Error(formula_error_value)
  }
  let function_num = match value_as_number(values[0]) {
    Ok(num) => Double::to_int(trunc_double(num))
    Err(err) => return err
  }
  let sub_values : Array[FormulaValue] = []
  for i in 1..<values.length() {
    sub_values.push(values[i])
  }
  match function_num {
    1 | 101 => average_values(sub_values)
    2 | 102 => count_values(sub_values)
    3 | 103 => counta_values(sub_values)
    4 | 104 => max_values(sub_values)
    5 | 105 => min_values(sub_values)
    6 | 106 => product_values(sub_values)
    7 | 107 => stdev_values(false, sub_values)
    8 | 108 =>
      match variance_values(sub_values, false, false) {
        Number(variance) => {
          let result = @math.pow(variance, 0.5)
          Number(round_significant_digits(result, 15))
        }
        Error(err) => Error(err)
        _ => Error(formula_error_value)
      }
    9 | 109 => sum_values(sub_values)
    10 | 110 => variance_values(sub_values, true, false)
    11 | 111 => variance_values(sub_values, false, false)
    _ => Error(formula_error_value)
  }
}

///|
fn aggregate_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return Error(formula_error_value)
  }
  let func_num = match value_as_int(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let opts = match value_as_int(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if opts < 0 || opts > 7 {
    return Error(formula_error_value)
  }
  let args_values = values[2:]
  match func_num {
    1 => average_values(args_values)
    2 => count_values(args_values)
    3 => counta_values(args_values)
    4 => max_values(args_values)
    5 => min_values(args_values)
    6 => product_values(args_values)
    7 =>
      if args_values.length() >= 1 {
        stdev_values(false, args_values)
      } else {
        Error(formula_error_value)
      }
    8 =>
      if args_values.length() >= 1 {
        match variance_values(args_values, false, false) {
          Number(variance) => {
            let result = @math.pow(variance, 0.5)
            Number(round_significant_digits(result, 15))
          }
          Error(err) => Error(err)
          _ => Error(formula_error_value)
        }
      } else {
        Error(formula_error_value)
      }
    9 => sum_values(args_values)
    10 =>
      if args_values.length() >= 1 {
        variance_values(args_values, true, false)
      } else {
        Error(formula_error_value)
      }
    11 =>
      if args_values.length() >= 1 {
        variance_values(args_values, false, false)
      } else {
        Error(formula_error_value)
      }
    12 =>
      if args_values.length() >= 1 {
        median_values(args_values)
      } else {
        Error(formula_error_value)
      }
    13 =>
      if args_values.length() >= 1 {
        mode_values(args_values)
      } else {
        Error(formula_error_value)
      }
    14 =>
      if args_values.length() == 2 {
        kth_values("LARGE", args_values[0], args_values[1])
      } else {
        Error(formula_error_value)
      }
    15 =>
      if args_values.length() == 2 {
        kth_values("SMALL", args_values[0], args_values[1])
      } else {
        Error(formula_error_value)
      }
    16 =>
      if args_values.length() == 2 {
        match value_as_number(args_values[1]) {
          Ok(k) => percentile_values(args_values[0], k, false, false)
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    17 =>
      if args_values.length() == 2 {
        match value_as_number(args_values[1]) {
          Ok(quart) =>
            quartile_values("QUARTILE.INC", args_values[0], quart, false)
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    18 =>
      if args_values.length() == 2 {
        match value_as_number(args_values[1]) {
          Ok(k) => percentile_values(args_values[0], k, true, false)
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    19 =>
      if args_values.length() == 2 {
        match value_as_number(args_values[1]) {
          Ok(quart) =>
            quartile_values("QUARTILE.EXC", args_values[0], quart, true)
          Err(err) => err
        }
      } else {
        Error(formula_error_value)
      }
    _ => Error(formula_error_value)
  }
}

///|
fn sumproduct_scalars(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut product = 1.0
  for value in values {
    match normalize_scalar(value) {
      Error(err) => return Error(err)
      Number(num) => product = product * num
      Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        product = product * num
      }
      String(text) =>
        match parse_double_opt(text) {
          Some(num) => product = product * num
          None => return Error(formula_error_value)
        }
      Empty => ()
      List(_) => return Error(formula_error_value)
    }
  }
  Number(product)
}

///|
fn sumproduct_number(value : FormulaValue) -> Result[Double, FormulaValue] {
  match normalize_scalar(value) {
    Error(err) => Err(Error(err))
    Number(num) => Ok(num)
    Bool(flag) => Ok(if flag { 1.0 } else { 0.0 })
    String(text) =>
      if text == "" {
        Ok(0.0)
      } else {
        match parse_double_opt(text) {
          Some(num) => Ok(num)
          None => Err(Error(formula_error_value))
        }
      }
    Empty => Ok(0.0)
    List(_) => Err(Error(formula_error_value))
  }
}

///|
fn sumproduct_values(ranges : Array[RangeValues]) -> FormulaValue {
  if ranges.length() == 0 {
    return Error(formula_error_value)
  }
  let base = ranges[0]
  for range in ranges {
    if range.rows != base.rows || range.cols != base.cols {
      return Error(formula_error_value)
    }
  }
  let mut sum = 0.0
  let count = base.rows * base.cols
  for idx in 0..<count {
    let mut product = 1.0
    for range in ranges {
      match sumproduct_number(range.values[idx]) {
        Ok(num) => product = product * num
        Err(err) => return err
      }
    }
    sum = sum + product
  }
  Number(sum)
}

///|
fn sumx_number(value : FormulaValue) -> Double {
  match normalize_scalar(value) {
    Number(num) => num
    Bool(flag) => if flag { 1.0 } else { 0.0 }
    String(text) =>
      match parse_double_opt(text) {
        Some(num) => num
        None => 0.0
      }
    Empty => 0.0
    Error(_) => 0.0
    List(_) => 0.0
  }
}

///|
fn sumx_values(
  name : String,
  left : RangeValues,
  right : RangeValues,
) -> FormulaValue {
  if left.rows != right.rows || left.cols != right.cols {
    return Error(formula_error_na)
  }
  let mut sum = 0.0
  let count = left.rows * left.cols
  for idx in 0..<count {
    let lhs = sumx_number(left.values[idx])
    let rhs = sumx_number(right.values[idx])
    if lhs != 0.0 && rhs != 0.0 {
      let term = match name {
        "SUMX2MY2" => lhs * lhs - rhs * rhs
        "SUMX2PY2" => lhs * lhs + rhs * rhs
        _ => (lhs - rhs) * (lhs - rhs)
      }
      sum = sum + term
    }
  }
  Number(sum)
}

///|
fn error_type_value(value : FormulaValue) -> FormulaValue {
  match normalize_scalar(value) {
    Error(err) =>
      if err == formula_error_null {
        Number(1.0)
      } else if err == formula_error_div {
        Number(2.0)
      } else if err == formula_error_value {
        Number(3.0)
      } else if err == formula_error_ref {
        Number(4.0)
      } else if err == formula_error_name {
        Number(5.0)
      } else if err == formula_error_num {
        Number(6.0)
      } else if err == formula_error_na {
        Number(7.0)
      } else {
        Error(formula_error_na)
      }
    _ => Error(formula_error_na)
  }
}

///|
fn type_value(value : FormulaValue) -> FormulaValue {
  match value {
    Error(_) => Number(16.0)
    List(_) => Number(64.0)
    Number(_) => Number(1.0)
    Bool(_) => Number(4.0)
    Empty => Number(1.0)
    String(_) => Number(2.0)
  }
}

///|
fn sheet_index_opt(workbook : Workbook, name : String) -> Int? {
  try workbook.sheet_index(name) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn is_known_error_code(err : String) -> Bool {
  err == formula_error_null ||
  err == formula_error_div ||
  err == formula_error_value ||
  err == formula_error_ref ||
  err == formula_error_name ||
  err == formula_error_num ||
  err == formula_error_na ||
  err == formula_error_spill ||
  err == formula_error_calc ||
  err == formula_error_getting_data
}

///|
fn is_ref_expr(expr : Expr) -> Bool {
  match expr {
    Cell(_, _) => true
    Range(_, _, _) => true
    _ => false
  }
}

///|
fn cell_has_formula(
  workbook : Workbook,
  sheet_name : String,
  reference : String,
) -> Bool {
  match workbook.sheet(sheet_name) {
    Some(sheet) => {
      let (row, col) = try cell_ref_to_rc(reference) catch {
        _ => return false
      } noraise {
        value => value
      }
      for cell in sheet.cells() {
        if cell.row == row && cell.col == col {
          match cell.formula {
            Some(formula) => return formula != ""
            None => return false
          }
        }
      }
      false
    }
    None => false
  }
}

///|
fn countblank_values(range_values : RangeValues) -> FormulaValue {
  let mut count = 0
  for value in range_values.values {
    match normalize_scalar(value) {
      Empty => count = count + 1
      _ => ()
    }
  }
  Number(Double::from_int(count))
}

///|
fn countif_values(
  range_values : RangeValues,
  criteria_value : FormulaValue,
) -> FormulaValue {
  let criteria = parse_formula_criteria(criteria_value)
  let mut count = 0
  for value in range_values.values {
    let normalized = normalize_scalar(value)
    if normalized is String(_) &&
      !formula_criteria_condition_is_string(criteria) {
      continue
    }
    if formula_criteria_eval(normalized, criteria) {
      count = count + 1
    }
  }
  Number(Double::from_int(count))
}

///|
fn sumif_values(
  range_values : RangeValues,
  criteria_value : FormulaValue,
  sum_range : RangeValues?,
) -> FormulaValue {
  let criteria = parse_formula_criteria(criteria_value)
  let mut sum = 0.0
  for row in 0..<range_values.rows {
    for col in 0..<range_values.cols {
      let idx = row * range_values.cols + col
      let cell = range_values.values[idx]
      let normalized = normalize_scalar(cell)
      if normalized is Empty {
        continue
      }
      if formula_criteria_eval(normalized, criteria) {
        let target = match sum_range {
          Some(range) =>
            match range.get(row, col) {
              Some(value) => value
              None => cell
            }
          None => cell
        }
        match normalize_scalar(target) {
          Number(num) => sum = sum + num
          Bool(flag) => {
            let num = if flag { 1.0 } else { 0.0 }
            sum = sum + num
          }
          _ => ()
        }
      }
    }
  }
  Number(sum)
}

///|
fn averageif_values(
  range_values : RangeValues,
  criteria_value : FormulaValue,
  average_range : RangeValues?,
) -> FormulaValue {
  let criteria = parse_formula_criteria(criteria_value)
  let mut sum = 0.0
  let mut count = 0
  for row in 0..<range_values.rows {
    for col in 0..<range_values.cols {
      let idx = row * range_values.cols + col
      let cell = normalize_scalar(range_values.values[idx])
      if formula_value_string(cell) == "" {
        continue
      }
      if cell is String(_) && !formula_criteria_condition_is_string(criteria) {
        continue
      }
      if formula_criteria_eval(cell, criteria) {
        let target = match average_range {
          Some(range) =>
            match range.get(row, col) {
              Some(value) => value
              None => cell
            }
          None => cell
        }
        match parse_double_opt(formula_value_string(target)) {
          Some(num) => {
            sum = sum + num
            count = count + 1
          }
          None => ()
        }
      }
    }
  }
  if count == 0 {
    Error(formula_error_div)
  } else {
    Number(sum / Double::from_int(count))
  }
}

///|
fn maxifs_values(
  max_range : RangeValues,
  matches : Array[CellIndex],
) -> FormulaValue {
  let mut best : Double? = None
  for cell in matches {
    match max_range.get(cell.row, cell.col) {
      Some(value) =>
        match value_as_number_opt(value) {
          Some(num) =>
            match best {
              Some(current) => if num > current { best = Some(num) }
              None => best = Some(num)
            }
          None => ()
        }
      None => return Error(formula_error_value)
    }
  }
  match best {
    Some(value) => Number(value)
    None => Number(0.0)
  }
}

///|
fn minifs_values(
  min_range : RangeValues,
  matches : Array[CellIndex],
) -> FormulaValue {
  let mut best : Double? = None
  for cell in matches {
    match min_range.get(cell.row, cell.col) {
      Some(value) =>
        match value_as_number_opt(value) {
          Some(num) =>
            match best {
              Some(current) => if num < current { best = Some(num) }
              None => best = Some(num)
            }
          None => ()
        }
      None => return Error(formula_error_value)
    }
  }
  match best {
    Some(value) => Number(value)
    None => Number(0.0)
  }
}

///|
fn ifs_match(
  ranges : Array[RangeValues],
  criteria : Array[FormulaCriteria],
) -> Array[CellIndex] {
  let matches : Array[CellIndex] = []
  if ranges.length() == 0 {
    return matches
  }
  let base = ranges[0]
  let base_criteria = criteria[0]
  for row in 0..<base.rows {
    for col in 0..<base.cols {
      let value = base.values[row * base.cols + col]
      if formula_criteria_eval(value, base_criteria) {
        matches.push({ row, col })
      }
    }
  }
  let mut current = matches
  for i in 1..<ranges.length() {
    let range = ranges[i]
    let criteria = criteria[i]
    let next : Array[CellIndex] = []
    for cell in current {
      match range.get(cell.row, cell.col) {
        Some(value) =>
          if formula_criteria_eval(value, criteria) {
            next.push(cell)
          }
        None => ()
      }
    }
    current = next
  }
  current
}

///|
fn flatten_values(values : ArrayView[FormulaValue]) -> Array[FormulaValue] {
  let out : Array[FormulaValue] = []
  for value in values {
    match value {
      List(list) => out.append(list)
      _ => out.push(value)
    }
  }
  out
}

///|

///|
fn resolve_cell_value(
  workbook : Workbook,
  sheet_name : String,
  reference : String,
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  let key = sheet_name + "!" + reference
  match ctx.visiting.get(key) {
    Some(_) => return Error(formula_error_calc)
    None => ()
  }
  if ctx.depth >= ctx.max_depth {
    return Error(formula_error_calc)
  }
  ctx.visiting[key] = true
  ctx.depth = ctx.depth + 1
  let value = calc_cell_value_internal(workbook, sheet_name, reference, ctx)
  ignore(ctx.visiting.remove(key))
  ctx.depth = ctx.depth - 1
  value
}

///|
fn spill_value_for_cell(
  workbook : Workbook,
  sheet_name : String,
  target_row : Int,
  target_col : Int,
  ctx : CalcContext,
) -> FormulaValue? raise XlsxError {
  let sheet = match workbook.sheet(sheet_name) {
    Some(value) => value
    None => return None
  }
  let max_cells = max_range_cells
  for cell in sheet.cells() {
    let formula = match cell.formula {
      Some(value) => value
      None => continue
    }
    let expr = parse_formula_expr(formula) catch { _ => continue }
    let shape = array_shape_from_expr(workbook, sheet_name, expr, ctx) catch {
      _ => continue
    }
    let (rows, cols) = match shape {
      Some(value) => value
      None => continue
    }
    if rows == 1 && cols == 1 {
      continue
    }
    if rows * cols > max_cells {
      continue
    }
    let anchor_row = cell.row
    let anchor_col = cell.col
    if target_row < anchor_row ||
      target_row >= anchor_row + rows ||
      target_col < anchor_col ||
      target_col >= anchor_col + cols {
      continue
    }
    let anchor_ref = cell_ref_from(anchor_row, anchor_col)
    let value = resolve_cell_value(workbook, sheet_name, anchor_ref, ctx)
    match value {
      List(list) => {
        let offset_row = target_row - anchor_row
        let offset_col = target_col - anchor_col
        let idx = offset_row * cols + offset_col
        if idx >= 0 && idx < list.length() {
          return Some(list[idx])
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn calc_cell_value_internal(
  workbook : Workbook,
  sheet_name : String,
  reference : String,
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  let sheet = match workbook.sheet(sheet_name) {
    Some(value) => value
    None => return Error(formula_error_ref)
  }
  let (row, col) = cell_ref_to_rc(reference)
  for cell in sheet.cells() {
    if cell.row == row && cell.col == col {
      match cell.formula {
        Some(formula) => {
          let expr = parse_formula_expr(formula)
          let prev_sheet = ctx.current_sheet
          let prev_ref = ctx.current_ref
          ctx.current_sheet = sheet_name
          ctx.current_ref = reference
          let result = eval_expr(workbook, sheet_name, expr, ctx)
          ctx.current_sheet = prev_sheet
          ctx.current_ref = prev_ref
          return result
        }
        None => {
          let value = cell_value_from_raw(cell.value_type, cell.value)
          return formula_value_from_cell_value(value)
        }
      }
    }
  }
  match spill_value_for_cell(workbook, sheet_name, row, col, ctx) {
    Some(value) => value
    None => Empty
  }
}

///|
fn collect_range_values(
  workbook : Workbook,
  sheet_name : String,
  start_ref : String,
  end_ref : String,
  ctx : CalcContext,
) -> Array[FormulaValue] raise XlsxError {
  collect_range_values_with_shape(workbook, sheet_name, start_ref, end_ref, ctx).values
}

///|
fn collect_range_values_with_shape(
  workbook : Workbook,
  sheet_name : String,
  start_ref : String,
  end_ref : String,
  ctx : CalcContext,
) -> RangeValues raise XlsxError {
  let (row1, col1) = cell_ref_to_rc(start_ref)
  let (row2, col2) = cell_ref_to_rc(end_ref)
  let min_row = if row1 < row2 { row1 } else { row2 }
  let max_row = if row1 > row2 { row1 } else { row2 }
  let min_col = if col1 < col2 { col1 } else { col2 }
  let max_col = if col1 > col2 { col1 } else { col2 }
  let (min_row, max_row, min_col, max_col) = effective_range_bounds(
    workbook, sheet_name, min_row, max_row, min_col, max_col,
  )
  let out : Array[FormulaValue] = []
  for row in min_row..<=max_row {
    for col in min_col..<=max_col {
      let cell_ref = cell_ref_from(row, col)
      out.push(resolve_cell_value(workbook, sheet_name, cell_ref, ctx))
    }
  }
  { values: out, rows: max_row - min_row + 1, cols: max_col - min_col + 1 }
}

///|
fn eval_range_expr(
  workbook : Workbook,
  sheet_name : String,
  expr : Expr,
  ctx : CalcContext,
) -> RangeValues raise XlsxError {
  match expr {
    Range(sheet, start_ref, end_ref) => {
      let target_sheet = if sheet == "" { sheet_name } else { sheet }
      collect_range_values_with_shape(
        workbook, target_sheet, start_ref, end_ref, ctx,
      )
    }
    Cell(sheet, reference) => {
      let target_sheet = if sheet == "" { sheet_name } else { sheet }
      let value = resolve_cell_value(workbook, target_sheet, reference, ctx)
      { values: [value], rows: 1, cols: 1 }
    }
    FuncCall(name, args) =>
      if is_munit_func(name) {
        munit_range_values_from_expr(workbook, sheet_name, args, ctx)
      } else if name == "TRANSPOSE" {
        transpose_range_values_from_expr(workbook, sheet_name, args, ctx)
      } else {
        let value = eval_expr(workbook, sheet_name, expr, ctx)
        { values: [value], rows: 1, cols: 1 }
      }
    _ => {
      let value = eval_expr(workbook, sheet_name, expr, ctx)
      { values: [value], rows: 1, cols: 1 }
    }
  }
}
