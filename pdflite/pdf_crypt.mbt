///|
pub(all) enum PdfPermission {
  PdfNoEdit
  PdfNoPrint
  PdfNoCopy
  PdfNoAnnot
  PdfNoForms
  PdfNoExtract
  PdfNoAssemble
  PdfNoHqPrint
} derive(Debug, Eq, ToJson)

///|
fn pdf_permission_denied(
  permissions : ArrayView[PdfPermission],
  target : PdfPermission,
) -> Bool {
  for permission in permissions {
    if permission == target {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_permission_set_bit(mask : Int, bit : Int, value : Bool) -> Int {
  if value {
    mask | (1 << (bit - 1))
  } else {
    mask
  }
}

///|
pub fn pdf_p_of_permissions(permissions : ArrayView[PdfPermission]) -> Int {
  let mut mask = 0
  mask = pdf_permission_set_bit(
    mask,
    3,
    !pdf_permission_denied(permissions, PdfNoPrint),
  )
  mask = pdf_permission_set_bit(
    mask,
    4,
    !pdf_permission_denied(permissions, PdfNoEdit),
  )
  mask = pdf_permission_set_bit(
    mask,
    5,
    !pdf_permission_denied(permissions, PdfNoCopy),
  )
  mask = pdf_permission_set_bit(
    mask,
    6,
    !pdf_permission_denied(permissions, PdfNoAnnot),
  )
  mask = pdf_permission_set_bit(mask, 7, true)
  mask = pdf_permission_set_bit(mask, 8, true)
  mask = pdf_permission_set_bit(
    mask,
    9,
    !pdf_permission_denied(permissions, PdfNoForms),
  )
  mask = pdf_permission_set_bit(
    mask,
    10,
    !pdf_permission_denied(permissions, PdfNoExtract),
  )
  mask = pdf_permission_set_bit(
    mask,
    11,
    !pdf_permission_denied(permissions, PdfNoAssemble),
  )
  mask = pdf_permission_set_bit(
    mask,
    12,
    !pdf_permission_denied(permissions, PdfNoHqPrint),
  )
  for bit in 13..<=32 {
    mask = pdf_permission_set_bit(mask, bit, true)
  }
  mask
}

///|
fn pdf_permission_bit_denied(mask : Int, bit : Int) -> Bool {
  ((mask >> (bit - 1)) & 1) == 0
}

///|
pub fn pdf_permissions_of_p(mask : Int) -> Array[PdfPermission] {
  let permissions : Array[PdfPermission] = []
  if pdf_permission_bit_denied(mask, 12) {
    permissions.push(PdfNoHqPrint)
  }
  if pdf_permission_bit_denied(mask, 11) {
    permissions.push(PdfNoAssemble)
  }
  if pdf_permission_bit_denied(mask, 10) {
    permissions.push(PdfNoExtract)
  }
  if pdf_permission_bit_denied(mask, 9) {
    permissions.push(PdfNoForms)
  }
  if pdf_permission_bit_denied(mask, 6) {
    permissions.push(PdfNoAnnot)
  }
  if pdf_permission_bit_denied(mask, 5) {
    permissions.push(PdfNoCopy)
  }
  if pdf_permission_bit_denied(mask, 4) {
    permissions.push(PdfNoEdit)
  }
  if pdf_permission_bit_denied(mask, 3) {
    permissions.push(PdfNoPrint)
  }
  permissions
}
