///|
/// Canonical declaration blocks carried by schema v14 artifacts.
pub(all) struct ViewTransitionBlock {
  group : String
  declarations : Array[(String, Array[String])]
} derive(Eq, Debug)

///|
pub extend ViewTransitionBlock with Eq::{equal, not_equal}

///|
pub extend ViewTransitionBlock with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub struct CompiledViewTransitionClass {
  name : String
  blocks : Array[ViewTransitionBlock]
  globals : Array[GlobalRule]
  diagnostics : Array[Diagnostic]
}

///|
let view_transition_groups : Array[String] = [
  "group", "image-pair", "old", "new",
]

///|
pub fn render_view_transition_css(
  css_name : String,
  blocks : Array[ViewTransitionBlock],
) -> String {
  blocks
  .map(block => {
    "::view-transition-" +
    block.group +
    "(*." +
    css_name +
    "){" +
    block.declarations
    .map(declaration => {
      declaration.1.map(value => declaration.0 + ":" + value).join(";")
    })
    .join(";") +
    "}"
  })
  .join("")
}

///|
pub fn valid_view_transition_blocks(
  blocks : Array[ViewTransitionBlock],
) -> Bool {
  let properties = application_order_properties().map(property => {
    dashify(application_order_emitted_property(property))
  })
  let mut previous = -1
  for block in blocks {
    let rank = view_transition_groups.search_by(group => group == block.group)
    guard rank is Some(rank) &&
      rank > previous &&
      !block.declarations.is_empty() else {
      return false
    }
    previous = rank
    for (property, values) in block.declarations {
      if !properties.contains(property) ||
        values.is_empty() ||
        values.any(value => {
          value.trim().is_empty() ||
          canonical_css_value(value) != value ||
          !css_value_diagnostics(value, property).is_empty()
        }) {
        return false
      }
    }
  }
  true
}

///|
pub fn compile_view_transition_class(
  module_name : String,
  definition : @ir.ViewTransitionClassDefinition,
) -> CompiledViewTransitionClass {
  let blocks : Array[ViewTransitionBlock] = []
  let globals : Array[GlobalRule] = []
  let diagnostics : Array[Diagnostic] = []
  let groups : Array[String] = []
  for style in definition.styles {
    if !view_transition_groups.contains(style.group) ||
      groups.contains(style.group) {
      diagnostics.push(
        error_diagnostic(
          "STYLE_VIEW_TRANSITION_GROUP",
          "View-transition groups must be unique group, image-pair, old, or new blocks",
          context=Some(diagnostic_context(module_name)),
        ),
      )
      continue
    }
    groups.push(style.group)
    let declarations : Array[(String, Array[String])] = []
    for declaration in style.declarations {
      let dynamic = match declaration.value {
        Dynamic(_, _, _) => true
        Expression(value) => value.is_dynamic()
        ExpressionFallbacks(values) => values.any(value => value.is_dynamic())
        _ => false
      }
      let restriction = if !declaration.conditions.is_empty() {
        Some(
          (
            "STYLE_VIEW_TRANSITION_CONDITION", "View-transition styles cannot contain conditions",
          ),
        )
      } else if dynamic {
        Some(
          (
            "STYLE_VIEW_TRANSITION_DYNAMIC", "View-transition styles cannot contain dynamic slots",
          ),
        )
      } else if declaration.value is Clear {
        Some(
          (
            "STYLE_VIEW_TRANSITION_CLEAR", "View-transition styles cannot contain Clear declarations",
          ),
        )
      } else if declaration.unsafe_raw ||
        !application_order_properties().contains(declaration.property) {
        Some(
          (
            "STYLE_VIEW_TRANSITION_PROPERTY", "View-transition styles require reviewed typed properties",
          ),
        )
      } else {
        None
      }
      if restriction is Some((code, message)) {
        diagnostics.push(
          error_diagnostic(
            code,
            message,
            source=declaration.source,
            context=Some(diagnostic_context(module_name)),
          ),
        )
        continue
      }
      let issues = authored_value_diagnostics(
        declaration,
        definition.name + "." + style.group,
      )
      for issue in issues {
        diagnostics.push(issue)
      }
      if validate_declaration(declaration) is Some(issue) {
        diagnostics.push(issue)
        continue
      }
      if !issues.is_empty() {
        continue
      }
      declarations.push(
        (
          dashify(application_order_emitted_property(declaration.property)),
          normalized_values(declaration.value),
        ),
      )
      for animation in declaration.value.animations() {
        globals.push(animation_global(animation))
      }
    }
    if !declarations.is_empty() {
      blocks.push({ group: style.group, declarations, })
    }
  }
  blocks.sort_by((left, right) => {
    view_transition_groups.search_by(group => group == left.group).unwrap() -
    view_transition_groups.search_by(group => group == right.group).unwrap()
  })
  if !diagnostics.is_empty() {
    return { name: definition.name, blocks: [], globals: [], diagnostics, }
  }
  if !blocks.is_empty() {
    let name = view_transition_class_name(module_name, definition.name)
    let css = render_view_transition_css(name, blocks)
    globals.push({
      kind: "view-transition",
      name,
      css,
      digest: sha256_digest(css),
    })
  }
  {
    name: definition.name,
    blocks,
    globals: sort_and_dedupe_globals(globals),
    diagnostics,
  }
}
