// Port of read-fonts 0.39.2 `src/tables/name.rs` (+ `generated_name.rs`)
// and the localized string selection from skrifa 0.42.1 `src/string.rs`.

///|
/// The [name](https://docs.microsoft.com/en-us/typography/opentype/spec/name) table.
pub struct Name {
  data : FontData
}

///|
pub fn FontRef::name(self : FontRef) -> Name raise ReadError {
  let data = self.expect_data_for_tag("name")
  if data.len() < 6 {
    raise OutOfBounds
  }
  { data, }
}

///|
pub fn Name::version(self : Name) -> Int {
  u16_at(self.data, 0)
}

///|
pub fn Name::count(self : Name) -> Int {
  u16_at(self.data, 2)
}

///|
pub fn Name::storage_offset(self : Name) -> Int {
  u16_at(self.data, 4)
}

///|
/// A name record.
pub(all) struct NameRecord {
  platform_id : Int
  encoding_id : Int
  language_id : Int
  name_id : Int
  length : Int
  string_offset : Int
} derive(Debug)

///|
pub fn Name::name_record(self : Name) -> Array[NameRecord] {
  let recs = self.data.read_array(6, self.count(), 12) catch {
    _ => FontData::empty()
  }
  [
    for i in 0..<(recs.len() / 12) => {
      NameRecord::{
        platform_id: u16_at(recs, i * 12),
        encoding_id: u16_at(recs, i * 12 + 2),
        language_id: u16_at(recs, i * 12 + 4),
        name_id: u16_at(recs, i * 12 + 6),
        length: u16_at(recs, i * 12 + 8),
        string_offset: u16_at(recs, i * 12 + 10),
      }
    }
  ]
}

///|
/// Language tag records (length, offset) of version 1 tables.
pub fn Name::lang_tag_record(self : Name) -> Array[(Int, Int)]? {
  if self.version() < 1 {
    return None
  }
  let start = 6 + self.count() * 12
  let lang_tag_count = u16_at(self.data, start)
  if lang_tag_count == 0 {
    return None
  }
  let recs = self.data.read_array(start + 2, lang_tag_count, 4) catch {
    _ => return None
  }
  Some(
    [
      for i in 0..<lang_tag_count => {
        (u16_at(recs, i * 4), u16_at(recs, i * 4 + 2))
      }
    ],
  )
}

///|
pub fn Name::string_data(self : Name) -> FontData {
  self.data.split_off(self.storage_offset()).unwrap_or(FontData::empty())
}

///|
/// String encodings of name records.
pub(all) enum NameEncoding {
  Utf16Be
  MacRoman
  Unknown
} derive(Eq, Debug)

///|
pub fn NameEncoding::new(platform_id : Int, encoding_id : Int) -> NameEncoding {
  match (platform_id, encoding_id) {
    (0, _) => Utf16Be
    (1, 0) => MacRoman
    (3, 0) => Utf16Be
    (3, 1) => Utf16Be
    (3, 10) => Utf16Be
    _ => Unknown
  }
}

///|
/// An encoded name string.
pub struct NameString {
  data : BytesView
  encoding : NameEncoding
}

///|
pub fn NameRecord::string(
  self : NameRecord,
  data : FontData,
) -> NameString raise ReadError {
  let start = self.string_offset
  let end = start + self.length
  guard data.get(start, end) is Some(bytes) else { raise OutOfBounds }
  {
    data: bytes,
    encoding: NameEncoding::new(self.platform_id, self.encoding_id),
  }
}

///|
fn lang_tag_string(
  length : Int,
  offset : Int,
  data : FontData,
) -> NameString raise ReadError {
  guard data.get(offset, offset + length) is Some(bytes) else {
    raise OutOfBounds
  }
  { data: bytes, encoding: Utf16Be, }
}

