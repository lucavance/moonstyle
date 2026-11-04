import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { test } from 'vite-plus/test';

const root = path.resolve(import.meta.dirname, '..');
const fixtureDirectory = path.join(root, 'tests', 'compile-fail');
const styleModule = root;

const fixtures = [
  { filename: 'registration-time.mbt', diagnostic: /RegisterableValue|Time/is },
  { filename: 'daily-white-space-string.mbt', diagnostic: /WhiteSpaceInput|String/is },
  {
    filename: 'daily-font-variation-length.mbt',
    diagnostic: /FontVariationSettingsInput|Length/is,
  },
  { filename: 'daily-vertical-align-color.mbt', diagnostic: /VerticalAlignInput|Color/is },
  { filename: 'image-fallback-rejects-length.mbt', diagnostic: /ImageInput|Length/is },
  { filename: 'page-string.mbt', diagnostic: /PageValueInput|String/is },
  { filename: 'page-length.mbt', diagnostic: /PageValueInput|Length/is },
  { filename: 'paint-length.mbt', diagnostic: /SvgPaintInput|Length/is },
  { filename: 'paint-string.mbt', diagnostic: /SvgPaintInput|String/is },
  { filename: 'paint-length-slot.mbt', diagnostic: /SvgPaintInput|DynamicSlot/is },
  { filename: 'scrollbar-length.mbt', diagnostic: /GradientColorInput|Length/is },
  { filename: 'scheme-frame.mbt', diagnostic: /color_scheme|no method/is },
  { filename: 'common-line-height-color.mbt', diagnostic: /LineHeightInput|Color/is },
  { filename: 'common-radius-angle.mbt', diagnostic: /BoxSizeValueInput|Angle/is },
  { filename: 'composite-shadow-color-length.mbt', diagnostic: /GradientColorInput|Length/is },
  { filename: 'composite-filter-color-slot.mbt', diagnostic: /FilterAmountDimension|Color/is },
  { filename: 'coverage-fallback-category.mbt', diagnostic: /ColorInput|Length.*implement/is },
  { filename: 'coverage-mix-weight.mbt', diagnostic: /Percentage|Length/is },
  { filename: 'coverage-image-resolution.mbt', diagnostic: /Resolution|Length/is },
  { filename: 'coverage-transform-angle.mbt', diagnostic: /AngleMathInput|Length/is },
  { filename: 'coverage-container-equality.mbt', diagnostic: /Number|Length/is },
  { filename: 'coverage-motion-string.mbt', diagnostic: /MotionPathInput|String/is },
  { filename: 'math-wrong-dimension.mbt', diagnostic: /MathExpr|Angle|Length/is },
  { filename: 'math-wrong-property.mbt', diagnostic: /LengthMathDimension|LengthInput|Angle/is },
  { filename: 'math-font-width-length.mbt', diagnostic: /PercentageInput|MathExpr/is },
  {
    filename: 'math-contract-wrong-dimension.mbt',
    diagnostic: /LengthContractExpression|LengthMathDimension|BoxSizeDimension/is,
  },
  {
    filename: 'conic-length-stop.mbt',
    diagnostic: /GradientStop|ConicPosition|LengthPercentage/is,
  },
  {
    filename: 'font-width-rejects-length.mbt',
    diagnostic: /PercentageInput|Length.*Percentage|font_width/is,
  },
  {
    filename: 'font-width-rejects-color-slot.mbt',
    diagnostic: /PercentageInput|DynamicSlot.*Color|font_width/is,
  },
  {
    filename: 'font-width-contract-rejects-length.mbt',
    diagnostic: /Percentage|Length.*Percentage/is,
  },
  {
    filename: 'fluent-invalid-property.mbt',
    diagnostic: /definitely_not_a_css_property|no method.*property|not found|unbound/i,
  },
  {
    filename: 'fluent-invalid-value-category.mbt',
    diagnostic: /LengthInput|Color.*Length|width/is,
  },
  {
    filename: 'fluent-invalid-slot-category.mbt',
    diagnostic: /LengthInput|ColorSlot|DynamicSlot.*Color|width/is,
  },
  {
    filename: 'fluent-slot-theme-override.mbt',
    diagnostic: /with_value|no method|not found|unbound/i,
  },
  {
    filename: 'fluent-mixed-fallback-categories.mbt',
    diagnostic: /wanted\s+:.*Color|expected.*Color|Length.*Color/is,
  },
  {
    filename: 'frame-clear-property.mbt',
    diagnostic: /clear_color|no method|not found|unbound/i,
  },
  {
    filename: 'invalid-value-conversion.mbt',
    diagnostic: /as_length_percentage|no method|not found|unbound/i,
  },
  {
    filename: 'style-input-rejects-primitive.mbt',
    diagnostic: /StyleInput|Int.*implement|does not implement/is,
  },
  {
    filename: 'rabbita-attrs-rejects-array.mbt',
    diagnostic: /StaticStyleInput|Array.*implement|does not implement/is,
    rabbita: true,
  },
  {
    filename: 'component-contract-rejects-width.mbt',
    diagnostic: /ButtonStyleInput|StyleList.*implement|does not implement/is,
    componentContract: true,
  },
  {
    filename: 'contract-invalid-property.mbt',
    diagnostic: /allow_definitely_not_a_css_property|no method|not found|unbound/i,
  },
  {
    filename: 'contract-invalid-literal-category.mbt',
    diagnostic: /wanted\s+:.*Color|expected.*Color|Length.*Color/is,
  },
  {
    filename: 'contract-invalid-token-category.mbt',
    diagnostic: /wanted\s+:.*Token.*Color|has type\s+:.*Token.*Length/is,
  },
  {
    filename: 'contract-animation-exact-values.mbt',
    diagnostic: /values|unexpected argument|no parameter/i,
  },
  {
    filename: 'invalid-property.mbt',
    diagnostic: /definitely_not_a_css_property|no method.*property/i,
  },
  {
    filename: 'invalid-value-category.mbt',
    diagnostic: /wanted\s+:.*Length|expected.*Length|Color.*Length/is,
  },
  {
    filename: 'invalid-dynamic-variable.mbt',
    diagnostic: /wanted\s+:.*CssVar.*Length|Color.*Length/is,
  },
  {
    filename: 'opaque-value-construction.mbt',
    diagnostic: /cannot create|private|not.*visible|field.*css/is,
  },
  {
    filename: 'component-capability-overreach.mbt',
    diagnostic:
      /LayoutDeclaration.*undefined|wanted\s+:.*LayoutDeclaration|expected.*LayoutDeclaration/is,
  },
  {
    filename: 'mixed-fallback-categories.mbt',
    diagnostic: /wanted\s+:.*Color|expected.*Color|Length.*Color/is,
  },
  {
    filename: 'unsupported-dynamic-property.mbt',
    diagnostic: /dynamic_height|not found|unbound/i,
  },
  {
    filename: 'opaque-number-construction.mbt',
    diagnostic: /cannot create|private|not.*visible|field.*css/is,
  },
  {
    filename: 'invalid-enum-value.mbt',
    diagnostic: /Bogus|unbound|not found/i,
  },
  {
    filename: 'cross-scalar-enum.mbt',
    diagnostic:
      /ScrollbarWidthValue.*ScrollSnapStopValue|ScrollSnapStopValue.*ScrollbarWidthValue/is,
  },
  {
    filename: 'invalid-scalar-primitive.mbt',
    diagnostic: /wanted\s+:.*Time|expected.*Time|Length.*Time/is,
  },
  {
    filename: 'anchor-name-rejects-length.mbt',
    diagnostic: /AnchorNames|Length.*AnchorNames|anchor_name/is,
  },
  {
    filename: 'vendor-property.mbt',
    diagnostic: /webkit_line_clamp|not found|unbound|private/i,
  },
  {
    filename: 'all-property.mbt',
    diagnostic: /\ball\b|not found|unbound/i,
  },
  {
    filename: 'unsupported-scalar-dynamic.mbt',
    diagnostic: /dynamic_block_size|not found|unbound/i,
  },
  {
    filename: 'border-width-requires-line-width.mbt',
    diagnostic: /wanted\s+:.*LineWidth|expected.*LineWidth|Length.*LineWidth/is,
  },
  {
    filename: 'border-style-requires-line-style.mbt',
    diagnostic: /wanted\s+:.*LineStyle|expected.*LineStyle|BorderStyle.*LineStyle/is,
  },
  {
    filename: 'border-rejects-string.mbt',
    diagnostic: /wanted\s+:.*BorderSide|expected.*BorderSide|String.*BorderSide/is,
  },
  {
    filename: 'border-width-rejects-composite.mbt',
    diagnostic: /wanted\s+:.*LineWidth|expected.*LineWidth|BorderSide.*LineWidth/is,
  },
];

