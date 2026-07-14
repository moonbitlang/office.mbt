///|
/// Ordered sets keep hostile batch paths independent of the runtime's
/// string-hash collision behavior.
type StableStringSet = @sorted_set.SortedSet[String]
