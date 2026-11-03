///|
using @html {button, div, h1, p, text}

///|
pub(all) enum Message {
  Toggle
} derive(Eq)

///|
struct Model {
  active : Bool
  progress : Int32
} derive(Eq)

///|
fn update(msg : Message, model : Model) -> Model {
  match msg {
    Toggle =>
      { active: !model.active, progress: if model.active { 37 } else { 76 }, }
  }
}

///|
fn rabbita_adapter_fixtures() -> @rabbita.Html {
  let base = @style_fixture_runtime.compiled([("color", "base-color")], inline_vars=[
    ("--meter", "25%"),
  ])
  let override_ = @style_fixture_runtime.compiled([("color", "active-color")])
  let checked : @style_fixture_runtime.StyleResult = Ok(
    @style_fixture_runtime.compiled([("color", "active-color")], inline_vars=[
      ("--backgroundColor", "red"),
      ("--BackgroundColor", "blue"),
    ]),
  )
  let optional : @style_fixture_runtime.CompiledStyle? = Some(base)
  let mixed_attrs = @style_fixture_runtime.expect_dynamic(
    @css.try_attrs(
      @style_fixture_runtime.compose(optional).add(checked),
      base=@html.Attrs::build().id("rabbita-adapter-mixed"),
    ),
  )
  div(id="rabbita-adapter-fixtures", hidden=true, [
    div(
      attrs=@css.attrs(
        base,
        base=@html.Attrs::build().id("rabbita-adapter-static"),
      ),
      @html.nothing,
    ),
    div(
      attrs=@css.attrs_many(
        [base, override_],
        base=@html.Attrs::build().id("rabbita-adapter-many"),
      ),
      @html.nothing,
    ),
    div(attrs=mixed_attrs, @html.nothing),
    div(
      attrs=@css.attrs_or_abort(
        checked,
        base=@html.Attrs::build().id("rabbita-adapter-checked"),
      ),
      div(
        attrs=@css.attrs_or_abort(
          @styles.expressionPanel(@moonstyle.px(0), @moonstyle.deg(0.0)),
          base=@html.Attrs::build().id("rabbita-adapter-zero"),
        ),
        @html.nothing,
      ),
    ),
  ])
}

