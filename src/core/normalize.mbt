///|
fn is_ascii_upper(code : Int32) -> Bool {
  code >= 65 && code <= 90
}

///|
fn is_ascii_lower(code : Int32) -> Bool {
  code >= 97 && code <= 122
}

///|
fn is_css_space(code : Int32) -> Bool {
  code == 32 || code == 9 || code == 10 || code == 13
}

///|
fn dashify(property : String) -> String {
  if property.has_prefix("--") {
    return property
  }
  let output = StringBuilder(size_hint=property.length() + 4)
  for i = 0; i < property.length(); i = i + 1 {
    let code = property.unsafe_get(i).to_int()
    if is_ascii_upper(code) {
      if i == 0 || is_ascii_lower(property.unsafe_get(i - 1).to_int()) {
        output.write_char('-')
      }
      output.write_char((code + 32).unsafe_to_char())
    } else {
      output.write_char(code.unsafe_to_char())
    }
  }
  output.to_string()
}

///|
fn is_url_open(value : String, index : Int32) -> Bool {
  if index < 3 || value.unsafe_get(index).to_int() != 40 {
    return false
  }
  if index > 3 {
    let previous = value.unsafe_get(index - 4).to_int()
    if is_ascii_upper(previous) ||
      is_ascii_lower(previous) ||
      (previous >= 48 && previous <= 57) ||
      previous == 45 ||
      previous == 95 ||
      previous == 92 ||
      previous >= 128 {
      return false
    }
  }
  let u = value.unsafe_get(index - 3).to_int()
  let r = value.unsafe_get(index - 2).to_int()
  let l = value.unsafe_get(index - 1).to_int()
  (u == 85 || u == 117) && (r == 82 || r == 114) && (l == 76 || l == 108)
}

///|
/// Normalize CSS syntax without changing resource identifiers or string data.
/// URL payloads are opaque, including their whitespace and escaped parentheses.
pub fn canonical_css_value(value : String) -> String {
  let trimmed = value.trim().to_owned()
  let output = StringBuilder(size_hint=trimmed.length())
  let mut pending_space = false
  let mut has_output = false
  let mut last_output = 0
  let mut quote = 0
  let mut escaped = false
  let mut in_url = false
  for i = 0; i < trimmed.length(); i = i + 1 {
    let code = trimmed.unsafe_get(i).to_int()
    if in_url || quote != 0 {
      output.write_char(code.unsafe_to_char())
      last_output = code
      if escaped {
        escaped = false
      } else if code == 92 {
        escaped = true
      } else if quote != 0 {
        if code == quote {
          quote = 0
        }
      } else if code == 34 || code == 39 {
        quote = code
      } else if code == 41 {
        in_url = false
      }
      continue
    }
    if code == 34 || code == 39 {
      if pending_space && has_output && last_output != 44 && last_output != 40 {
        output.write_char(' ')
      }
      pending_space = false
      quote = code
      output.write_char(code.unsafe_to_char())
      has_output = true
      last_output = code
    } else if is_css_space(code) {
      pending_space = true
    } else {
      let punctuation = code == 44 || code == 41
      let follows_punctuation = code == 40
      if pending_space &&
        has_output &&
        last_output != 44 &&
        last_output != 40 &&
        !punctuation &&
        !follows_punctuation {
        output.write_char(' ')
      }
      pending_space = false
      if code == 48 &&
        i + 1 < trimmed.length() &&
        trimmed.unsafe_get(i + 1).to_int() == 46 {
        let previous_is_digit = i > 0 &&
          ({
            let previous = trimmed.unsafe_get(i - 1).to_int()
            previous >= 48 && previous <= 57
          })
        if !previous_is_digit {
          continue
        }
      }
      output.write_char(code.unsafe_to_char())
      has_output = true
      last_output = code
      if code == 40 && is_url_open(trimmed, i) {
        in_url = true
      }
    }
  }
  output.to_string()
}
