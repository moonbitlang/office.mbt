// Internals of the deletion planner that a black-box test cannot see.

///|
/// `RangeFamily`'s derived `Compare` — its DECLARATION ORDER — is what
/// `sort` uses, and the reported family for a target that trips several
/// is the first, so that order must agree with the labels a reader sees.
///
/// Checked by SORTING the constructors, not by reading a hand-typed list
/// that mirrors the enum: a constructor added last and its label slotted
/// alphabetically into such a list keeps the list green while `sort`
/// puts the family last. And checked with a lexicographic comparison
/// written out here, because the obvious one is wrong: MoonBit compares
/// `String` by LENGTH first, so `"aa" < "b"` is false.
test "range families sort into alphabetical label order" {
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

  assert_true(lexicographically_before("aa", "b"))
  assert_false("aa" < "b")
  // Every constructor, deliberately out of order.
  let families : Array[RangeFamily] = [
    TrackedMoveTo,
    CustomXmlIns,
    BookmarkRange,
    RangePermission,
    CustomXmlMoveTo,
    CommentRange,
    TrackedMoveFrom,
    CustomXmlDel,
    CustomXmlMoveFrom,
  ]
  families.sort()
  for index in 1..<families.length() {
    assert_true(
      lexicographically_before(
        families[index - 1].label(),
        families[index].label(),
      ),
      msg="\{families[index - 1].label()} must precede \{families[index].label()}",
    )
  }
  let seen : Map[String, Bool] = Map([])
  for family in families {
    seen[family.label()] = true
  }
  assert_eq(seen.length(), families.length())
}
