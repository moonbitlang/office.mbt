///|
let max_xml_mce_tokens = 4096

///|
let max_xml_mce_token_chars = 1024

///|
priv struct XmlMceName {
  namespace_id : Int
  local_name : String
}

///|
priv struct XmlMceExtensionName {
  namespace_uri : String
  local_name : String
} derive(Eq, Hash)

///|
priv struct XmlMceScopeDelta {
  ignorable_namespace_ids : Array[Int]
  process_content_keys : Array[MceProcessKey]
  process_generation_resets : Array[MceProcessGenerationReset]
}

///|
priv struct XmlMceScopeEntry {
  delta : XmlMceScopeDelta?
  must_understand_supported : Bool
}

///|
priv struct XmlMceContext {
  understood_namespaces : Set[String]
  extension_elements : Set[XmlMceExtensionName]
  ignorable_namespace_counts : Map[Int, Int]
  process_content : MceProcessTracker
  max_work_chars : Int
  mut work_chars : Int
}

///|
fn XmlMceContext::new(
  understood_namespaces : ArrayView[String],
  extension_elements : ArrayView[(String, String)],
  max_work_chars : Int,
) -> XmlMceContext {
  let understood : Set[String] = Set([])
  for namespace_uri in understood_namespaces {
    understood.add(namespace_uri)
  }
  let extensions : Set[XmlMceExtensionName] = Set([])
  for extension in extension_elements {
    let (namespace_uri, local_name) = extension
    extensions.add({ namespace_uri, local_name })
  }
  {
    understood_namespaces: understood,
    extension_elements: extensions,
    ignorable_namespace_counts: Map([]),
    process_content: MceProcessTracker::new(),
    max_work_chars,
    work_chars: 0,
  }
}

///|
fn XmlMceContext::is_extension_element(
  self : XmlMceContext,
  namespace_uri : String,
  local_name : String,
) -> Bool {
  self.extension_elements.contains({ namespace_uri, local_name })
}

///|
fn XmlMceContext::charge(
  self : XmlMceContext,
  value : StringView,
) -> Unit raise ParseXmlError {
  if value.length() > self.max_work_chars - self.work_chars {
    raise InvalidXml(msg="MCE directive work limit exceeded")
  }
  self.work_chars += value.length()
}

///|
fn XmlMceContext::understands(
  self : XmlMceContext,
  namespace_uri : StringView,
) -> Bool {
  self.understood_namespaces.contains(namespace_uri.to_owned())
}

///|
fn XmlMceContext::add_ignorable(
  self : XmlMceContext,
  namespace_id : Int,
) -> Unit {
  self.ignorable_namespace_counts[namespace_id] = self.ignorable_namespace_counts.get_or_default(
      namespace_id, 0,
    ) +
    1
}

///|
fn XmlMceContext::is_ignorable(
  self : XmlMceContext,
  namespace_id : Int,
) -> Bool {
  self.ignorable_namespace_counts.get_or_default(namespace_id, 0) > 0
}

///|
fn XmlMceContext::is_effectively_ignorable(
  self : XmlMceContext,
  namespace_id : Int,
  namespace_uri : StringView,
) -> Bool {
  self.is_ignorable(namespace_id) && !self.understands(namespace_uri)
}

///|
fn XmlMceContext::processes(self : XmlMceContext, name : XmlMceName) -> Bool {
  self.process_content.processes(name.namespace_id, name.local_name)
}

///|
fn XmlMceContext::leave_scope(
  self : XmlMceContext,
  delta : XmlMceScopeDelta?,
) -> Unit {
  guard delta is Some(delta) else { return }
  self.process_content.leave(
    delta.process_content_keys,
    delta.process_generation_resets,
  )
  for namespace_id in delta.ignorable_namespace_ids {
    let remaining = self.ignorable_namespace_counts.get_or_default(
        namespace_id, 0,
      ) -
      1
    if remaining <= 0 {
      ignore(self.ignorable_namespace_counts.remove(namespace_id))
    } else {
      self.ignorable_namespace_counts[namespace_id] = remaining
    }
  }
}

///|
priv enum XmlMceBindingScope {
  BindingScope(Array[(String, String)], XmlMceBindingScope?)
}

