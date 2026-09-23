// Added for office.mbt: preserve the upstream method-call API explicitly.
// Make deprecated implicit trait-method promotions explicit on current MoonBit.

///|
pub extend Comment with @debug.Debug::{to_repr}

///|
pub extend Comment with Eq::{not_equal, equal}

///|
pub extend CommentAuthor with @debug.Debug::{to_repr}

///|
pub extend CommentAuthor with Eq::{not_equal, equal}

///|
pub extend CommentAuthorList with @debug.Debug::{to_repr}

///|
pub extend CommentAuthorList with Eq::{not_equal, equal}

///|
pub extend CommentList with @debug.Debug::{to_repr}

///|
pub extend CommentList with Eq::{not_equal, equal}

///|
pub extend CommentPos with @debug.Debug::{to_repr}

///|
pub extend CommentPos with Eq::{not_equal, equal}

///|
pub extend CommentsError with @debug.Debug::{to_repr}

///|
pub extend CommentsError with Eq::{not_equal, equal}

///|
pub extend CommentsError with Show::{to_string, output}
