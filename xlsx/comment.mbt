///|
pub(all) struct Comment {
  cell : String
  author : String
  text : String
  paragraph : Array[RichTextRun]
  width : Int?
  height : Int?
} derive(Eq, Show)

///|
let max_comment_author_chars = 255
