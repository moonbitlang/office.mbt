// Added for office.mbt: preserve the upstream method-call API explicitly.
// Make deprecated implicit trait-method promotions explicit on current MoonBit.

///|
pub extend QName with @debug.Debug::{to_repr}

///|
pub extend QName with Eq::{not_equal, equal}

///|
pub extend QName with Hash::{hash, hash_combine}

///|
pub extend QName with Show::{to_string, output}

///|
pub extend XmlElement with @debug.Debug::{to_repr}

///|
pub extend XmlElement with Eq::{not_equal, equal}

///|
pub extend XmlElement with Show::{to_string, output}

///|
pub extend XmlError with @debug.Debug::{to_repr}

///|
pub extend XmlError with Eq::{not_equal, equal}

///|
pub extend XmlError with Show::{to_string, output}

///|
pub extend XmlEvent with @debug.Debug::{to_repr}

///|
pub extend XmlEvent with Show::{to_string, output}

///|
pub extend XmlNode with @debug.Debug::{to_repr}

///|
pub extend XmlNode with Eq::{not_equal, equal}

///|
pub extend XmlNode with Show::{to_string, output}
