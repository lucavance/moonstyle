///|
pub let usage =
  #|Usage: moonstyle <init|doctor|upgrade|generate|check|watch> [options]
  #|
  #|  --root <directory>          MoonBit module root (default: current directory)
  #|  --json                      Versioned JSON reports; watch emits NDJSON
  #|  --verbose                   Extraction inputs, outputs and cache details
  #|  init --styles-package <name> --extractor-package <path>
  #|  doctor --strict             Check native compilation and current artifacts
  #|  upgrade --dry-run           Preview the complete managed-file transaction
  #|
  #|The native CLI requires MoonBit; Node and Vite are optional integrations.

///|
pub fn parse(args : Array[String]) -> (String, Map[String, String]) raise {
  let command = args.get(0).unwrap_or("--help")
  if ["--help", "-h", "--version"].contains(command) {
    return (command, Map([]))
  }
  guard ["init", "doctor", "upgrade", "generate", "check", "watch"].contains(
    command,
  ) else {
    @support.reject("STYLE_USAGE", "Unknown command: " + command)
  }
  let options = Map([])
  let mut index = 1
  while index < args.length() {
    let argument = args[index]
    if ["--help", "-h"].contains(argument) {
      return ("--help", options)
    }
    let parts = argument.split("=").map(part => part.to_owned()).collect()
    let flag = parts[0]
    let valued = ["--root"].contains(flag) ||
      (
        command == "init" &&
        ["--styles-package", "--extractor-package"].contains(flag)
      )
    let boolean = flag == "--json" ||
      (flag == "--strict" && command == "doctor") ||
      (flag == "--dry-run" && command == "upgrade") ||
      (flag == "--verbose" && ["generate", "check", "watch"].contains(command))
    guard !options.contains(flag) && (valued || boolean) else {
      @support.reject("STYLE_USAGE", "Unknown or repeated option: " + argument)
    }
    let value = if valued {
      if parts.length() > 1 {
        argument[flag.length() + 1:].to_owned()
      } else {
        index += 1
        args.get(index).unwrap_or("")
      }
    } else {
      guard parts.length() == 1 else {
        @support.reject("STYLE_USAGE", "Flag takes no value: " + flag)
      }
      "true"
    }
    guard value != "" && !value.has_prefix("--") else {
      @support.reject("STYLE_USAGE", "Missing value for " + flag)
    }
    options[flag] = value
    index += 1
  }
  guard !(options.contains("--json") && options.contains("--verbose")) else {
    @support.reject("STYLE_USAGE", "--json and --verbose cannot be combined")
  }
  (command, options)
}

///|
pub async fn run(args : Array[String]) -> Int32 {
  let (command, options) = parse(args) catch {
    @support.ToolError(_, message) => {
      println(message + "\n\n" + usage)
      return 2
    }
    _ => return 2
  }
  if command == "--help" {
    println(usage)
    return 0
  }
  if command == "--version" {
    println(@project.version)
    return 0
  }
  let root = options.get("--root").unwrap_or(".")
  let json = options.contains("--json")
  let verbose = options.contains("--verbose")
  let outcome = try {
    let root = @fs.realpath(root)
    match command {
      "init" =>
        @project.initialize(
          root,
          styles=options.get("--styles-package"),
          extractor=options.get("--extractor-package"),
        )
      "upgrade" =>
        @project.initialize(
          root,
          upgrade=true,
          dry_run=options.contains("--dry-run"),
        )
      "doctor" => @project.doctor(root, strict=options.contains("--strict"))
      "generate" => @project.extract(root)
      "check" => @project.extract(root, check=true)
      "watch" => {
        @project.watch(root, event => {
          if json {
            println(event.stringify())
          } else if @support.get(event, "event") == Json("watch-start") {
            println("[moonstyle] watch-ready " + root)
          } else if @support.get(event, "event") == Json("watch-stop") {
            println("[moonstyle] watch-stop")
          } else {
            println(
              "[moonstyle] check-start\n" +
              @project.render(event, verbose~) +
              "\n[moonstyle] check-end",
            )
          }
        })
        @project.report(command, [])
      }
      _ => @project.report(command, [])
    }
  } catch {
    error =>
      if @async.is_being_cancelled() {
        raise error
      } else {
        @project.failed_report(command, error)
      }
  }
  println(@project.render(outcome, json~, verbose~))
  if @support.flag(outcome, "passed") {
    0
  } else {
    1
  }
}
