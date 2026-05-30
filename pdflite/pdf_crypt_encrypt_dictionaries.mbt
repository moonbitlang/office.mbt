///|
fn pdf_crypt_saved_arc4_dictionary(
  values : PdfEncryptionValues,
  key_length_bits : Int,
  revision : Int,
) -> @syntax.PdfObject {
  if revision == 4 {
    let std_cf = pdf_crypt_std_cf_name
    PdfDictionary([
      (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
      (pdf_crypt_v_name, PdfInteger(4)),
      (
        pdf_crypt_cf_name,
        PdfDictionary([
          (
            std_cf,
            PdfDictionary([
              (pdf_crypt_length_name, PdfInteger(key_length_bits / 8)),
              (
                pdf_crypt_auth_event_name,
                PdfNameObject(pdf_crypt_doc_open_name),
              ),
              (pdf_crypt_cfm_name, PdfNameObject(pdf_crypt_v2_name)),
            ]),
          ),
        ]),
      ),
      (pdf_crypt_encrypt_metadata_name, PdfBoolean(values.encrypt_metadata)),
      (pdf_crypt_length_name, PdfInteger(key_length_bits)),
      (pdf_crypt_r_name, PdfInteger(4)),
      (pdf_crypt_o_name, PdfString(values.owner_entry)),
      (pdf_crypt_u_name, PdfString(values.user_entry)),
      (pdf_crypt_p_name, PdfInteger(values.permissions)),
      (pdf_crypt_strf_name, PdfNameObject(std_cf)),
      (pdf_crypt_stmf_name, PdfNameObject(std_cf)),
    ])
  } else {
    let entries : Array[(PdfName, @syntax.PdfObject)] = [
      (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
      (
        pdf_crypt_v_name,
        PdfInteger(if revision == 2 && key_length_bits == 40 { 1 } else { 2 }),
      ),
      (pdf_crypt_r_name, PdfInteger(revision)),
      (pdf_crypt_o_name, PdfString(values.owner_entry)),
      (pdf_crypt_u_name, PdfString(values.user_entry)),
      (pdf_crypt_p_name, PdfInteger(values.permissions)),
    ]
    if key_length_bits != 40 {
      entries.push((pdf_crypt_length_name, PdfInteger(key_length_bits)))
    }
    PdfDictionary(entries)
  }
}

///|
fn pdf_crypt_saved_aesv2_dictionary(
  values : PdfEncryptionValues,
) -> @syntax.PdfObject {
  let std_cf = pdf_crypt_std_cf_name
  PdfDictionary([
    (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
    (pdf_crypt_v_name, PdfInteger(4)),
    (
      pdf_crypt_cf_name,
      PdfDictionary([
        (
          std_cf,
          PdfDictionary([
            (pdf_crypt_length_name, PdfInteger(16)),
            (pdf_crypt_auth_event_name, PdfNameObject(pdf_crypt_doc_open_name)),
            (pdf_crypt_cfm_name, PdfNameObject(pdf_crypt_aesv2_name)),
          ]),
        ),
      ]),
    ),
    (pdf_crypt_encrypt_metadata_name, PdfBoolean(values.encrypt_metadata)),
    (pdf_crypt_length_name, PdfInteger(128)),
    (pdf_crypt_r_name, PdfInteger(4)),
    (pdf_crypt_o_name, PdfString(values.owner_entry)),
    (pdf_crypt_u_name, PdfString(values.user_entry)),
    (pdf_crypt_p_name, PdfInteger(values.permissions)),
    (pdf_crypt_strf_name, PdfNameObject(std_cf)),
    (pdf_crypt_stmf_name, PdfNameObject(std_cf)),
  ])
}

///|
fn pdf_crypt_saved_aesv3_dictionary(
  values : PdfEncryptionValues,
) -> @syntax.PdfObject raise PdfError {
  let std_cf = pdf_crypt_std_cf_name
  let revision = match values.crypt_type {
    PdfCryptAESV3(true) => 6
    _ => 5
  }
  PdfDictionary([
    (pdf_crypt_filter_name, PdfNameObject(pdf_crypt_standard_name)),
    (pdf_crypt_v_name, PdfInteger(5)),
    (
      pdf_crypt_cf_name,
      PdfDictionary([
        (
          std_cf,
          PdfDictionary([
            (pdf_crypt_length_name, PdfInteger(32)),
            (pdf_crypt_auth_event_name, PdfNameObject(pdf_crypt_doc_open_name)),
            (pdf_crypt_cfm_name, PdfNameObject(pdf_crypt_aesv3_name)),
          ]),
        ),
      ]),
    ),
    (pdf_crypt_encrypt_metadata_name, PdfBoolean(values.encrypt_metadata)),
    (pdf_crypt_length_name, PdfInteger(256)),
    (pdf_crypt_r_name, PdfInteger(revision)),
    (pdf_crypt_o_name, PdfString(values.owner_entry)),
    (pdf_crypt_u_name, PdfString(values.user_entry)),
    (
      pdf_crypt_oe_name,
      PdfString(
        pdf_aesv3_crypt_entry(pdf_crypt_oe_name, values.owner_encryption_key),
      ),
    ),
    (
      pdf_crypt_ue_name,
      PdfString(
        pdf_aesv3_crypt_entry(pdf_crypt_ue_name, values.user_encryption_key),
      ),
    ),
    (
      pdf_aesv3_permissions_key(),
      PdfString(
        pdf_crypt_chop_string(
          pdf_aesv3_permissions_key(),
          match values.permissions_entry {
            Some(value) => value
            None =>
              raise EncryptionDictionaryEntryExpected(
                pdf_aesv3_permissions_key(),
              )
          },
          16,
        ),
      ),
    ),
    (pdf_crypt_p_name, PdfInteger(values.permissions)),
    (pdf_crypt_strf_name, PdfNameObject(std_cf)),
    (pdf_crypt_stmf_name, PdfNameObject(std_cf)),
  ])
}
