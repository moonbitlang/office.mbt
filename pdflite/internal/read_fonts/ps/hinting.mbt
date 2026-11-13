// Port of read-fonts 0.39.2 `src/ps/hinting.rs`.

///|
/// Maximum number of values in a set of blue alignment zones.
pub const MAX_BLUE_VALUES : Int32 = 7

///|
/// Operand for the `BlueValues`, `OtherBlues`, `FamilyBlues` and
/// `FamilyOtherBlues` operators.
#derive(Eq, Debug)
pub(all) struct Blues {
  values : Array[(@font_types.Fixed, @font_types.Fixed)]
}

///|
/// Creates a new set of blues from the given values.
pub fn Blues::new(values : Array[@font_types.Fixed]) -> Blues {
  let blues = []
  let mut stash = @font_types.Fixed::zero()
  for i, value in values {
    if i >= MAX_BLUE_VALUES * 2 {
      break
    }
    if (i & 1) == 0 {
      stash = value
    } else {
      blues.push((stash, value))
    }
  }
  { values: blues, }
}

///|
pub fn Blues::default() -> Blues {
  { values: [], }
}

///|
/// Maximum number of stem snap parameters.
pub const MAX_STEM_SNAPS : Int32 = 12

///|
/// Operand for the `StemSnapH` and `StemSnapV` operators.
#derive(Eq, Debug)
pub(all) struct StemSnaps {
  values : Array[@font_types.Fixed]
}

///|
/// Creates a new set of stem snaps for the given values.
pub fn StemSnaps::new(values : Array[@font_types.Fixed]) -> StemSnaps {
  let v = []
  for i, value in values {
    if i >= MAX_STEM_SNAPS {
      break
    }
    v.push(value)
  }
  { values: v, }
}

///|
/// Parameters used to generate the stem and counter zones for the hinting
/// algorithm.
#derive(Eq, Debug)
pub(all) struct HintingParams {
  mut blues : Blues
  mut family_blues : Blues
  mut other_blues : Blues
  mut family_other_blues : Blues
  mut blue_scale : @font_types.Fixed
  mut blue_shift : @font_types.Fixed
  mut blue_fuzz : @font_types.Fixed
  mut language_group : Int32
}

///|
pub fn HintingParams::default() -> HintingParams {
  {
    blues: Blues::default(),
    other_blues: Blues::default(),
    family_blues: Blues::default(),
    family_other_blues: Blues::default(),
    blue_scale: @font_types.Fixed::from_f64(0.039625),
    blue_shift: @font_types.Fixed::from_i32(7),
    blue_fuzz: @font_types.Fixed::one(),
    language_group: 0,
  }
}