///|
/// Decodes the string into characters.
pub fn NameString::chars(self : NameString) -> Array[Char] {
  let result = []
  let data = self.data
  let mut pos = 0
  let rep = '\u{FFFD}'
  while pos < data.length() {
    match self.encoding {
      Utf16Be => {
        if pos + 2 > data.length() {
          break
        }
        let c1 = (data[pos].to_int() << 8) | data[pos + 1].to_int()
        pos += 2
        let raw = if c1 >= 0xD800 && c1 < 0xDC00 {
          if pos + 2 > data.length() {
            result.push(rep)
            continue
          }
          let c2 = (data[pos].to_int() << 8) | data[pos + 1].to_int()
          pos += 2
          ((c1 & 0x3FF) << 10) + (c2 & 0x3FF) + 0x10000
        } else {
          c1
        }
        result.push(char_from_u32(raw).unwrap_or(rep))
      }
      MacRoman => {
        let c = data[pos].to_int()
        pos += 1
        let raw = if c < 128 { c } else { mac_roman_decode[c - 128] }
        result.push(char_from_u32(raw).unwrap_or(rep))
      }
      Unknown => break
    }
  }
  result
}

///|
fn char_from_u32(v : Int) -> Char? {
  if v < 0 || v > 0x10FFFF || (v >= 0xD800 && v <= 0xDFFF) {
    None
  } else {
    Some(Int::unsafe_to_char(v))
  }
}

///|
pub fn NameString::to_string(self : NameString) -> String {
  String::from_array(self.chars())
}

///|
let mac_roman_decode : FixedArray[Int] = [
  196, 197, 199, 201, 209, 214, 220, 225, 224, 226, 228, 227, 229, 231, 233, 232,
  234, 235, 237, 236, 238, 239, 241, 243, 242, 244, 246, 245, 250, 249, 251, 252,
  8224, 176, 162, 163, 167, 8226, 182, 223, 174, 169, 8482, 180, 168, 8800, 198,
  216, 8734, 177, 8804, 8805, 165, 181, 8706, 8721, 8719, 960, 8747, 170, 186, 937,
  230, 248, 191, 161, 172, 8730, 402, 8776, 8710, 171, 187, 8230, 160, 192, 195,
  213, 338, 339, 8211, 8212, 8220, 8221, 8216, 8217, 247, 9674, 255, 376, 8260, 8364,
  8249, 8250, 64257, 64258, 8225, 183, 8218, 8222, 8240, 194, 202, 193, 203, 200,
  205, 206, 207, 204, 211, 212, 63743, 210, 218, 219, 217, 305, 710, 732, 175, 728,
  729, 730, 184, 733, 731, 711,
]

///|
/// A localized string: language (BCP 47 tag) and value.
pub struct LocalizedString {
  language : String?
  value : NameString?
}

///|
pub fn LocalizedString::language(self : LocalizedString) -> String? {
  self.language
}

///|
pub fn LocalizedString::chars(self : LocalizedString) -> Array[Char] {
  match self.value {
    Some(v) => v.chars()
    None => []
  }
}

///|
fn LocalizedString::new(name : Name, record : NameRecord) -> LocalizedString {
  let language = name_language(name, record)
  let value = Some(record.string(name.string_data())) catch { _ => None }
  { language, value, }
}

///|
fn name_language(name : Name, record : NameRecord) -> String? {
  let language_id = record.language_id
  // For version 1 name tables, prefer language tags
  if name.version() == 1 && language_id >= 0x8000 {
    let index = language_id - 0x8000
    guard name.lang_tag_record() is Some(recs) else { return None }
    guard recs.get(index) is Some((length, offset)) else { return None }
    let s = lang_tag_string(length, offset, name.string_data()) catch {
      _ => return None
    }
    let chars = s.chars()
    if chars.length() > 30 {
      return None
    }
    for ch in chars {
      if ch.to_int() >= 0x80 {
        return None
      }
    }
    Some(String::from_array(chars))
  } else {
    match record.platform_id {
      // We only match Macintosh and Windows language ids.
      1 | 3 => language_id_to_bcp47(language_id)
      _ => None
    }
  }
}

///|
fn language_id_to_bcp47(language_id : Int) -> String? {
  let table = language_id_to_bcp47_table
  let mut lo = 0
  let mut hi = table.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let (k, v) = table[mid]
    if k < language_id {
      lo = mid + 1
    } else if k > language_id {
      hi = mid
    } else {
      return Some(v)
    }
  }
  None
}

