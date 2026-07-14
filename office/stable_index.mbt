///|
/// Ordered indexes keep hostile package names independent of the runtime's
/// string-hash collision behavior.
type StableStringMap[V] = @sorted_map.SortedMap[String, V]
