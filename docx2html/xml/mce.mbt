// ECMA-376 Part 3 Markup Compatibility processing for strict XML trees.
// This entry point deliberately uses an empty markup configuration (there are
// no application-defined extension elements) and a caller-supplied application
// namespace configuration. OPC Relationships parts use exactly that model.

///|
const MCE_NAMESPACE_URI : String = "http://schemas.openxmlformats.org/markup-compatibility/2006"

///|
const MCE_ALTERNATE_CONTENT : String = "{http://schemas.openxmlformats.org/markup-compatibility/2006}AlternateContent"

///|
const MCE_CHOICE : String = "{http://schemas.openxmlformats.org/markup-compatibility/2006}Choice"

///|
const MCE_FALLBACK : String = "{http://schemas.openxmlformats.org/markup-compatibility/2006}Fallback"

///|
const MCE_IGNORABLE : String = "{http://schemas.openxmlformats.org/markup-compatibility/2006}Ignorable"

///|
const MCE_PROCESS_CONTENT : String = "{http://schemas.openxmlformats.org/markup-compatibility/2006}ProcessContent"

///|
const MCE_MUST_UNDERSTAND : String = "{http://schemas.openxmlformats.org/markup-compatibility/2006}MustUnderstand"

///|
const MCE_XML_BASE : String = "{http://www.w3.org/XML/1998/namespace}base"

///|
const MCE_XML_LANG : String = "{http://www.w3.org/XML/1998/namespace}lang"

///|
const MCE_XML_SPACE : String = "{http://www.w3.org/XML/1998/namespace}space"

///|
priv struct MceNamespaceChange {
  prefix : String
  previous : String?
}

///|
priv struct MceProcessAddition {
  key : String
  wildcard : Bool
}

///|
priv struct MceElementScope {
  namespace_changes : Array[MceNamespaceChange]
  ignorable_additions : Array[String]
  process_additions : Array[MceProcessAddition]
  must_understand_satisfied : Bool
}

///|
priv struct MceProcessor {
  budget : XmlReadBudget
  application_namespaces : @sorted_map.SortedMap[String, Bool]
  namespaces : @sorted_map.SortedMap[String, String]
  ignorable_namespaces : @sorted_map.SortedMap[String, Int]
  process_exact_names : @sorted_map.SortedMap[String, Int]
  process_wildcard_namespaces : @sorted_map.SortedMap[String, Int]
}

///|
fn mce_mismatch(message : String) -> Unit raise DocxError {
  raise InvalidXml(message="markup compatibility mismatch: " + message)
}

///|
fn mce_xml_whitespace_only(value : String) -> Bool {
  for character in value {
    if character != ' ' &&
      character != '\t' &&
      character != '\n' &&
      character != '\r' {
      return false
    }
  }
  true
}

///|
fn mce_namespace_from_expanded_name(
  name : String,
  budget : XmlReadBudget,
) -> String? raise DocxError {
  if !name.has_prefix("{") {
    return None
  }
  match name.rev_find("}") {
    Some(close) if close > 0 => {
      budget.charge_derived_chars(close - 1)
      Some(name[1:close].to_owned())
    }
    _ => None
  }
}

///|
// Use the final Clark-name separator rather than a string prefix: namespace
// names may themselves contain `}`, and must not impersonate `xmlns`.
fn mce_expanded_namespace_is(name : String, namespace_uri : String) -> Bool {
  if !name.has_prefix("{") {
    return false
  }
  match name.rev_find("}") {
    Some(close) if close > 0 => name[1:close] == namespace_uri
    _ => false
  }
}

///|
fn mce_split_tokens(
  value : String,
  budget : XmlReadBudget,
) -> Array[String] raise DocxError {
  let tokens : Array[String] = []
  let mut index = 0
  while index < value.length() {
    while index < value.length() {
      let character = match value.get_char(index) {
        Some(character) => character
        None => raise InvalidXml(message="invalid UTF-16 in MCE attribute")
      }
      if character != ' ' &&
        character != '\t' &&
        character != '\n' &&
        character != '\r' {
        break
      }
      index = index + character.utf16_len()
    }
    if index == value.length() {
      break
    }
    let start = index
    while index < value.length() {
      let character = match value.get_char(index) {
        Some(character) => character
        None => raise InvalidXml(message="invalid UTF-16 in MCE attribute")
      }
      if character == ' ' ||
        character == '\t' ||
        character == '\n' ||
        character == '\r' {
        break
      }
      index = index + character.utf16_len()
    }
    budget.charge_namespace_bindings(1)
    budget.charge_derived_chars(index - start)
    tokens.push(value[start:index].to_owned())
  }
  tokens
}