///|
fn xml_mce_extend_bindings(
  parent : XmlMceBindingScope?,
  declarations : Array[(String, String)],
) -> XmlMceBindingScope? {
  if declarations.length() == 0 {
    parent
  } else {
    Some(BindingScope(declarations, parent))
  }
}

///|
priv struct XmlMceProjectionState {
  active : Bool
  scope_delta : XmlMceScopeDelta?
  pending_bindings : XmlMceBindingScope?
  is_alternate_content : Bool
  mut alternate_choice_seen : Bool
  mut alternate_fallback_seen : Bool
  mut alternate_selected : Bool
  opaque_descendants : Bool
}

///|
fn xml_mce_tokens(
  value : StringView,
  label : StringView,
  allow_empty? : Bool = true,
) -> Array[String] raise ParseXmlError {
  let normalized = collapse_schema_whitespace(value)
  if normalized == "" {
    if allow_empty {
      return []
    }
    raise InvalidXml(msg="MCE \{label.to_owned()} is empty")
  }
  let output : Array[String] = []
  for token in normalized.split(" ") {
    if token == "" || token.length() > max_xml_mce_token_chars {
      raise InvalidXml(msg="MCE \{label.to_owned()} is invalid")
    }
    if output.length() >= max_xml_mce_tokens {
      raise InvalidXml(msg="MCE \{label.to_owned()} token limit exceeded")
    }
    output.push(token.to_owned())
  }
  output
}

///|
fn xml_mce_resolve_prefix(
  scanner : XmlStartTagScanner,
  prefix : StringView,
  label : StringView,
) -> (String, Int) raise ParseXmlError {
  if !is_xml_ncname(prefix) {
    raise InvalidXml(msg="MCE \{label.to_owned()} prefix is invalid")
  }
  scanner.resolve_prefix_identity(prefix, false)
}

///|
fn xml_mce_expanded_name(
  scanner : XmlStartTagScanner,
  token : StringView,
  label : StringView,
) -> (String, XmlMceName) raise ParseXmlError {
  let parts = token.split(":").collect()
  if parts.length() != 2 ||
    !is_xml_ncname(parts[0]) ||
    (parts[1] != "*" && !is_xml_ncname(parts[1])) {
    raise InvalidXml(msg="MCE \{label.to_owned()} name is invalid")
  }
  let (namespace_uri, namespace_id) = xml_mce_resolve_prefix(
    scanner,
    parts[0],
    label,
  )
  (namespace_uri, { namespace_id, local_name: parts[1].to_owned() })
}

///|
fn xml_mce_enter_scope(
  scanner : XmlStartTagScanner,
  context : XmlMceContext,
) -> XmlMceScopeEntry raise ParseXmlError {
  let mut delta : XmlMceScopeDelta? = None
  let mut must_understand_supported = true
  match scanner.attribute(markup_compatibility_namespace, "Ignorable") {
    Some(value) => {
      context.charge(value)
      let reset_namespaces : Set[Int] = Set([])
      for prefix in xml_mce_tokens(value, "Ignorable") {
        let (namespace_uri, namespace_id) = xml_mce_resolve_prefix(
          scanner, prefix, "Ignorable",
        )
        if namespace_uri == "" ||
          namespace_uri == markup_compatibility_namespace {
          raise InvalidXml(msg="MCE Ignorable namespace is invalid")
        }
        context.add_ignorable(namespace_id)
        match delta {
          Some(value) => value.ignorable_namespace_ids.push(namespace_id)
          None =>
            delta = Some({
              ignorable_namespace_ids: [namespace_id],
              process_content_keys: [],
              process_generation_resets: [],
            })
        }
        if !reset_namespaces.contains(namespace_id) {
          reset_namespaces.add(namespace_id)
          let reset = context.process_content.reset(namespace_id)
          match delta {
            Some(value) => value.process_generation_resets.push(reset)
            None => ()
          }
        }
      }
    }
    None => ()
  }
  match scanner.attribute(markup_compatibility_namespace, "ProcessContent") {
    Some(value) => {
      context.charge(value)
      for token in xml_mce_tokens(value, "ProcessContent") {
        let (_, name) = xml_mce_expanded_name(scanner, token, "ProcessContent")
        if !context.is_ignorable(name.namespace_id) {
          raise InvalidXml(msg="MCE ProcessContent namespace is not ignorable")
        }
        let key = context.process_content.add(
          name.namespace_id,
          name.local_name,
        )
        match delta {
          Some(value) => value.process_content_keys.push(key)
          None =>
            delta = Some({
              ignorable_namespace_ids: [],
              process_content_keys: [key],
              process_generation_resets: [],
            })
        }
      }
    }
    None => ()
  }
  match scanner.attribute(markup_compatibility_namespace, "MustUnderstand") {
    Some(value) => {
      context.charge(value)
      for prefix in xml_mce_tokens(value, "MustUnderstand") {
        let (namespace_uri, _) = xml_mce_resolve_prefix(
          scanner, prefix, "MustUnderstand",
        )
        if namespace_uri == markup_compatibility_namespace ||
          !context.understands(namespace_uri) {
          must_understand_supported = false
        }
      }
    }
    None => ()
  }
  for directive in ["PreserveElements", "PreserveAttributes"] {
    match scanner.attribute(markup_compatibility_namespace, directive) {
      Some(value) => {
        context.charge(value)
        for token in xml_mce_tokens(value, directive) {
          let (_, name) = xml_mce_expanded_name(scanner, token, directive)
          if !context.is_ignorable(name.namespace_id) {
            raise InvalidXml(msg="MCE \{directive} namespace is not ignorable")
          }
        }
      }
      None => ()
    }
  }
  { delta, must_understand_supported }
}

