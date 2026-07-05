///|
// The predefined CMap tables in this package are stored as flat
// `ReadOnlyArray[Int]` literals, which the native backend lowers to static C
// data. Direct tuple-array literals instead compile to ~410 bytes of
// constructor C per element, which blew the generated translation unit up to
// 87 MB. These helpers rebuild the original tuple shape once at load, so the
// public table values (and every consumer) are unchanged.

///|
fn pdf_cmap_unpack1(flat : ReadOnlyArray[Int]) -> Array[Int] {
  let out : Array[Int] = Array::new(capacity=flat.length())
  for i in 0..<flat.length() {
    out.push(flat[i])
  }
  out
}

///|
fn pdf_cmap_unpack2(flat : ReadOnlyArray[Int]) -> Array[(Int, Int)] {
  let n = flat.length() / 2
  let out : Array[(Int, Int)] = Array::new(capacity=n)
  for i in 0..<n {
    out.push((flat[i * 2], flat[i * 2 + 1]))
  }
  out
}

///|
fn pdf_cmap_unpack3(flat : ReadOnlyArray[Int]) -> Array[(Int, Int, Int)] {
  let n = flat.length() / 3
  let out : Array[(Int, Int, Int)] = Array::new(capacity=n)
  for i in 0..<n {
    out.push((flat[i * 3], flat[i * 3 + 1], flat[i * 3 + 2]))
  }
  out
}

///|
/// CSR-style unpack: `keys[i]` pairs with `pool[offsets[i]:offsets[i+1]]`.
fn pdf_cmap_unpack_csr(
  keys : ReadOnlyArray[Int],
  offsets : ReadOnlyArray[Int],
  pool : ReadOnlyArray[Int],
) -> Array[(Int, Array[Int])] {
  let n = keys.length()
  let out : Array[(Int, Array[Int])] = Array::new(capacity=n)
  for i in 0..<n {
    let start = offsets[i]
    let stop = offsets[i + 1]
    let vals : Array[Int] = Array::new(capacity=stop - start)
    for j in start..<stop {
      vals.push(pool[j])
    }
    out.push((keys[i], vals))
  }
  out
}