///|
fn mce_expanded_name(
  namespace_uri : String,
  local_name : String,
  budget : XmlReadBudget,
) -> String raise DocxError {
  let length = xml_derived_name_length(
    namespace_uri.length(),
    local_name.length(),
    2,
  )
  budget.charge_derived_chars(length)
  let output = StringBuilder()
  output.write_char('{')
  output.write_string(namespace_uri)
  output.write_char('}')
  output.write_string(local_name)
  output.to_string()
}

///|
fn MceProcessor::application_understands(
  self : MceProcessor,
  namespace_uri : String,
) -> Bool {
  self.application_namespaces.contains(namespace_uri)
}

///|
fn increment_mce_count(
  counts : @sorted_map.SortedMap[String, Int],
  key : String,
) -> Unit {
  match counts.get(key) {
    Some(count) => counts[key] = count + 1
    None => counts[key] = 1
  }
}

///|
fn decrement_mce_count(
  counts : @sorted_map.SortedMap[String, Int],
  key : String,
) -> Unit {
  match counts.get(key) {
    Some(count) if count > 1 => counts[key] = count - 1
    Some(_) => counts.remove(key)
    None => ()
  }
}

///|
fn MceProcessor::namespace_is_ignorable(
  self : MceProcessor,
  namespace_uri : String,
) -> Bool {
  self.ignorable_namespaces.contains(namespace_uri)
}

///|
fn MceProcessor::element_matches_process_content(
  self : MceProcessor,
  element_name : String,
  namespace_uri : String,
) -> Bool {
  self.process_exact_names.contains(element_name) ||
  self.process_wildcard_namespaces.contains(namespace_uri)
}

///|
fn MceProcessor::resolve_prefix(
  self : MceProcessor,
  prefix : String,
  directive : String,
) -> String raise DocxError {
  if !is_xml_ncname(prefix) {
    mce_mismatch(directive + " contains an invalid namespace prefix")
  }
  match self.namespaces.get(prefix) {
    Some(namespace_uri) if namespace_uri != MCE_NAMESPACE_URI => namespace_uri
    Some(_) => {
      mce_mismatch(directive + " cannot name the MCE namespace")
      ""
    }
    None => {
      mce_mismatch(directive + " contains an unbound namespace prefix")
      ""
    }
  }
}

///|
fn MceProcessor::apply_namespace_declarations(
  self : MceProcessor,
  element : XmlElement,
) -> Array[MceNamespaceChange] raise DocxError {
  let changes : Array[MceNamespaceChange] = []
  for name, namespace_uri in element.attributes {
    guard mce_expanded_namespace_is(name, XMLNS_NAMESPACE_URI) else { continue }
    guard name.rev_find("}") is Some(close) else {
      raise InvalidXml(message="invalid retained XML namespace declaration")
    }
    let local_start = close + 1
    self.budget.charge_derived_chars(name.length() - local_start)
    let declaration_name = name[local_start:].to_owned()
    let prefix = if declaration_name == "xmlns" { "" } else { declaration_name }
    self.budget.charge_namespace_bindings(2)
    changes.push({ prefix, previous: self.namespaces.get(prefix) })
    self.namespaces[prefix] = namespace_uri
  }
  changes
}

///|
fn MceProcessor::add_ignorable_namespaces(
  self : MceProcessor,
  value : String,
) -> Array[String] raise DocxError {
  let additions : Array[String] = []
  for prefix in mce_split_tokens(value, self.budget) {
    let namespace_uri = self.resolve_prefix(prefix, "Ignorable")
    self.budget.charge_namespace_bindings(1)
    increment_mce_count(self.ignorable_namespaces, namespace_uri)
    additions.push(namespace_uri)
  }
  additions
}

///|
fn MceProcessor::add_process_content_names(
  self : MceProcessor,
  value : String,
) -> Array[MceProcessAddition] raise DocxError {
  let additions : Array[MceProcessAddition] = []
  for token in mce_split_tokens(value, self.budget) {
    guard token.find(":") is Some(colon) &&
      colon > 0 &&
      colon + 1 < token.length() &&
      !token[colon + 1:].contains(":") else {
      mce_mismatch("ProcessContent contains an invalid name pair")
    }
    self.budget.charge_derived_chars(token.length() - 1)
    let prefix = token[:colon].to_owned()
    let local_name = token[colon + 1:].to_owned()
    if local_name != "*" && !is_xml_ncname(local_name) {
      mce_mismatch("ProcessContent contains an invalid local name")
    }
    let namespace_uri = self.resolve_prefix(prefix, "ProcessContent")
    if !self.namespace_is_ignorable(namespace_uri) {
      mce_mismatch("ProcessContent names a namespace that is not ignorable")
    }
    self.budget.charge_namespace_bindings(1)
    if local_name == "*" {
      increment_mce_count(self.process_wildcard_namespaces, namespace_uri)
      additions.push({ key: namespace_uri, wildcard: true })
    } else {
      let expanded = mce_expanded_name(namespace_uri, local_name, self.budget)
      increment_mce_count(self.process_exact_names, expanded)
      additions.push({ key: expanded, wildcard: false })
    }
  }
  additions
}

