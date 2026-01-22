///|
pub struct Stack[T] {
  items : Array[T]
}

///|
pub fn[T] Stack::new() -> Stack[T] {
  { items: [] }
}

///|
pub fn[T] Stack::push(self : Stack[T], value : T) -> Unit {
  self.items.push(value)
}

///|
pub fn[T] Stack::pop(self : Stack[T]) -> T? {
  self.items.pop()
}

///|
pub fn[T] Stack::peek(self : Stack[T]) -> T? {
  self.items.last()
}

///|
pub fn[T] Stack::len(self : Stack[T]) -> Int {
  self.items.length()
}

///|
pub fn[T] Stack::empty(self : Stack[T]) -> Bool {
  self.items.is_empty()
}

///|
pub fn[T] new_stack() -> Stack[T] {
  Stack::new()
}
