///|
pub(all) enum Condition {
  Pseudo(String)
  AtRule(String)
} derive(Eq, Debug)

///|
pub(all) struct ConditionalBranch {
  condition : Condition
  value : String
} derive(Eq, Debug)

///|
pub(all) enum StyleValue {
  Static(String)
  Conditional(String, Array[ConditionalBranch])
  Dynamic(String)
} derive(Eq, Debug)

///|
pub(all) struct Declaration {
  property : String
  value : StyleValue
} derive(Eq, Debug)

///|
pub(all) struct Namespace {
  name : String
  declarations : Array[Declaration]
} derive(Eq, Debug)

///|
pub(all) struct StyleSet {
  export_name : String
  namespaces : Array[Namespace]
} derive(Eq, Debug)

///|
pub fn decl(property : String, value : String) -> Declaration {
  { property, value: Static(value), }
}

///|
pub fn conditional(
  property : String,
  default_value : String,
  branches : Array[ConditionalBranch],
) -> Declaration {
  { property, value: Conditional(default_value, branches), }
}

///|
pub fn dynamic(property : String, suffix : String) -> Declaration {
  { property, value: Dynamic(suffix), }
}

///|
pub fn pseudo(value : String, result : String) -> ConditionalBranch {
  { condition: Pseudo(value), value: result, }
}

///|
pub fn at_rule(value : String, result : String) -> ConditionalBranch {
  { condition: AtRule(value), value: result, }
}

///|
pub fn style_namespace(
  name : String,
  declarations : Array[Declaration],
) -> Namespace {
  { name, declarations, }
}

///|
fn Condition::to_manifest_json(self : Condition) -> Json {
  match self {
    Pseudo(value) => { "kind": "pseudo", "value": value }
    AtRule(value) => { "kind": "at-rule", "value": value }
  }
}

///|
fn ConditionalBranch::to_manifest_json(self : ConditionalBranch) -> Json {
  { "condition": self.condition.to_manifest_json(), "value": self.value }
}

///|
fn StyleValue::to_manifest_json(self : StyleValue) -> Json {
  match self {
    Static(value) => { "kind": "static", "value": value }
    Conditional(default_value, branches) =>
      {
        "kind": "conditional",
        "default": default_value,
        "branches": branches.map(branch => branch.to_manifest_json()),
      }
    Dynamic(suffix) => { "kind": "dynamic", "suffix": suffix }
  }
}

///|
fn Declaration::to_manifest_json(self : Declaration) -> Json {
  { "property": self.property, "value": self.value.to_manifest_json() }
}

///|
fn Namespace::to_manifest_json(self : Namespace) -> Json {
  {
    "name": self.name,
    "declarations": self.declarations.map(decl => decl.to_manifest_json()),
  }
}

///|
pub fn StyleSet::to_manifest_json(self : StyleSet) -> Json {
  {
    "schemaVersion": 1,
    "exportName": self.export_name,
    "namespaces": self.namespaces.map(ns => ns.to_manifest_json()),
  }
}
