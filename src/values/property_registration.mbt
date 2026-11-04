///|
/// Explicit CSS registration metadata. Unregistered variables retain ordinary
/// custom-property inheritance and substitution behavior.
pub(all) struct PropertyRegistration {
  inherits : Bool
} derive(Eq, Debug)

///|
/// Value categories supported by the reviewed @property registration API.
pub trait RegisterableValue {}

///|
pub impl RegisterableValue for Color

///|
pub impl RegisterableValue for Length

///|
pub impl RegisterableValue for Number

///|
fn registration_numeric(css : String, category : String) -> Bool {
  let units = match category {
    "number" => [""]
    "percentage" => ["%"]
    "angle" => ["deg", "grad", "rad", "turn"]
    "length" => ["px", "cm", "mm", "q", "in", "pc", "pt"]
    _ => []
  }
  if css == "0" && category == "length" {
    return true
  }
  units.any(unit => {
    if !css.has_suffix(unit) {
      return false
    }
    let number = css[:css.length() - unit.length()].to_owned()
    number
    .iter()
    .all(ch => {
      (ch >= '0' && ch <= '9') ||
      ch == '.' ||
      ch == '+' ||
      ch == '-' ||
      ch == 'e' ||
      ch == 'E'
    }) &&
    numeric_part(number, "number") is Some(_)
  })
}

///|
fn registration_color_initial(css : String) -> Bool {
  let contextual = "currentcolor accentcolor accentcolortext activetext buttonborder buttonface buttontext canvas canvastext field fieldtext graytext highlight highlighttext linktext mark marktext selecteditem selecteditemtext visitedtext"
  if named_color(css).to_css() == css {
    return !contextual.split(" ").any(name => name == css)
  }
  if css.has_prefix("#") {
    return try {
      ignore(hex_color(css))
      true
    } catch {
      _ => false
    }
  }
  guard css.find("(") is Some(open) && css.has_suffix(")") else { return false }
  let name = css[:open].to_owned()
  if ![
      "rgb", "rgba", "hsl", "hsla", "hwb", "lab", "lch", "oklab", "oklch", "color",
    ].contains(name) {
    return false
  }
  let body = css[open + 1:css.length() - 1].to_owned()
  let parts = body.split("/").to_array()
  if parts.length() > 2 {
    return false
  }
  let comma = body.contains(",")
  if comma &&
    (parts.length() != 1 || !["rgb", "rgba", "hsl", "hsla"].contains(name)) {
    return false
  }
  let channels = if comma {
    parts[0].split(",").map(value => value.trim().to_owned()).to_array()
  } else {
    parts[0]
    .split(" ")
    .filter(value => !value.is_empty())
    .map(value => value.to_owned())
    .to_array()
  }
  let offset = if name == "color" { 1 } else { 0 }
  if offset == 1 &&
    (
      channels.is_empty() ||
      ![
        "srgb", "srgb-linear", "display-p3", "a98-rgb", "prophoto-rgb", "rec2020",
        "xyz-d50", "xyz-d65",
      ].contains(channels[0])
    ) {
    return false
  }
  let legacy_alpha = comma &&
    (name == "rgba" || name == "hsla") &&
    parts.length() == 1 &&
    channels.length() == 4
  if channels.length() != 3 + offset && !legacy_alpha {
    return false
  }
  for index in offset..<channels.length() {
    let value = channels[index]
    let hue = ((name == "hsl" || name == "hsla" || name == "hwb") && index == 0) ||
      ((name == "lch" || name == "oklch") && index == 2)
    let percentage_required = (name == "hsl" || name == "hsla" || name == "hwb") &&
      index > 0 &&
      index < 3
    let valid = if hue {
      registration_numeric(value, "number") ||
      registration_numeric(value, "angle")
    } else if percentage_required {
      registration_numeric(value, "percentage")
    } else {
      registration_numeric(value, "number") ||
      registration_numeric(value, "percentage")
    }
    if !valid {
      return false
    }
  }
  parts.length() == 1 ||
  ({
    let alpha = parts[1].trim().to_owned()
    registration_numeric(alpha, "number") ||
    registration_numeric(alpha, "percentage")
  })
}

///|
/// Register before sharing the token with styles or themes. A registered
/// initial value must be independent of font, viewport, or other variables.
#warnings("-unused_trait_bound")
pub fn[T : RegisterableValue] Token::registered(
  self : Token[T],
  inherits~ : Bool = true,
) -> Token[T] {
  { ..self, variable: { ..self.variable, registration: Some({ inherits, }), }, }
}

///|
#warnings("-unused_trait_bound")
pub fn[T : RegisterableValue] DynamicSlot::registered(
  self : DynamicSlot[T],
  inherits~ : Bool = true,
) -> DynamicSlot[T] {
  { ..self, variable: { ..self.variable, registration: Some({ inherits, }), }, }
}

///|
/// Validate the deliberately narrow initial-value subset, including metadata
/// supplied through the low-level IR rather than the typed authoring API.
pub fn VarDefinition::registration_issue(self : VarDefinition) -> ValueIssue? {
  if self.registration is None {
    return None
  }
  let css = self.default_css.to_lower()
  let valid = match self.category {
    NumberCategory => registration_numeric(css, "number")
    LengthCategory => registration_numeric(css, "length")
    ColorCategory => registration_color_initial(css)
    _ => false
  }
  if valid {
    None
  } else {
    Some({
      code: "STYLE_PROPERTY_INITIAL_VALUE",
      label: "Registered initial values require a static color, absolute length, or finite number: " +
      self.name,
    })
  }
}

///|
pub extend PropertyRegistration with Eq::{equal, not_equal}

///|
pub extend PropertyRegistration with @debug.Debug::{to_repr}
