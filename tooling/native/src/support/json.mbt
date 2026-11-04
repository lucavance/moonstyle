///|
pub suberror ToolError {
  ToolError(String, String)
}

///|
pub fn[T] reject(code : String, message : String) -> T raise ToolError {
  raise ToolError(code, message)
}

///|
pub fn get(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
pub fn string(value : Json) -> String raise {
  guard value is String(text) else { reject("STYLE_JSON", "Expected a string") }
  text
}

///|
pub fn text(value : Json, key : String) -> String raise {
  string(get(value, key))
}

///|
pub fn array(value : Json) -> Array[Json] raise {
  guard value is Array(items) else { reject("STYLE_JSON", "Expected an array") }
  items
}

///|
pub fn fields(value : Json) -> Map[String, Json] raise {
  guard value is Object(items) else {
    reject("STYLE_JSON", "Expected an object")
  }
  items
}

///|
pub fn flag(value : Json, key : String) -> Bool {
  get(value, key) is True
}

///|
pub fn copy(value : Json) -> Map[String, Json] raise {
  fields(value).copy()
}

///|
pub fn exact(value : Json, names : Array[String], label : String) -> Unit raise {
  let actual = fields(value).keys().collect()
  actual.sort()
  let expected = names.copy()
  expected.sort()
  guard actual == expected else {
    reject(
      "STYLE_PROJECT_SCHEMA",
      label + " must contain exactly: " + expected.join(", "),
    )
  }
}

///|
pub fn hash(value : String) -> String {
  hash_bytes(@utf8.encode(value))
}

///|
pub fn hash_bytes(value : Bytes) -> String {
  "sha256:" + @crypto.bytes_to_hex_string(@crypto.sha256(value))
}

///|
pub fn quote(value : String) -> String {
  Json::string(value).stringify(escape_slash=false)
}

///|
/// Canonical JSON keeps grammar identities independent of map insertion order.
pub fn canonical(value : Json) -> String {
  match value {
    Object(fields) => {
      let keys = fields.keys().collect()
      keys.sort_by((a, b) => a[:].lexical_compare(b[:]))
      "{" +
      keys.map(key => quote(key) + ":" + canonical(fields[key])).join(",") +
      "}"
    }
    Array(items) => "[" + items.map(canonical).join(",") + "]"
    _ => value.stringify(escape_slash=false)
  }
}
