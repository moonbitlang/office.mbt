///|
/// `mc:Ignorable` resets inherited processing rules for each namespace it
/// names. Generations make that reset O(1): older `ProcessContent` entries stay
/// reference-counted until their XML scope ends, but only the current
/// generation participates in element selection.
priv struct MceProcessKey {
  namespace_id : Int
  generation : Int
  local_name : String
} derive(Eq, Hash)

///|
priv struct MceProcessGenerationReset {
  namespace_id : Int
  previous_generation : Int?
}

///|
priv struct MceProcessTracker {
  key_counts : Map[MceProcessKey, Int]
  generations : Map[Int, Int]
  mut next_generation : Int
}

///|
fn MceProcessTracker::new() -> MceProcessTracker {
  { key_counts: Map([]), generations: Map([]), next_generation: 1 }
}

///|
fn MceProcessTracker::reset(
  self : MceProcessTracker,
  namespace_id : Int,
) -> MceProcessGenerationReset {
  let reset : MceProcessGenerationReset = {
    namespace_id,
    previous_generation: self.generations.get(namespace_id),
  }
  self.generations[namespace_id] = self.next_generation
  self.next_generation += 1
  reset
}

///|
fn MceProcessTracker::add(
  self : MceProcessTracker,
  namespace_id : Int,
  local_name : String,
) -> MceProcessKey {
  let key : MceProcessKey = {
    namespace_id,
    generation: self.generations.get_or_default(namespace_id, 0),
    local_name,
  }
  self.key_counts[key] = self.key_counts.get_or_default(key, 0) + 1
  key
}

///|
fn MceProcessTracker::processes(
  self : MceProcessTracker,
  namespace_id : Int,
  local_name : String,
) -> Bool {
  let generation = self.generations.get_or_default(namespace_id, 0)
  self.key_counts.get_or_default({ namespace_id, generation, local_name }, 0) >
  0 ||
  self.key_counts.get_or_default(
    { namespace_id, generation, local_name: "*" },
    0,
  ) >
  0
}

///|
fn MceProcessTracker::leave(
  self : MceProcessTracker,
  keys : ArrayView[MceProcessKey],
  resets : ArrayView[MceProcessGenerationReset],
) -> Unit {
  for key in keys {
    let remaining = self.key_counts.get_or_default(key, 0) - 1
    if remaining <= 0 {
      ignore(self.key_counts.remove(key))
    } else {
      self.key_counts[key] = remaining
    }
  }
  for reset in resets {
    match reset.previous_generation {
      Some(generation) => self.generations[reset.namespace_id] = generation
      None => ignore(self.generations.remove(reset.namespace_id))
    }
  }
}
