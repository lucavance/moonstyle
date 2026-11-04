///|
pub async fn run(task : String, root : String, write~ : Bool = false) -> Unit {
  match task {
    "generate-order" => application_order(root)
    "interfaces" => interfaces(root)
    "api" => api_baseline(root, write~)
    "toolchain" => toolchain(root)
    "licenses" => licenses(root)
    "licenses-node" => node_licenses(root)
    "worktree" => worktree(root)
    "generated" => generated(root)
    "fixtures" => fixtures(root, write~)
    "docs" => docs(root)
    "boundaries" => boundaries(root)
    "release" => {
      toolchain(root)
      licenses(root)
      docs(root)
      api_baseline(root)
      @benchmark.audit(root)
    }
    _ => @support.reject("STYLE_COMMAND", "Unknown maintenance task: " + task)
  }
}