///|
/// Returns the localized strings for the given name id.
pub fn FontRef::localized_strings(
  self : FontRef,
  id : Int,
) -> Array[LocalizedString] {
  let name = self.name() catch { _ => return [] }
  let result = []
  for record in name.name_record() {
    if record.name_id == id {
      result.push(LocalizedString::new(name, record))
    }
  }
  result
}

///|
/// Returns the best available English string or the first string in the
/// sequence.
pub fn english_or_first(strings : Array[LocalizedString]) -> LocalizedString? {
  let mut best_rank = -1
  let mut best_string : LocalizedString? = None
  for i, string in strings {
    let rank = match (i, string.language) {
      (_, Some("en-US")) => return Some(string)
      (_, Some("en")) => 2
      (_, None) => 1
      (0, _) => 0
      _ => continue
    }
    if rank > best_rank {
      best_rank = rank
      best_string = Some(string)
    }
  }
  best_string
}

///|
/// Well-known name id: family name.
pub const NAME_ID_FAMILY_NAME : Int = 1

///|
/// Mapping from Mac/Windows language ids to BCP 47 tags (sorted by id).
let language_id_to_bcp47_table : FixedArray[(Int, String)] = [
  (0, "en"),
  (1, "fr"),
  (2, "de"),
  (3, "it"),
  (4, "nl"),
  (5, "sv"),
  (6, "es"),
  (7, "da"),
  (8, "pt"),
  (9, "nb"),
  (10, "he"),
  (11, "ja"),
  (12, "ar"),
  (13, "fi"),
  (14, "el"),
  (15, "is"),
  (16, "mt"),
  (17, "tr"),
  (18, "hr"),
  (19, "zh-Hant"),
  (20, "ur"),
  (21, "hi"),
  (22, "th"),
  (23, "ko"),
  (24, "lt"),
  (25, "pl"),
  (26, "hu"),
  (27, "et"),
  (28, "lv"),
  (29, "se"),
  (30, "fo"),
  (31, "fa"),
  (32, "ru"),
  (33, "zh-Hans"),
  (34, "nl"),
  (35, "ga"),
  (36, "sq"),
  (37, "ro"),
  (38, "cs"),
  (39, "sk"),
  (40, "sl"),
  (41, "yi"),
  (42, "sr"),
  (43, "mk"),
  (44, "bg"),
  (45, "uk"),
  (46, "be"),
  (47, "uz"),
  (48, "kk"),
  (49, "az-Cyrl"),
  (50, "az-Arab"),
  (51, "hy"),
  (52, "ka"),
  (53, "mo"),
  (54, "ky"),
  (55, "tg"),
  (56, "tk"),
  (57, "mn-Mong"),
  (58, "mn-Cyrl"),
  (59, "ps"),
  (60, "ku"),
  (61, "ks"),
  (62, "sd"),
  (63, "bo"),
  (64, "ne"),
  (65, "sa"),
  (66, "mr"),
  (67, "bn"),
  (68, "as"),
  (69, "gu"),
  (70, "pa"),
  (71, "or"),
  (72, "ml"),
  (73, "kn"),
  (74, "ta"),
  (75, "te"),
  (76, "si"),
  (77, "my"),
  (78, "km"),
  (79, "lo"),
  (80, "vi"),
  (81, "id"),
  (82, "tl"),
  (83, "ms-Latn"),
  (84, "ms-Arab"),
  (85, "am"),
  (86, "ti"),
  (87, "om"),
  (88, "so"),
  (89, "sw"),
  (90, "rw"),
  (91, "rn"),
  (92, "ny"),
  (93, "mg"),
  (94, "eo"),
  (128, "cy"),
  (129, "eu"),
  (130, "ca"),
  (131, "la"),
  (132, "qu"),
  (133, "gn"),
  (134, "ay"),
  (135, "tt"),
  (136, "ug"),
  (137, "dz"),
  (138, "jv-Latn"),
  (139, "su-Latn"),
  (140, "gl"),
  (141, "af"),
  (142, "br"),
  (143, "iu"),
  (144, "gd"),
  (145, "gv"),
  (146, "ga"),
  (147, "to"),
  (148, "el"),
  (149, "kl"),
  (150, "az-Latn"),
  (151, "nn"),
  (1025, "ar-SA"),
  (1026, "bg-BG"),
  (1027, "ca-ES"),
  (1028, "zh-TW"),
  (1029, "cs-CZ"),
  (1030, "da-DK"),
  (1031, "de-DE"),
  (1032, "el-GR"),
  (1033, "en-US"),
  (1034, "es-ES_tradnl"),
  (1035, "fi-FI"),
  (1036, "fr-FR"),
  (1037, "he-IL"),
  (1037, "he"),
  (1038, "hu-HU"),
  (1038, "hu"),
  (1039, "is-IS"),
  (1040, "it-IT"),
  (1041, "ja-JP"),
  (1042, "ko-KR"),
  (1043, "nl-NL"),
  (1044, "nb-NO"),
  (1045, "pl-PL"),
  (1046, "pt-BR"),
  (1047, "rm-CH"),
  (1048, "ro-RO"),
  (1049, "ru-RU"),
  (1050, "hr-HR"),
  (1051, "sk-SK"),
  (1052, "sq-AL"),
  (1053, "sv-SE"),
  (1054, "th-TH"),
  (1055, "tr-TR"),
  (1056, "ur-PK"),
  (1057, "id-ID"),
  (1058, "uk-UA"),
  (1059, "be-BY"),
  (1060, "sl-SI"),
  (1061, "et-EE"),
  (1062, "lv-LV"),
  (1063, "lt-LT"),
  (1064, "tg-Cyrl-TJ"),
  (1065, "fa-IR"),
  (1066, "vi-VN"),
  (1067, "hy-AM"),
  (1068, "az-Latn-AZ"),
  (1069, "eu-ES"),
  (1070, "hsb-DE"),
  (1071, "mk-MK"),
  (1074, "tn-ZA"),
  (1076, "xh-ZA"),
  (1077, "zu-ZA"),
  (1078, "af-ZA"),
  (1079, "ka-GE"),
  (1080, "fo-FO"),
  (1081, "hi-IN"),
  (1082, "mt-MT"),
  (1083, "se-NO"),
  (1086, "ms-MY"),
  (1087, "kk-KZ"),
  (1088, "ky-KG"),
  (1089, "sw-KE"),
  (1090, "tk-TM"),
  (1091, "uz-Latn-UZ"),
  (1091, "uz"),
  (1092, "tt-RU"),
  (1093, "bn-IN"),
  (1094, "pa-IN"),
  (1095, "gu-IN"),
  (1096, "or-IN"),
  (1097, "ta-IN"),
  (1098, "te-IN"),
  (1099, "kn-IN"),
  (1100, "ml-IN"),
  (1101, "as-IN"),
  (1102, "mr-IN"),
  (1103, "sa-IN"),
  (1104, "mn-Cyrl"),
  (1105, "bo-CN"),
  (1106, "cy-GB"),
  (1107, "km-KH"),
  (1108, "lo-LA"),
  (1110, "gl-ES"),
  (1111, "kok-IN"),
  (1114, "syr-SY"),
  (1115, "si-LK"),
  (1117, "iu-Cans-CA"),
  (1118, "am-ET"),
  (1121, "ne-NP"),
  (1122, "fy-NL"),
  (1123, "ps-AF"),
  (1124, "fil-PH"),
  (1125, "dv-MV"),
  (1128, "ha-Latn-NG"),
  (1130, "yo-NG"),
  (1131, "quz-BO"),
  (1132, "nso-ZA"),
  (1133, "ba-RU"),
  (1134, "lb-LU"),
  (1135, "kl-GL"),
  (1136, "ig-NG"),
  (1144, "ii-CN"),
  (1146, "arn-CL"),
  (1148, "moh-CA"),
  (1150, "br-FR"),
  (1152, "ug-CN"),
  (1153, "mi-NZ"),
  (1154, "oc-FR"),
  (1155, "co-FR"),
  (1156, "gsw-FR"),
  (1157, "sah-RU"),
  (1158, "qut-GT"),
  (1159, "rw-RW"),
  (1160, "wo-SN"),
  (1164, "prs-AF"),
  (1169, "gd-GB"),
  (2049, "ar-IQ"),
  (2052, "zh-Hans"),
  (2055, "de-CH"),
  (2057, "en-GB"),
  (2058, "es-MX"),
  (2060, "fr-BE"),
  (2064, "it-CH"),
  (2067, "nl-BE"),
  (2068, "nn-NO"),
  (2070, "pt-PT"),
  (2074, "sr-Latn-CS"),
  (2077, "sv-FI"),
  (2092, "az-Cyrl-AZ"),
  (2094, "dsb-DE"),
  (2094, "dsb"),
  (2107, "se-SE"),
  (2108, "ga-IE"),
  (2110, "ms-BN"),
  (2115, "uz-Cyrl-UZ"),
  (2117, "bn-BD"),
  (2128, "mn-Mong-CN"),
  (2141, "iu-Latn-CA"),
  (2143, "tzm-Latn-DZ"),
  (2155, "quz-EC"),
  (3073, "ar-EG"),
  (3076, "zh-Hant"),
  (3079, "de-AT"),
  (3081, "en-AU"),
  (3082, "es-ES"),
  (3084, "fr-CA"),
  (3098, "sr-Cyrl-CS"),
  (3131, "se-FI"),
  (3179, "quz-PE"),
  (4097, "ar-LY"),
  (4100, "zh-SG"),
  (4103, "de-LU"),
  (4105, "en-CA"),
  (4106, "es-GT"),
  (4108, "fr-CH"),
  (4122, "hr-BA"),
  (4155, "smj-NO"),
  (5121, "ar-DZ"),
  (5124, "zh-MO"),
  (5127, "de-LI"),
  (5129, "en-NZ"),
  (5130, "es-CR"),
  (5132, "fr-LU"),
  (5146, "bs-Latn-BA"),
  (5146, "bs"),
  (5179, "smj-SE"),
  (5179, "smj"),
  (6145, "ar-MA"),
  (6153, "en-IE"),
  (6154, "es-PA"),
  (6156, "fr-MC"),
  (6170, "sr-Latn-BA"),
  (6203, "sma-NO"),
  (7169, "ar-TN"),
  (7177, "en-ZA"),
  (7178, "es-DO"),
  (7194, "sr-Cyrl-BA"),
  (7227, "sma-SE"),
  (7227, "sma"),
  (8193, "ar-OM"),
  (8201, "en-JM"),
  (8202, "es-VE"),
  (8218, "bs-Cyrl-BA"),
  (8218, "bs-Cyrl"),
  (8251, "sms-FI"),
  (8251, "sms"),
  (9217, "ar-YE"),
  (9225, "en-029"),
  (9226, "es-CO"),
  (9242, "sr-Latn-RS"),
  (9275, "smn-FI"),
  (10241, "ar-SY"),
  (10249, "en-BZ"),
  (10250, "es-PE"),
  (10266, "sr-Cyrl-RS"),
  (11265, "ar-JO"),
  (11273, "en-TT"),
  (11274, "es-AR"),
  (11290, "sr-Latn-ME"),
  (12289, "ar-LB"),
  (12297, "en-ZW"),
  (12298, "es-EC"),
  (12314, "sr-Cyrl-ME"),
  (13313, "ar-KW"),
  (13321, "en-PH"),
  (13322, "es-CL"),
  (14337, "ar-AE"),
  (14346, "es-UY"),
  (15361, "ar-BH"),
  (15370, "es-PY"),
  (16385, "ar-QA"),
  (16393, "en-IN"),
  (16394, "es-BO"),
  (17417, "en-MY"),
  (17418, "es-SV"),
  (18441, "en-SG"),
  (18442, "es-HN"),
  (19466, "es-NI"),
  (20490, "es-PR"),
  (21514, "es-US"),
]
