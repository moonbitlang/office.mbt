///|
/// Add a parsed object using the next available object number.
///
/// Returns the allocated object number and records an object-altered event.
pub fn PdfDocument::add_object(
  self : PdfDocument,
  object : @syntax.PdfObject,
  generation? : Int = 0,
) -> Int {
  self.objects.add_object(object, generation~)
}

///|
/// Add or replace a parsed object at an explicit object number.
///
/// This records an object-altered event and updates the maximum object number if
/// needed.
pub fn PdfDocument::add_object_given_number(
  self : PdfDocument,
  number : Int,
  object : @syntax.PdfObject,
  generation? : Int = 0,
) -> Unit {
  self.objects.add_object_given_number(number, object, generation~)
}

///|
fn PdfDocument::load_object_given_number(
  self : PdfDocument,
  number : Int,
  object : @syntax.PdfObject,
  generation? : Int = 0,
) -> Unit {
  self.objects.load_object_given_number(number, object, generation)
}

///|
fn PdfDocument::load_object_given_number_already_decrypted(
  self : PdfDocument,
  number : Int,
  object : @syntax.PdfObject,
) -> Unit {
  self.objects.load_object_given_number_already_decrypted(number, object)
}

///|
/// Remove an object from the document and record a deletion event.
pub fn PdfDocument::remove_object(self : PdfDocument, number : Int) -> Unit {
  self.objects.remove_object(number)
}

///|
/// Return a parsed object by number, or `PdfNull` if it is absent or deferred.
pub fn PdfDocument::lookup_object_or_null(
  self : PdfDocument,
  number : Int,
) -> @syntax.PdfObject {
  self.objects.lookup_object_or_null(number)
}

///|
/// Return a copy of the document object mutation log.
pub fn PdfDocument::event_log(
  self : PdfDocument,
) -> Array[(Int, PdfObjectEvent)] {
  self.objects.log()
}
