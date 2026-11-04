///|
async fn main {
  let args = @env.args()
  @generator.generate(
    @fs.realpath(if args.length() > 1 { args[1] } else { "../.." }),
  ) catch {
    @support.ToolError(code, message) => abort(code + ": " + message)
    error => raise error
  }
}