///|
fn xml_mce_require_must_understand(
  entry : XmlMceScopeEntry,
) -> Unit raise ParseXmlError {
  if !entry.must_understand_supported {
    raise InvalidXml(msg="MCE MustUnderstand namespace is unsupported")
  }
}

///|
fn xml_mce_validate_container_attributes(
  scanner : XmlStartTagScanner,
  context : XmlMceContext,
  label : StringView,
  allow_requires : Bool,
) -> Unit raise ParseXmlError {
  for attribute in scanner.expanded_attribute_names() {
    if allow_requires &&
      attribute.namespace_uri == "" &&
      attribute.local_name == "Requires" {
      continue
    }
    if attribute.namespace_uri != xml_namespace_uri &&
      (
        attribute.namespace_uri == markup_compatibility_namespace ||
        context.is_ignorable(attribute.namespace_id)
      ) {
      continue
    }
    raise InvalidXml(msg="MCE \{label.to_owned()} has a disallowed attribute")
  }
}

///|
fn xml_mce_choice_supported(
  scanner : XmlStartTagScanner,
  context : XmlMceContext,
) -> Bool raise ParseXmlError {
  let requires = match scanner.attribute("", "Requires") {
    Some(value) => value
    None => raise InvalidXml(msg="MCE Choice is missing Requires")
  }
  context.charge(requires)
  let mut supported = true
  for prefix in xml_mce_tokens(requires, "Choice Requires", allow_empty=false) {
    let (namespace_uri, _) = xml_mce_resolve_prefix(
      scanner, prefix, "Choice Requires",
    )
    if namespace_uri == markup_compatibility_namespace {
      raise InvalidXml(msg="MCE Choice Requires namespace is invalid")
    }
    if !context.understands(namespace_uri) {
      supported = false
    }
  }
  supported
}

///|
fn xml_mce_namespace_attributes(
  scanner : XmlStartTagScanner,
  pending : XmlMceBindingScope?,
) -> String {
  guard pending is Some(_) else { return "" }
  let seen : Set[String] = Set([])
  for declaration in scanner.current_namespace_declarations() {
    let (prefix, _) = declaration
    seen.add(prefix)
  }
  let output = StringBuilder::new()
  let mut current = pending
  while current is Some(BindingScope(declarations, parent)) {
    for declaration in declarations {
      let (prefix, namespace_uri) = declaration
      if prefix == "xml" || seen.contains(prefix) {
        continue
      }
      seen.add(prefix)
      output.write_string(" xmlns")
      if prefix != "" {
        output.write_char(':')
        output.write_string(prefix)
      }
      output.write_string("=\"")
      output.write_string(escape_xml_attr(namespace_uri))
      output.write_char('"')
    }
    current = parent
  }
  output.to_string()
}

