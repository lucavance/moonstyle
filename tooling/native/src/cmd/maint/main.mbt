///|
async fn main {
  let args = @env.args()
  let task = args.get(1).unwrap_or("help")
  let root = @fs.realpath(args.get(2).unwrap_or("../.."))
  @maintenance.run(task, root, write=args.contains("--write")) catch {
    @support.ToolError(code, message) => {
      println(code + ": " + message)
      @sys.exit(1)
    }
    error => {
      println(error.to_string())
      @sys.exit(1)
    }
  }
}
