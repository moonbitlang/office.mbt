///|
priv struct PdfImageListEntry {
  object_number : Int
  pages : Array[Int]
  name : String
  width : Int
  height : Int
  byte_count : Int
  bits_per_component : Int?
  colourspace : String?
  filter : String?
  mask : String
  mask_object_number : Int?
}
