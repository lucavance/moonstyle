///|
pub(all) enum ContainerStyleCondition {
  StyleEquals(@values.VariableUse, String)
  StyleNot(ContainerStyleCondition)
  StyleAll(Array[ContainerStyleCondition])
  StyleAny(Array[ContainerStyleCondition])
} derive(Eq, Debug)

///|
pub extend ContainerStyleCondition with Eq::{equal, not_equal}

///|
pub extend ContainerStyleCondition with @debug.Debug::{to_repr}

///|
pub fn ContainerStyleCondition::variables(
  self : ContainerStyleCondition,
) -> Array[@values.VariableUse] {
  match self {
    StyleEquals(variable, _) => [variable]
    StyleNot(child) => child.variables()
    StyleAll(children) | StyleAny(children) => {
      let output = []
      for child in children {
        for variable in child.variables() {
          output.push(variable)
        }
      }
      output
    }
  }
}
