// Internals of the deletion planner that a black-box test cannot see.

///|
/// `RangeFamily`'s DECLARATION ORDER is what `sort` uses — the derived
/// `Compare` — and the reported family for a target that trips several
/// is the first, so the order must be a property of the vocabulary and
/// not of where a constructor happened to be typed.
///
/// The list is declared alphabetically by label. This checks that with
/// a lexicographic comparison written out HERE, because the obvious way
/// to check it is wrong: MoonBit compares `String` by LENGTH first, so
/// `"aa" < "b"` is false and `["a comment range", "a bookmark range"]`
/// is what `sort` calls sorted. Every string ordering in this repo that
/// a person is meant to read has to be built rather than assumed.
test "range families are declared in alphabetical label order" {
  fn lexicographically_before(left : String, right : String) -> Bool {
    let shared = if left.length() < right.length() {
      left.length()
    } else {
      right.length()
    }
    for index in 0..<shared {
      if left[index] != right[index] {
        return left[index] < right[index]
      }
    }
    left.length() < right.length()
  }

  // The comparison itself, proved on the case that separates it from
  // the built-in one.
  assert_true(lexicographically_before("aa", "b"))
  assert_false("aa" < "b")
  let labels = [
    BookmarkRange.label(),
    CommentRange.label(),
    CustomXmlDel.label(),
    CustomXmlIns.label(),
    CustomXmlMoveFrom.label(),
    CustomXmlMoveTo.label(),
    RangePermission.label(),
    TrackedMoveFrom.label(),
    TrackedMoveTo.label(),
  ]
  for index in 1..<labels.length() {
    assert_true(
      lexicographically_before(labels[index - 1], labels[index]),
      msg="\{labels[index - 1]} must precede \{labels[index]}",
    )
  }
  // Distinct, so no two families can be confused in a message.
  let seen : Map[String, Bool] = Map([])
  for label in labels {
    seen[label] = true
  }
  assert_eq(seen.length(), labels.length())
}