///|
fn MceProcessor::must_understand_is_satisfied(
  self : MceProcessor,
  value : String,
) -> Bool raise DocxError {
  let mut satisfied = true
  for prefix in mce_split_tokens(value, self.budget) {
    let namespace_uri = self.resolve_prefix(prefix, "MustUnderstand")
    if !self.application_understands(namespace_uri) {
      satisfied = false
    }
  }
  satisfied
}

///|
fn MceProcessor::enter_element(
  self : MceProcessor,
  element : XmlElement,
) -> MceElementScope raise DocxError {
  self.budget.charge_namespace_bindings(1)
  let namespace_changes = self.apply_namespace_declarations(element)
  let ignorable_additions = match element.attributes.get(MCE_IGNORABLE) {
    Some(value) => self.add_ignorable_namespaces(value)
    None => []
  }
  let process_additions = match element.attributes.get(MCE_PROCESS_CONTENT) {
    Some(value) => self.add_process_content_names(value)
    None => []
  }
  let must_understand_satisfied = match
    element.attributes.get(MCE_MUST_UNDERSTAND) {
    Some(value) => self.must_understand_is_satisfied(value)
    None => true
  }
  {
    namespace_changes,
    ignorable_additions,
    process_additions,
    must_understand_satisfied,
  }
}

///|
fn MceProcessor::leave_element(
  self : MceProcessor,
  scope : MceElementScope,
) -> Unit {
  for offset in 0..<scope.process_additions.length() {
    let addition = scope.process_additions[scope.process_additions.length() -
      offset -
      1]
    if addition.wildcard {
      decrement_mce_count(self.process_wildcard_namespaces, addition.key)
    } else {
      decrement_mce_count(self.process_exact_names, addition.key)
    }
  }
  for offset in 0..<scope.ignorable_additions.length() {
    decrement_mce_count(
      self.ignorable_namespaces,
      scope.ignorable_additions[scope.ignorable_additions.length() - offset - 1],
    )
  }
  for offset in 0..<scope.namespace_changes.length() {
    let change = scope.namespace_changes[scope.namespace_changes.length() -
      offset -
      1]
    match change.previous {
      Some(previous) => self.namespaces[change.prefix] = previous
      None => self.namespaces.remove(change.prefix)
    }
  }
}

///|
fn mce_require_must_understand(scope : MceElementScope) -> Unit raise DocxError {
  if !scope.must_understand_satisfied {
    mce_mismatch("MustUnderstand names an unsupported namespace")
  }
}

///|
fn MceProcessor::qualified_attribute_allowed_on_mce_element(
  self : MceProcessor,
  name : String,
) -> Bool raise DocxError {
  guard mce_namespace_from_expanded_name(name, self.budget)
    is Some(namespace_uri) else {
    return false
  }
  namespace_uri != XML_NAMESPACE_URI &&
  (
    namespace_uri == MCE_NAMESPACE_URI ||
    self.namespace_is_ignorable(namespace_uri)
  )
}

///|
fn MceProcessor::validate_alternate_content_attributes(
  self : MceProcessor,
  element : XmlElement,
) -> Unit raise DocxError {
  for name, _ in element.attributes {
    if mce_expanded_namespace_is(name, XMLNS_NAMESPACE_URI) {
      continue
    }
    if !self.qualified_attribute_allowed_on_mce_element(name) {
      mce_mismatch("AlternateContent has a disallowed attribute")
    }
  }
}

///|
fn MceProcessor::validate_choice_attributes(
  self : MceProcessor,
  element : XmlElement,
) -> String raise DocxError {
  let mut requires : String? = None
  for name, value in element.attributes {
    if mce_expanded_namespace_is(name, XMLNS_NAMESPACE_URI) {
      continue
    }
    if name == "Requires" {
      requires = Some(value)
    } else if !self.qualified_attribute_allowed_on_mce_element(name) {
      mce_mismatch("Choice has a disallowed attribute")
    }
  }
  match requires {
    Some(value) => value
    None => {
      mce_mismatch("Choice is missing Requires")
      ""
    }
  }
}

