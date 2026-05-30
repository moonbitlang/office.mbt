///|
fn pdf_metadata_xml_string_of_name(
  name : @metadata.PdfMetadataXmlName,
) -> String {
  "NAME |" + name.uri + "| |" + name.local_name + "|"
}

///|
fn pdf_metadata_xml_string_of_attribute(
  attribute : @metadata.PdfMetadataXmlAttribute,
) -> String {
  "ATTRNAME |" +
  attribute.name.uri +
  "| |" +
  attribute.name.local_name +
  "|, STR {" +
  attribute.value +
  "}"
}

///|
fn pdf_metadata_xml_string_of_attributes(
  attributes : ArrayView[@metadata.PdfMetadataXmlAttribute],
) -> String {
  let mut output = ""
  for attribute in attributes {
    output = output + " " + pdf_metadata_xml_string_of_attribute(attribute)
  }
  output
}

///|
fn pdf_metadata_xml_string_of_trees(
  trees : ArrayView[@metadata.PdfMetadataXmlTree],
) -> String {
  let mut output = ""
  for tree in trees {
    output = output + " " + pdf_metadata_string_of_xmltree(tree)
  }
  output
}

///|
/// Return cpdfmetadata's debug string representation for an XML tree.
pub fn pdf_metadata_string_of_xmltree(
  tree : @metadata.PdfMetadataXmlTree,
) -> String {
  match tree {
    PdfMetadataXmlData(data) => "D {" + data + "}"
    PdfMetadataXmlElement(tag, children) =>
      "E (" +
      pdf_metadata_xml_string_of_name(tag.name) +
      ", ATTRIBUTES {" +
      pdf_metadata_xml_string_of_attributes(tag.attributes) +
      "}, " +
      pdf_metadata_xml_string_of_trees(children) +
      ")"
  }
}

///|
/// Source-spelled compatibility alias for cpdfmetadata's `string_of_xmltree`.
pub fn pdf_string_of_xmltree(tree : @metadata.PdfMetadataXmlTree) -> String {
  pdf_metadata_string_of_xmltree(tree)
}

///|
fn pdf_metadata_xml_collect_list_items(
  tree : @metadata.PdfMetadataXmlTree,
) -> String {
  match tree {
    PdfMetadataXmlElement(tag, children) =>
      if tag.name.uri == @metadata.pdf_metadata_rdf_namespace &&
        (
          tag.name.local_name == "Alt" ||
          tag.name.local_name == "Seq" ||
          tag.name.local_name == "Bag"
        ) {
        let values : Array[String] = []
        for child in children {
          match child {
            PdfMetadataXmlElement(li_tag, [PdfMetadataXmlData(data)]) =>
              if li_tag.name.uri == @metadata.pdf_metadata_rdf_namespace &&
                li_tag.name.local_name == "li" {
                values.push(data)
              }
            _ => ()
          }
        }
        pdf_metadata_combine_list_items(values)
      } else {
        ""
      }
    _ => ""
  }
}

///|
fn pdf_metadata_xml_collect_list_items_all(
  trees : ArrayView[@metadata.PdfMetadataXmlTree],
) -> String? {
  for tree in trees {
    match tree {
      PdfMetadataXmlElement(_, _) =>
        break Some(pdf_metadata_xml_collect_list_items(tree))
      _ => ()
    }
  } nobreak {
    None
  }
}

///|
fn pdf_metadata_xmltree_attribute_data_for(
  uri : String,
  name : String,
  attributes : ArrayView[@metadata.PdfMetadataXmlAttribute],
) -> String? {
  for attribute in attributes {
    if attribute.name.uri == uri && attribute.name.local_name == name {
      break Some(attribute.value)
    }
  } nobreak {
    None
  }
}

///|
/// Return the first XML-tree value matching a namespace URI and local name,
/// following cpdfmetadata's `get_data_for` tree traversal.
pub fn pdf_metadata_xmltree_get_data_for(
  xml_uri : String,
  name : String,
  tree : @metadata.PdfMetadataXmlTree,
) -> String? {
  match tree {
    PdfMetadataXmlData(_) => None
    PdfMetadataXmlElement(tag, children) =>
      if children.length() == 0 {
        pdf_metadata_xmltree_attribute_data_for(xml_uri, name, tag.attributes)
      } else if tag.name.uri == xml_uri && tag.name.local_name == name {
        match children {
          [PdfMetadataXmlData(data)] => Some(data)
          _ => pdf_metadata_xml_collect_list_items_all(children)
        }
      } else {
        for child in children {
          match pdf_metadata_xmltree_get_data_for(xml_uri, name, child) {
            Some(value) => break Some(value)
            None => ()
          }
        } nobreak {
          None
        }
      }
  }
}

///|
/// Source-spelled compatibility alias for cpdfmetadata's `get_data_for`.
pub fn pdf_get_data_for(
  xml_uri : String,
  name : String,
  tree : @metadata.PdfMetadataXmlTree,
) -> String? {
  pdf_metadata_xmltree_get_data_for(xml_uri, name, tree)
}

///|
fn pdf_metadata_xml_escaped_text(text : String) -> String {
  text
  .replace(old="&", new="&amp;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
}

///|
fn pdf_metadata_xml_escaped_attribute(text : String) -> String {
  pdf_metadata_xml_escaped_text(text)
  .replace(old="\"", new="&quot;")
  .replace(old="'", new="&apos;")
}

///|
fn pdf_metadata_xml_qualified_name(
  name : @metadata.PdfMetadataXmlName,
) -> String {
  match name.prefix {
    Some(prefix) if prefix != "" => prefix + ":" + name.local_name
    _ => name.local_name
  }
}

///|
fn pdf_metadata_xmltree_push_bytes(
  output : Array[String],
  tree : @metadata.PdfMetadataXmlTree,
) -> Unit {
  match tree {
    PdfMetadataXmlData(data) => output.push(pdf_metadata_xml_escaped_text(data))
    PdfMetadataXmlElement(tag, children) => {
      output.push("<")
      output.push(pdf_metadata_xml_qualified_name(tag.name))
      for attribute in tag.attributes {
        output.push(" ")
        output.push(pdf_metadata_xml_qualified_name(attribute.name))
        output.push("=\"")
        output.push(pdf_metadata_xml_escaped_attribute(attribute.value))
        output.push("\"")
      }
      if children.length() == 0 {
        output.push("/>")
      } else {
        output.push(">")
        for child in children {
          pdf_metadata_xmltree_push_bytes(output, child)
        }
        output.push("</")
        output.push(pdf_metadata_xml_qualified_name(tag.name))
        output.push(">")
      }
    }
  }
}

///|
/// Serialize a metadata XML-tree document to UTF-8 XML bytes.
///
/// Like cpdfmetadata's `bytes_of_xmltree`, this omits an XML declaration.
pub fn pdf_metadata_bytes_of_xmltree(
  document : @metadata.PdfMetadataXmlDocument,
) -> @core.PdfBytes {
  let output : Array[String] = []
  match document.dtd {
    Some(dtd) if dtd != "" => output.push(dtd)
    _ => ()
  }
  pdf_metadata_xmltree_push_bytes(output, document.tree)
  @utf8.encode(output.join(""))
}

///|
/// Source-spelled compatibility alias for cpdfmetadata's `bytes_of_xmltree`.
pub fn pdf_bytes_of_xmltree(
  document : @metadata.PdfMetadataXmlDocument,
) -> @core.PdfBytes {
  pdf_metadata_bytes_of_xmltree(document)
}