///|
fn trim_xml_mce_states(
  states : Array[XmlMceProjectionState],
  next_depth : Int,
  context : XmlMceContext,
) -> Unit raise ParseXmlError {
  while states.length() >= next_depth {
    let state = states.pop().unwrap()
    context.leave_scope(state.scope_delta)
    if state.is_alternate_content && !state.alternate_choice_seen {
      raise InvalidXml(msg="MCE AlternateContent has no Choice element")
    }
  }
}

///|
fn xml_mce_state_for_current_element(
  scanner : XmlStartTagScanner,
  states : Array[XmlMceProjectionState],
  context : XmlMceContext,
) -> XmlMceProjectionState raise ParseXmlError {
  let depth = scanner.depth()
  trim_xml_mce_states(states, depth, context)
  let parent = if depth > 1 {
    if states.length() != depth - 1 {
      raise InvalidXml(msg="MCE projection nesting is invalid")
    }
    Some(states[depth - 2])
  } else {
    None
  }
  match parent {
    Some(parent_state) if !parent_state.active =>
      return {
        active: false,
        scope_delta: None,
        pending_bindings: None,
        is_alternate_content: false,
        alternate_choice_seen: false,
        alternate_fallback_seen: false,
        alternate_selected: false,
        opaque_descendants: false,
      }
    _ => ()
  }
  match parent {
    Some(parent_state) if parent_state.opaque_descendants =>
      return {
        active: true,
        scope_delta: None,
        pending_bindings: None,
        is_alternate_content: false,
        alternate_choice_seen: false,
        alternate_fallback_seen: false,
        alternate_selected: false,
        opaque_descendants: true,
      }
    _ => ()
  }
  let declarations = scanner.current_namespace_declarations()
  let namespace_uri = scanner.namespace_uri().to_owned()
  let namespace_id = scanner.current_namespace_identity()
  let local_name = scanner.local_name().to_owned()
  if depth == 1 {
    if namespace_uri == markup_compatibility_namespace {
      raise InvalidXml(msg="MCE document element is invalid")
    }
    if context.is_extension_element(namespace_uri, local_name) {
      return {
        active: true,
        scope_delta: None,
        pending_bindings: None,
        is_alternate_content: false,
        alternate_choice_seen: false,
        alternate_fallback_seen: false,
        alternate_selected: false,
        opaque_descendants: true,
      }
    }
    let scope_entry = xml_mce_enter_scope(scanner, context)
    xml_mce_require_must_understand(scope_entry)
    return {
      active: true,
      scope_delta: scope_entry.delta,
      pending_bindings: None,
      is_alternate_content: false,
      alternate_choice_seen: false,
      alternate_fallback_seen: false,
      alternate_selected: false,
      opaque_descendants: false,
    }
  }
  let parent_state = parent.unwrap()
  if !parent_state.is_alternate_content &&
    namespace_uri != markup_compatibility_namespace &&
    context.is_extension_element(namespace_uri, local_name) {
    scanner.insert_current_attributes(
      xml_mce_namespace_attributes(scanner, parent_state.pending_bindings),
    )
    return {
      active: true,
      scope_delta: None,
      pending_bindings: None,
      is_alternate_content: false,
      alternate_choice_seen: false,
      alternate_fallback_seen: false,
      alternate_selected: false,
      opaque_descendants: true,
    }
  }
  let scope_entry = xml_mce_enter_scope(scanner, context)
  let mut active = parent_state.active
  let mut pending_bindings : XmlMceBindingScope? = None
  let mut is_alternate_content = false
  if parent_state.is_alternate_content {
    if namespace_uri == markup_compatibility_namespace && local_name == "Choice" {
      xml_mce_validate_container_attributes(scanner, context, "Choice", true)
      if parent_state.alternate_fallback_seen {
        raise InvalidXml(msg="MCE Choice follows Fallback")
      }
      parent_state.alternate_choice_seen = true
      let supported = xml_mce_choice_supported(scanner, context)
      active = !parent_state.alternate_selected && supported
      if active {
        parent_state.alternate_selected = true
        xml_mce_require_must_understand(scope_entry)
        scanner.unwrap_current_element()
        pending_bindings = xml_mce_extend_bindings(
          parent_state.pending_bindings,
          declarations,
        )
      } else {
        scanner.remove_current_subtree()
      }
    } else if namespace_uri == markup_compatibility_namespace &&
      local_name == "Fallback" {
      xml_mce_validate_container_attributes(scanner, context, "Fallback", false)
      if parent_state.alternate_fallback_seen {
        raise InvalidXml(
          msg="MCE AlternateContent has multiple Fallback elements",
        )
      }
      parent_state.alternate_fallback_seen = true
      active = !parent_state.alternate_selected
      if active {
        parent_state.alternate_selected = true
        xml_mce_require_must_understand(scope_entry)
        scanner.unwrap_current_element()
        pending_bindings = xml_mce_extend_bindings(
          parent_state.pending_bindings,
          declarations,
        )
      } else {
        scanner.remove_current_subtree()
      }
    } else if context.is_effectively_ignorable(namespace_id, namespace_uri) {
      if context.processes({ namespace_id, local_name }) {
        raise InvalidXml(msg="MCE AlternateContent child is invalid")
      }
      active = false
      scanner.remove_current_subtree()
    } else {
      raise InvalidXml(msg="MCE AlternateContent child is invalid")
    }
  } else if namespace_uri == markup_compatibility_namespace {
    if local_name != "AlternateContent" {
      raise InvalidXml(msg="MCE element is misplaced")
    }
    xml_mce_validate_container_attributes(
      scanner, context, "AlternateContent", false,
    )
    xml_mce_require_must_understand(scope_entry)
    scanner.unwrap_current_element()
    pending_bindings = xml_mce_extend_bindings(
      parent_state.pending_bindings,
      declarations,
    )
    is_alternate_content = true
  } else if context.is_effectively_ignorable(namespace_id, namespace_uri) {
    let name : XmlMceName = { namespace_id, local_name }
    if context.processes(name) {
      if scanner.attribute(xml_namespace_uri, "base") is Some(_) ||
        scanner.attribute(xml_namespace_uri, "lang") is Some(_) ||
        scanner.attribute(xml_namespace_uri, "space") is Some(_) {
        raise InvalidXml(
          msg="MCE ProcessContent element has an unsafe xml attribute",
        )
      }
      xml_mce_require_must_understand(scope_entry)
      scanner.unwrap_current_element()
      pending_bindings = xml_mce_extend_bindings(
        parent_state.pending_bindings,
        declarations,
      )
    } else {
      active = false
      scanner.remove_current_subtree()
    }
  } else {
    xml_mce_require_must_understand(scope_entry)
    scanner.insert_current_attributes(
      xml_mce_namespace_attributes(scanner, parent_state.pending_bindings),
    )
  }
  {
    active,
    scope_delta: scope_entry.delta,
    pending_bindings,
    is_alternate_content,
    alternate_choice_seen: false,
    alternate_fallback_seen: false,
    alternate_selected: false,
    opaque_descendants: context.is_extension_element(namespace_uri, local_name),
  }
}