///|
fn MceProcessor::validate_fallback_attributes(
  self : MceProcessor,
  element : XmlElement,
) -> Unit raise DocxError {
  for name, _ in element.attributes {
    if mce_expanded_namespace_is(name, XMLNS_NAMESPACE_URI) {
      continue
    }
    if !self.qualified_attribute_allowed_on_mce_element(name) {
      mce_mismatch("Fallback has a disallowed attribute")
    }
  }
}

///|
fn MceProcessor::choice_is_supported(
  self : MceProcessor,
  requires : String,
) -> Bool raise DocxError {
  let prefixes = mce_split_tokens(requires, self.budget)
  if prefixes.is_empty() {
    mce_mismatch("Choice Requires must contain at least one prefix")
  }
  let mut supported = true
  for prefix in prefixes {
    let namespace_uri = self.resolve_prefix(prefix, "Choice Requires")
    if !self.application_understands(namespace_uri) {
      supported = false
    }
  }
  supported
}

///|
fn MceProcessor::filter_attributes(
  self : MceProcessor,
  element : XmlElement,
) -> @sorted_map.SortedMap[String, String] raise DocxError {
  let output : @sorted_map.SortedMap[String, String] = SortedMap([])
  for name, value in element.attributes {
    self.budget.charge_namespace_bindings(1)
    if mce_expanded_namespace_is(name, XMLNS_NAMESPACE_URI) {
      continue
    }
    match mce_namespace_from_expanded_name(name, self.budget) {
      Some(namespace_uri) if namespace_uri == MCE_NAMESPACE_URI => continue
      Some(namespace_uri) if self.namespace_is_ignorable(namespace_uri) &&
        !self.application_understands(namespace_uri) => continue
      _ => output[name] = value
    }
  }
  output
}

///|
fn MceProcessor::process_children(
  self : MceProcessor,
  children : Array[XmlNode],
) -> Array[XmlNode] raise DocxError {
  let output : Array[XmlNode] = []
  for child in children {
    self.budget.charge_namespace_bindings(1)
    match child {
      XmlText(value) => output.push(XmlText(value))
      XmlElement(element) => output.append(self.process_element(element))
    }
  }
  output
}

///|
fn MceProcessor::foreign_alternate_content_child_is_ignored(
  self : MceProcessor,
  element : XmlElement,
) -> Bool raise DocxError {
  let scope = self.enter_element(element)
  let ignored = match
    mce_namespace_from_expanded_name(element.name, self.budget) {
    Some(namespace_uri) =>
      self.namespace_is_ignorable(namespace_uri) &&
      !self.application_understands(namespace_uri) &&
      !self.element_matches_process_content(element.name, namespace_uri)
    None => false
  }
  self.leave_element(scope)
  ignored
}

///|
fn MceProcessor::process_choice(
  self : MceProcessor,
  element : XmlElement,
  select_if_supported : Bool,
) -> (Bool, Array[XmlNode]) raise DocxError {
  let scope = self.enter_element(element)
  let requires = self.validate_choice_attributes(element)
  let supported = self.choice_is_supported(requires)
  let selected = select_if_supported && supported
  let output = if selected {
    mce_require_must_understand(scope)
    self.process_children(element.children)
  } else {
    []
  }
  self.leave_element(scope)
  (selected, output)
}

///|
fn MceProcessor::process_fallback(
  self : MceProcessor,
  element : XmlElement,
  selected : Bool,
) -> Array[XmlNode] raise DocxError {
  let scope = self.enter_element(element)
  self.validate_fallback_attributes(element)
  let output = if selected {
    mce_require_must_understand(scope)
    self.process_children(element.children)
  } else {
    []
  }
  self.leave_element(scope)
  output
}