///|
fn view(emit : @rabbita.Emit[Message], model : Model) -> @rabbita.Html {
  let page_style = @moonstyle.compose(@styles.page).when(
    model.active,
    @styles.dark,
  )
  let card_style = @moonstyle.compose(@styles.card).when(
    model.active,
    @styles.active,
  )
  let meter_attrs = @css.attrs_or_abort(
    @styles.meter(@moonstyle.percent(model.progress)),
  )
  let multi_dynamic_attrs = @css.attrs_or_abort(
    @moonstyle.style_list()
    .when(model.active, @styles.active)
    .add(
      @styles.multiDynamic(
        @moonstyle.percent(model.progress),
        if model.active {
          @moonstyle.rgb(48, 62, 72)
        } else {
          @moonstyle.rgb(220, 230, 238)
        },
        if model.active {
          @moonstyle.rgb(245, 248, 250)
        } else {
          @moonstyle.rgb(30, 40, 50)
        },
      ),
    ),
  )
  let rejected_dynamic_base = @html.Attrs::build().class("retained-base")
  ignore(
    @css.try_attrs(
      @styles.meter(@moonstyle.length(0.0 / 0.0, Px)),
      base=rejected_dynamic_base,
    ),
  )
  let component_overrides = @component_button.button_styles(
      @component_button.badge,
    )
    .when(model.active, @styles.active)
    .add(
      @styles.buttonTone(
        if model.active {
          @moonstyle.rgb(245, 248, 250)
        } else {
          @moonstyle.rgb(23, 33, 43)
        },
      ),
    )
  let dependency_attrs = @css.attrs_or_abort(
    component_overrides
    .to_style_list()
    .add(@style_fixture_runtime.compiled([("dependency-border", "dep-b")])),
    base=@html.Attrs::build().hidden(true),
  )
  let conflict_longhand_last = @moonstyle.compose(@styles.conflictMargin)
    .add(@styles.conflictMarginTop)
    .add(@styles.conflictPadding)
    .add(@styles.conflictPaddingLeft)
    .add(@styles.conflictGap)
    .add(@styles.conflictRowGap)
  let conflict_shorthand_last = @moonstyle.compose(@styles.conflictMarginTop)
    .add(@styles.conflictMargin)
    .add(@styles.conflictPaddingLeft)
    .add(@styles.conflictPadding)
    .add(@styles.conflictRowGap)
    .add(@styles.conflictGap)
  let conditional_shorthand_last = @moonstyle.compose(@styles.conflictMarginTop).add(
    @styles.conflictConditionalMargin,
  )
  let conditional_longhand_last = @moonstyle.compose(
    @styles.conflictConditionalMargin,
  ).add(@styles.conflictMarginTop)
  let rtl_directional = @styles.rtlDirectional
  let conflict_logical_last = @moonstyle.compose(@styles.conflictPhysicalMargin).add(
    @styles.conflictLogicalMargin,
  )
  let conflict_physical_last = @moonstyle.compose(@styles.conflictLogicalMargin).add(
    @styles.conflictPhysicalMargin,
  )
  let explicit_clear = @moonstyle.compose(@styles.clearBase).when(
    model.active,
    @styles.clearColor,
  )
  let scalar_logical_last = @moonstyle.compose(@styles.scalarHeight)
    .add(@styles.scalarBlockSize)
    .add(@styles.scalarWidth)
    .add(@styles.scalarInlineSize)
  let scalar_physical_last = @moonstyle.compose(@styles.scalarBlockSize)
    .add(@styles.scalarHeight)
    .add(@styles.scalarInlineSize)
    .add(@styles.scalarWidth)
  let scalar_scroll_longhand_last = @moonstyle.compose(
    @styles.scalarScrollMargin,
  ).add(@styles.scalarScrollMarginTop)
  let scalar_scroll_shorthand_last = @moonstyle.compose(
    @styles.scalarScrollMarginTop,
  ).add(@styles.scalarScrollMargin)
  let scalar_overscroll_axis_last = @moonstyle.compose(@styles.scalarOverscroll).add(
    @styles.scalarOverscrollBlock,
  )
  let scalar_overscroll_shorthand_last = @moonstyle.compose(
    @styles.scalarOverscrollBlock,
  ).add(@styles.scalarOverscroll)
  let scalar_transition_longhand_last = @moonstyle.compose(
    @styles.scalarTransition,
  ).add(@styles.scalarTransitionDuration)
  let scalar_transition_shorthand_last = @moonstyle.compose(
    @styles.scalarTransitionDuration,
  ).add(@styles.scalarTransition)
  let scalar_svg = @styles.scalarSvg
  let border_composite_side = @styles.borderCompositeSide
  let border_composite_pairs = @styles.borderCompositePairs
  let border_composite_longhands = @styles.borderCompositeLonghands
  let border_composite_corner = @styles.borderCompositeCorner
  let border_composite_outline = @styles.borderCompositeOutline
  div(id="validation-page", attrs=@css.attrs_or_abort(page_style), [
    rabbita_adapter_fixtures(),
    div(id="validation-card", attrs=@css.attrs_or_abort(card_style), [
      h1(attrs=@css.attrs(@styles.title), [text("MoonStyle")]),
      p(attrs=@css.attrs(@styles.copy), [
        text(
          "MoonBit authors and extracts typed atomic CSS. Rabbita renders the application.",
        ),
      ]),
      div(id="meter-track", attrs=@css.attrs(@styles.meterTrack), [
        div(id="meter", attrs=meter_attrs, @html.nothing),
      ]),
      button(
        id="toggle",
        attrs=@css.attrs(@styles.button),
        on_click=emit(Toggle),
        [
          text(
            if model.active {
              "Reset validation"
            } else {
              "Activate validation"
            },
          ),
        ],
      ),
      div(
        id="keyframe-animation",
        attrs=@css.attrs(@styles.animated),
        @html.nothing,
      ),
      div(id="multi-dynamic", attrs=multi_dynamic_attrs, @html.nothing),
      div(
        id="expression-panel",
        attrs=@css.attrs_or_abort(
          @styles.expressionPanel(
            @moonstyle.px(if model.active { 80 } else { 20 }),
            @moonstyle.deg(if model.active { 180.0 } else { 90.0 }),
          ),
        ),
        @html.nothing,
      ),
      div(
        id="expression-grid",
        attrs=@css.attrs_or_abort(
          @styles.expressionGrid(
            @moonstyle.px(if model.active { 120 } else { 80 }).as_length_percentage(),
          ),
        ),
        [
          div([text("One")]),
          div([text("Two")]),
          div([text("Three")]),
          div(
            id="expression-subgrid",
            attrs=@css.attrs(@styles.expressionSubgrid),
            [div([text("Sub one")]), div([text("Sub two")])],
          ),
        ],
      ),
      div(
        id="rejected-dynamic-base",
        attrs=rejected_dynamic_base.hidden(true),
        @html.nothing,
      ),
      div(id="cross-module", attrs=dependency_attrs, @html.nothing),
      div(
        id="explicit-clear",
        attrs=@css.attrs_or_abort(
          explicit_clear,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="conflict-longhand-last",
        attrs=@css.attrs_or_abort(
          conflict_longhand_last,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="conflict-shorthand-last",
        attrs=@css.attrs_or_abort(
          conflict_shorthand_last,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="conditional-shorthand-last",
        attrs=@css.attrs_or_abort(
          conditional_shorthand_last,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="conditional-longhand-last",
        attrs=@css.attrs_or_abort(
          conditional_longhand_last,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="rtl-directional",
        attrs=@css.attrs_or_abort(
          rtl_directional,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="conflict-logical-last",
        attrs=@css.attrs_or_abort(
          conflict_logical_last,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="conflict-physical-last",
        attrs=@css.attrs_or_abort(
          conflict_physical_last,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="scalar-logical-last",
        attrs=@css.attrs_or_abort(
          scalar_logical_last,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="scalar-physical-last",
        attrs=@css.attrs_or_abort(
          scalar_physical_last,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="scalar-scroll-longhand-last",
        attrs=@css.attrs_or_abort(
          scalar_scroll_longhand_last,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="scalar-scroll-shorthand-last",
        attrs=@css.attrs_or_abort(
          scalar_scroll_shorthand_last,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="scalar-overscroll-axis-last",
        attrs=@css.attrs_or_abort(
          scalar_overscroll_axis_last,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="scalar-overscroll-shorthand-last",
        attrs=@css.attrs_or_abort(
          scalar_overscroll_shorthand_last,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="scalar-transition-longhand-last",
        attrs=@css.attrs_or_abort(
          scalar_transition_longhand_last,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="scalar-transition-shorthand-last",
        attrs=@css.attrs_or_abort(
          scalar_transition_shorthand_last,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="scalar-svg",
        attrs=@css.attrs_or_abort(
          scalar_svg,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="border-composite-side",
        attrs=@css.attrs_or_abort(
          border_composite_side,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="border-composite-pairs",
        attrs=@css.attrs_or_abort(
          border_composite_pairs,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="border-composite-longhands",
        attrs=@css.attrs_or_abort(
          border_composite_longhands,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="border-composite-corner",
        attrs=@css.attrs_or_abort(
          border_composite_corner,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
      div(
        id="border-composite-outline",
        attrs=@css.attrs_or_abort(
          border_composite_outline,
          base=@html.Attrs::build().hidden(true),
        ),
        @html.nothing,
      ),
    ]),
  ])
}

///|
fn root() -> @rabbita.Val[@rabbita.Html] {
  let (model, emit) = @rabbita.create_pure_state(
    { active: false, progress: 37, },
    update=fn(model, message) { update(message, model) },
  )
  model.view(model => view(emit, model))
}

///|
fn main {
  @rabbita.new(root).mount("app")
}
