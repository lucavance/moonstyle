///|
fn declaration_expressions(
  declaration : @ir.Declaration,
) -> Array[@values.Expression] {
  match declaration.value {
    Expression(value) => [value]
    ExpressionFallbacks(values) => values
    _ => []
  }
}

///|
fn expression_variable_diagnostics(
  registry : @ir.Registry,
) -> Array[@core.Diagnostic] {
  let expressions : Array[(String, @values.Expression, @ir.SourceSpan?)] = []
  for style_set in registry.styles {
    for namespace_ in style_set.namespaces {
      for declaration in namespace_.declarations {
        match declaration.value {
          Expression(value) =>
            expressions.push((declaration.property, value, declaration.source))
          ExpressionFallbacks(values) =>
            for value in values {
              expressions.push(
                (declaration.property, value, declaration.source),
              )
            }
          Animation(_) | AnimationList(_) =>
            for animation in declaration.value.animations() {
              for frame in animation.keyframes.frames {
                for value in frame.declarations {
                  for expression in value.expressions {
                    expressions.push((value.property, expression, value.source))
                  }
                }
              }
            }
          _ => ()
        }
      }
    }
  }
  let diagnostics = []
  for (property, expression, source) in expressions {
    for use_ in expression.variables() {
      let constraints = use_.constraints.copy()
      for constraint in expression.property_constraints(property) {
        if !constraints.contains(constraint) {
          constraints.push(constraint)
        }
      }
      for theme in registry.themes {
        for override_ in theme.overrides {
          if override_.name == use_.variable.definition.name {
            for
              issue in @values.expression_value_issues(
                constraints,
                override_.value_css,
              ) {
              diagnostics.push(
                @core.error_diagnostic(
                  issue.code,
                  "Invalid expression variable " +
                  override_.name +
                  " in theme " +
                  theme.name +
                  ": " +
                  issue.label,
                  source~,
                  context=Some(@core.diagnostic_context(registry.module_name)),
                ),
              )
            }
          }
        }
      }
    }
  }
  diagnostics
}

///|
fn legacy_grid_literal_matches(
  values : Array[String],
  declaration : @ir.Declaration,
) -> Bool {
  if ![
      "gridTemplateColumns", "gridTemplateRows", "gridAutoColumns", "gridAutoRows",
      "transform", "animationTimeline", "animationRangeStart", "animationRangeEnd",
      "offsetPath", "offsetPosition", "offsetAnchor", "offsetRotate", "width", "height",
      "minWidth", "maxWidth", "minHeight", "maxHeight", "inlineSize", "blockSize",
      "minInlineSize", "maxInlineSize", "minBlockSize", "maxBlockSize", "flexBasis",
      "fontSize", "lineHeight", "borderRadius", "borderStartStartRadius", "borderStartEndRadius",
      "borderEndStartRadius", "borderEndEndRadius", "borderTopLeftRadius", "borderTopRightRadius",
      "borderBottomLeftRadius", "borderBottomRightRadius", "filter", "backdropFilter",
      "boxShadow", "textShadow",
    ].contains(declaration.property) {
    return false
  }
  let expressions = declaration_expressions(declaration)
  !expressions.is_empty() &&
  expressions.every(value => {
    value.variables().is_empty() &&
    values.contains(@core.canonical_css_value(value.to_css()))
  })
}
