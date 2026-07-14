///|
/// Ordered indexes keep hostile ZIP entry names independent of the runtime's
/// string-hash collision behavior.
type StableStringMap[V] = @sorted_map.SortedMap[String, V]
