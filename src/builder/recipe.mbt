///|
pub struct VariantChoice {
  value : String
  rules : Array[Rule]
}

///|
pub fn variant_choice(value : String, rules : Array[Rule]) -> VariantChoice {
  { value, rules: rules.copy(), }
}

///|
pub struct VariantSelection {
  axis : String
  value : String
}

///|
pub fn variant_is(axis : String, value : String) -> VariantSelection {
  { axis, value, }
}

///|
pub fn boolean_variant_is(axis : String, enabled : Bool) -> VariantSelection {
  { axis, value: if enabled { "true" } else { "false" }, }
}

///|
struct RecipeAxis {
  name : String
  choices : Array[VariantChoice]
  default_value : String?
  boolean : Bool
}

///|
struct RecipeCompound {
  matches : Array[VariantSelection]
  rules : Array[Rule]
}

///|
pub struct Recipe {
  name : String
  base : Array[Rule]
  variants : Array[RecipeAxis]
  compounds : Array[RecipeCompound]
  contract : String?
}

///|
pub fn recipe_rule() -> Rule {
  rule("recipe")
}

///|
fn Rule::recipe_named(self : Rule, name : String) -> Rule {
  { name, declarations: self.declarations, variables: self.variables, }
}

///|
fn recipe_rules_named(rules : Array[Rule], prefix : String) -> Array[Rule] {
  let output : Array[Rule] = []
  for index, authored in rules {
    output.push(authored.recipe_named(prefix + "_" + index.to_string()))
  }
  output
}

///|
pub fn recipe(name : String, base : Array[Rule]) -> Recipe {
  {
    name,
    base: recipe_rules_named(base, name + "__base"),
    variants: [],
    compounds: [],
    contract: None,
  }
}

///|
pub fn Recipe::variant(
  self : Recipe,
  axis : String,
  choices : Array[VariantChoice],
  default~ : String? = None,
) -> Recipe {
  let variants = self.variants.copy()
  let normalized = choices.map(choice => {
    value: choice.value,
    rules: recipe_rules_named(
      choice.rules,
      self.name + "__" + axis + "__" + choice.value,
    ),
  })
  variants.push({
    name: axis,
    choices: normalized,
    default_value: default,
    boolean: false,
  })
  { ..self, variants, }
}

///|
pub fn Recipe::boolean_variant(
  self : Recipe,
  axis : String,
  enabled : Array[Rule],
  disabled~ : Array[Rule] = [],
  default~ : Bool? = None,
) -> Recipe {
  let variants = self.variants.copy()
  variants.push({
    name: axis,
    choices: [
      {
        value: "true",
        rules: recipe_rules_named(enabled, self.name + "__" + axis + "__true"),
      },
      {
        value: "false",
        rules: recipe_rules_named(disabled, self.name + "__" + axis + "__false"),
      },
    ],
    default_value: default.map(value => if value { "true" } else { "false" }),
    boolean: true,
  })
  { ..self, variants, }
}

///|
pub fn Recipe::compound(
  self : Recipe,
  matches : Array[VariantSelection],
  rules : Array[Rule],
) -> Recipe {
  let compounds = self.compounds.copy()
  compounds.push({
    matches: matches.copy(),
    rules: recipe_rules_named(
      rules,
      self.name + "__compound__" + compounds.length().to_string(),
    ),
  })
  { ..self, compounds, }
}

///|
pub fn Recipe::for_contract(self : Recipe, contract : StyleContract) -> Recipe {
  { ..self, contract: Some(contract.name), }
}

///|
pub fn Recipe::rules(self : Recipe) -> Array[Rule] {
  let output = self.base.copy()
  for axis in self.variants {
    for choice in axis.choices {
      for authored in choice.rules {
        output.push(authored)
      }
    }
  }
  for compound in self.compounds {
    for authored in compound.rules {
      output.push(authored)
    }
  }
  output
}

///|
pub fn Recipe::to_ir(self : Recipe) -> @ir.Recipe {
  {
    name: self.name,
    base: self.base.map(authored => authored.name),
    variants: self.variants.map(axis => {
      name: axis.name,
      choices: axis.choices.map(choice => {
        value: choice.value,
        rules: choice.rules.map(authored => authored.name),
      }),
      default_value: axis.default_value,
      boolean: axis.boolean,
    }),
    compounds: self.compounds.map(compound => {
      matches: compound.matches.map(selection => {
        axis: selection.axis,
        value: selection.value,
      }),
      rules: compound.rules.map(authored => authored.name),
    }),
    contract: self.contract,
  }
}
