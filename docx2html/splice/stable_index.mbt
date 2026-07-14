///|
/// Ordered indexes keep archive and plan names independent of the runtime's
/// string-hash collision behavior.
type StableStringMap[V] = @sorted_map.SortedMap[String, V]

///|
type StableStringSet = @sorted_set.SortedSet[String]
