///|
fn pdf_image_path_separator(code_unit : UInt16) -> Bool {
  let value = code_unit.to_int()
  value == 47 || value == 92
}

///|
fn pdf_image_dirname(path : String) -> String {
  let mut separator = -1
  for index in 0..<path.length() {
    if pdf_image_path_separator(path.at(index)) {
      separator = index
    }
  }
  if separator < 0 {
    "."
  } else if separator == 0 {
    path[:1].to_owned()
  } else {
    path[:separator].to_owned()
  }
}

///|
fn pdf_image_join_directory_file(
  directory : String,
  filename : String,
) -> String {
  if directory == "." {
    "./" + filename
  } else if directory.length() == 0 {
    filename
  } else {
    let last = directory.at(directory.length() - 1).to_int()
    if last == 47 || last == 92 {
      directory + filename
    } else {
      directory + "/" + filename
    }
  }
}
