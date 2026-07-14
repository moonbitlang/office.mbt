///|
/// Ordered indexes keep hostile OOXML identifiers, paths, and namespace
/// prefixes independent of the runtime's string-hash collision behavior.
type StableStringMap[V] = @sorted_map.SortedMap[String, V]

///|
type StableStringSet = @sorted_set.SortedSet[String]