///|
fn MceProcessor::process_alternate_content(
  self : MceProcessor,
  element : XmlElement,
  scope : MceElementScope,
) -> Array[XmlNode] raise DocxError {
  self.validate_alternate_content_attributes(element)
  mce_require_must_understand(scope)
  let mut choices = 0
  let mut saw_fallback = false
  let mut selected = false
  let selected_content : Array[XmlNode] = []
  for child in element.children {
    match child {
      XmlText(value) =>
        if !mce_xml_whitespace_only(value) {
          mce_mismatch("AlternateContent contains non-whitespace text")
        }
      XmlElement(child_element) =>
        if child_element.name == MCE_CHOICE {
          if saw_fallback {
            mce_mismatch("Choice follows Fallback in AlternateContent")
          }
          choices = choices + 1
          let (choice_selected, content) = self.process_choice(
            child_element,
            !selected,
          )
          if choice_selected {
            selected = true
            selected_content.append(content)
          }
        } else if child_element.name == MCE_FALLBACK {
          if saw_fallback {
            mce_mismatch("AlternateContent has multiple Fallback elements")
          }
          saw_fallback = true
          if !selected {
            selected = true
            selected_content.append(self.process_fallback(child_element, true))
          } else {
            ignore(self.process_fallback(child_element, false))
          }
        } else if mce_namespace_from_expanded_name(
            child_element.name,
            self.budget,
          ) ==
          Some(MCE_NAMESPACE_URI) {
          mce_mismatch("AlternateContent has an unexpected MCE child")
        } else if !self.foreign_alternate_content_child_is_ignored(
            child_element,
          ) {
          mce_mismatch("AlternateContent has a non-ignorable foreign child")
        }
    }
  }
  if choices == 0 {
    mce_mismatch("AlternateContent has no Choice element")
  }
  selected_content
}

///|
fn MceProcessor::process_element(
  self : MceProcessor,
  element : XmlElement,
) -> Array[XmlNode] raise DocxError {
  let scope = self.enter_element(element)
  if element.name == MCE_ALTERNATE_CONTENT {
    let output = self.process_alternate_content(element, scope)
    self.leave_element(scope)
    return output
  }
  match mce_namespace_from_expanded_name(element.name, self.budget) {
    Some(namespace_uri) if namespace_uri == MCE_NAMESPACE_URI =>
      mce_mismatch("Choice, Fallback, or unknown MCE element is misplaced")
    Some(namespace_uri) if self.namespace_is_ignorable(namespace_uri) &&
      !self.application_understands(namespace_uri) => {
      if self.element_matches_process_content(element.name, namespace_uri) {
        if element.attributes.contains(MCE_XML_BASE) ||
          element.attributes.contains(MCE_XML_LANG) ||
          element.attributes.contains(MCE_XML_SPACE) {
          mce_mismatch(
            "an unwrapped ProcessContent element has xml:base, xml:lang, or xml:space",
          )
        }
        mce_require_must_understand(scope)
        let output = self.process_children(element.children)
        self.leave_element(scope)
        return output
      }
      self.leave_element(scope)
      return []
    }
    _ => ()
  }
  mce_require_must_understand(scope)
  let attributes = self.filter_attributes(element)
  let children = self.process_children(element.children)
  let output_element : XmlElement = { name: element.name, attributes, children }
  self.leave_element(scope)
  [XmlElement(output_element)]
}

///|
fn process_markup_compatibility(
  root : XmlElement,
  budget : XmlReadBudget,
  application_namespaces : Array[String],
) -> XmlElement raise DocxError {
  let understood : @sorted_map.SortedMap[String, Bool] = SortedMap([])
  for namespace_uri in application_namespaces {
    budget.charge_namespace_bindings(1)
    understood[namespace_uri] = true
  }
  let processor = MceProcessor::{
    budget,
    application_namespaces: understood,
    namespaces: SortedMap([("xml", XML_NAMESPACE_URI)]),
    ignorable_namespaces: SortedMap([]),
    process_exact_names: SortedMap([]),
    process_wildcard_namespaces: SortedMap([]),
  }
  let output = processor.process_element(root)
  let mut document_root : XmlElement? = None
  for node in output {
    match node {
      XmlText(value) =>
        if !mce_xml_whitespace_only(value) {
          mce_mismatch("processing did not produce a single document element")
        }
      XmlElement(element) =>
        if document_root is Some(_) {
          mce_mismatch("processing produced multiple document elements")
        } else {
          document_root = Some(element)
        }
    }
  }
  match document_root {
    Some(element) => element
    None => {
      mce_mismatch("processing produced no document element")
      xml_element("")
    }
  }
}

///|
/// Strictly parses UTF-8 XML, preserves namespace scope long enough to apply
/// ECMA-376 Part 3 Markup Compatibility processing, and returns the processed
/// single-root tree. The markup configuration is empty; callers provide the
/// namespaces their application understands.
pub fn read_xml_bytes_strict_mce_limited(
  source : BytesView,
  budget : XmlReadBudget,
  application_namespaces : Array[String],
) -> XmlElement raise DocxError {
  budget.charge_source(source.length())
  let text = @utf8.decode(source, ignore_bom=true) catch {
    _ => raise InvalidXml(message="XML source is not valid UTF-8")
  }
  let root = read_xml_string_with_mode(
    text,
    Map([]),
    true,
    Some(budget),
    true,
    Some(Utf8),
    true,
  )
  process_markup_compatibility(root, budget, application_namespaces)
}