function moduleManifest() {
  return 'name = "local/style-compile-fail"\nversion = "0.0.0"\nimport { "lampclaw/moonstyle@0.2.0" }';
}

function packageManifest(componentContract = false, rabbita = false) {
  return [
    'import {',
    '  "lampclaw/moonstyle" @moonstyle,',
    ...(rabbita ? ['  "lampclaw/moonstyle/rabbita" @css,'] : []),
    '  "lampclaw/moonstyle/properties" @properties,',
    '  "lampclaw/moonstyle/values" @values,',
    ...(componentContract ? ['  "local/style-compile-fail/component" @component,'] : []),
    '}',
    '',
  ].join('\n');
}

for (const fixture of fixtures) {
  test(`${fixture.filename} is rejected by moon check`, () => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'style-compile-fail-'));
    try {
      fs.writeFileSync(path.join(directory, 'moon.mod'), `${moduleManifest()}\n`);
      fs.writeFileSync(
        path.join(directory, 'moon.work'),
        `members = [".", ${JSON.stringify(styleModule)}]\n`,
      );
      fs.writeFileSync(
        path.join(directory, 'moon.pkg'),
        packageManifest(fixture.componentContract, fixture.rabbita),
      );
      if (fixture.componentContract) {
        const componentDirectory = path.join(directory, 'component');
        fs.mkdirSync(componentDirectory);
        for (const filename of ['moon.pkg', 'styles.generated.mbt']) {
          fs.copyFileSync(
            path.join(root, 'validation', 'tests', 'component_a_generated', filename),
            path.join(componentDirectory, filename),
          );
        }
      }
      fs.copyFileSync(
        path.join(fixtureDirectory, fixture.filename),
        path.join(directory, fixture.filename),
      );
      const result = spawnSync('moon', ['check', '--target', 'js'], {
        cwd: directory,
        encoding: 'utf8',
      });
      const output = `${result.stdout}${result.stderr}`;
      assert.notEqual(result.status, 0, `${fixture.filename} unexpectedly compiled`);
      assert.match(output, fixture.diagnostic);
    } finally {
      fs.rmSync(directory, { recursive: true, force: true });
    }
  });
}
