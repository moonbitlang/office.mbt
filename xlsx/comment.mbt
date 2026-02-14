///|
pub(all) struct Comment {
  cell : String
  author : String
  author_id : Int?
  text : String
  paragraph : Array[RichTextRun]
  width : Int?
  height : Int?
} derive(Show)

///|
let max_comment_author_chars = 255