///|
/// Applies ECMA-376 Markup Compatibility selection to an XML part and returns
/// its effective projection. Unsupported `Choice` branches and ignorable
/// subtrees are removed, selected `Choice`/`Fallback` and `ProcessContent`
/// wrappers are unwrapped, and namespace declarations from removed wrappers
/// are retained on promoted children. Processing is streaming, cancellable,
/// and bounded by `max_output_chars`. Application-defined `extension_elements`
/// and their descendants remain opaque: they are namespace-validated as XML,
/// but MCE directives on or inside their payload are preserved rather than
/// interpreted.
pub fn project_xml_markup_compatibility(
  xml : StringView,
  understood_namespaces : ArrayView[String],
  max_output_chars? : Int = 16 * 1024 * 1024,
  cancelled? : () -> Bool = () => false,
  extension_elements? : ArrayView[(String, String)] = [],
) -> String raise ParseXmlError {
  check_xml_cancelled(cancelled)
  if max_output_chars < 0 {
    raise InvalidXml(msg="MCE output limit is invalid")
  }
  let scanner = xml_start_tag_scanner_with_rewrites(
    xml,
    Map([]),
    Map([]),
    Map([]),
    Map([]),
    false,
    max_output_chars,
    cancelled~,
  )
  let context = XmlMceContext::new(
    understood_namespaces, extension_elements, max_output_chars,
  )
  let states : Array[XmlMceProjectionState] = []
  while scanner.next() {
    states.push(xml_mce_state_for_current_element(scanner, states, context))
  }
  trim_xml_mce_states(states, 1, context)
  scanner.finish_rewritten_xml()
}
