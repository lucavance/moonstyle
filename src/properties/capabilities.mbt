///|
pub struct LayoutDeclaration {
  declaration : @ir.Declaration
}

///|
pub struct TypographyDeclaration {
  declaration : @ir.Declaration
}

///|
pub struct VisualDeclaration {
  declaration : @ir.Declaration
}

///|
pub struct InteractionDeclaration {
  declaration : @ir.Declaration
}

///|
pub struct MotionDeclaration {
  declaration : @ir.Declaration
}

///|
fn layout_declaration(declaration : @ir.Declaration) -> LayoutDeclaration {
  { declaration, }
}

///|
fn typography_declaration(
  declaration : @ir.Declaration,
) -> TypographyDeclaration {
  { declaration, }
}

///|
fn visual_declaration(declaration : @ir.Declaration) -> VisualDeclaration {
  { declaration, }
}

///|
fn interaction_declaration(
  declaration : @ir.Declaration,
) -> InteractionDeclaration {
  { declaration, }
}

///|
fn motion_declaration(declaration : @ir.Declaration) -> MotionDeclaration {
  { declaration, }
}

///|
pub fn LayoutDeclaration::to_declaration(
  self : LayoutDeclaration,
) -> @ir.Declaration {
  self.declaration
}

///|
pub fn TypographyDeclaration::to_declaration(
  self : TypographyDeclaration,
) -> @ir.Declaration {
  self.declaration
}

///|
pub fn VisualDeclaration::to_declaration(
  self : VisualDeclaration,
) -> @ir.Declaration {
  self.declaration
}

///|
pub fn InteractionDeclaration::to_declaration(
  self : InteractionDeclaration,
) -> @ir.Declaration {
  self.declaration
}

///|
pub fn MotionDeclaration::to_declaration(
  self : MotionDeclaration,
) -> @ir.Declaration {
  self.declaration
}

///|
pub fn LayoutDeclaration::with_source(
  self : LayoutDeclaration,
  source : @ir.SourceSpan,
) -> LayoutDeclaration {
  { declaration: self.declaration.with_source(source), }
}

///|
pub fn TypographyDeclaration::with_source(
  self : TypographyDeclaration,
  source : @ir.SourceSpan,
) -> TypographyDeclaration {
  { declaration: self.declaration.with_source(source), }
}

///|
pub fn VisualDeclaration::with_source(
  self : VisualDeclaration,
  source : @ir.SourceSpan,
) -> VisualDeclaration {
  { declaration: self.declaration.with_source(source), }
}

///|
pub fn InteractionDeclaration::with_source(
  self : InteractionDeclaration,
  source : @ir.SourceSpan,
) -> InteractionDeclaration {
  { declaration: self.declaration.with_source(source), }
}

///|
pub fn MotionDeclaration::with_source(
  self : MotionDeclaration,
  source : @ir.SourceSpan,
) -> MotionDeclaration {
  { declaration: self.declaration.with_source(source), }
}
