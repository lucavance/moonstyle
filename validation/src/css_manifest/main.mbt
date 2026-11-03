///|
fn demo_styles() -> StyleSet {
  {
    export_name: "styles",
    namespaces: [
      style_namespace("page", [
        decl("minHeight", "100vh"),
        decl("display", "grid"),
        decl("placeItems", "center"),
        decl("fontFamily", "Inter, ui-sans-serif, system-ui, sans-serif"),
        decl("padding", "24px"),
        conditional("backgroundColor", "#f3f5f7", [
          at_rule("@media (max-width: 640px)", "#e7eef5"),
        ]),
        decl("color", "#17212b"),
      ]),
      style_namespace("card", [
        decl("width", "min(560px, 100%)"),
        decl("padding", "28px"),
        decl("borderWidth", "1px"),
        decl("borderStyle", "solid"),
        decl("borderColor", "#cad3dc"),
        decl("borderRadius", "8px"),
        decl("boxShadow", "0 18px 50px rgba(30, 45, 60, 0.12)"),
        conditional("backgroundColor", "#ffffff", [pseudo(":hover", "#f8fbfd")]),
        decl("color", "#17212b"),
      ]),
      style_namespace("active", [
        decl("backgroundColor", "#e2f4e8"),
        decl("borderColor", "#4b9668"),
      ]),
      style_namespace("title", [
        decl("fontSize", "28px"),
        decl("fontWeight", "700"),
        decl("lineHeight", "1.2"),
        decl("margin", "0 0 12px"),
      ]),
      style_namespace("copy", [
        decl("fontSize", "15px"),
        decl("lineHeight", "1.6"),
        decl("margin", "0 0 22px"),
        decl("color", "#52606d"),
      ]),
      style_namespace("meterTrack", [
        decl("height", "12px"),
        decl("width", "100%"),
        decl("overflow", "hidden"),
        decl("borderRadius", "6px"),
        decl("backgroundColor", "#dce3e9"),
        decl("marginBottom", "20px"),
      ]),
      style_namespace("meter", [
        dynamic("width", "%"),
        decl("height", "100%"),
        decl("backgroundColor", "#216e4e"),
        decl("transition", "width 180ms ease"),
      ]),
      style_namespace("button", [
        decl("appearance", "none"),
        decl("border", "1px solid #1f5f46"),
        decl("borderRadius", "6px"),
        decl("backgroundColor", "#216e4e"),
        decl("color", "white"),
        decl("fontWeight", "650"),
        decl("padding", "10px 16px"),
        decl("cursor", "pointer"),
      ]),
    ],
  }
}

///|
fn main {
  println(demo_styles().to_manifest_json().stringify())
}
