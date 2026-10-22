///|
priv struct PdflitePasswords {
  user : Bytes?
  owner : Bytes?
}

///|
async fn pdflite_cmd_password_value(
  args : @argparse.Matches,
  name : String,
) -> Bytes? {
  guard pdflite_cmd_optional_value(args, name + "-file") is Some(path) else {
    return pdflite_cmd_optional_value(args, name).map(value => {
      @utf8.encode(value)
    })
  }
  Some(@fs.read_file(path).binary())
}

///|
async fn pdflite_cmd_passwords(args : @argparse.Matches) -> PdflitePasswords {
  // Global options are propagated to the selected leaf command by argparse.
  guard args.subcommand is Some((_, child)) else {
    return {
      user: pdflite_cmd_password_value(args, "password"),
      owner: pdflite_cmd_password_value(args, "owner-password"),
    }
  }
  pdflite_cmd_passwords(child)
}

///|
fn pdflite_cmd_read_with_passwords(
  bytes : Bytes,
  passwords : PdflitePasswords,
) -> @pdf.PdfDocument raise @core.PdfError {
  if passwords.user is None && passwords.owner is None {
    return @pdf.pdf_read_document_from_bytes(bytes)
  }
  let result = @pdf.pdf_read_document_from_bytes_with_passwords(
    bytes,
    user_password=passwords.user.map(bytes => bytes),
    owner_password=passwords.owner.map(bytes => bytes),
  )
  guard result is Some(decrypted) else {
    raise SoftError("PDF password authentication failed")
  }
  decrypted.document
}
