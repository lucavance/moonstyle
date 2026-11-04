///|
pub fn dx_budget(
  debug_cold : Double,
  release_cold : Double,
  warm : Double,
  execution : Double,
  devtools : Double,
  parity : Bool,
) -> Json {
  let ratio = debug_cold / release_cold
  let warm_limit = 750.0.max(debug_cold * 0.5)
  let overhead = 0.0.max(devtools - execution)
  let checks : Json = {
    "debugColdRelative": {
      "actual": ratio,
      "maximum": 0.65,
      "met": ratio <= 0.65,
    },
    "debugWarm": {
      "actualMs": warm,
      "maximumMs": warm_limit,
      "met": warm <= warm_limit,
    },
    "devtoolsOverhead": {
      "actualMs": overhead,
      "maximumMs": 50,
      "met": overhead <= 50.0,
    },
    "outputParity": { "met": parity },
  }
  {
    "checks": checks,
    "met": ratio <= 0.65 && warm <= warm_limit && overhead <= 50.0 && parity,
  }
}

///|
pub async fn dx(root : String) -> Unit {
  let temporary = @fs.tmpdir(prefix="moonstyle-dx-")
  defer @fs.rmdir(temporary, recursive=true)
  let app = root + "/validation"
  let config = @project.style_config(app)
  let bundles = @project.dependency_bundles(app, config)
  let debug_cold = []
  let release_cold = []
  let execution = []
  let devtools_execution = []
  let mut warm_target = ""
  let build = async fn(profile : String, target : String) -> (String, Double) {
    let args = [
        "run", "cmd/style_extract", "--target", "native", "--build-only", "--output-json",
        "--target-dir", target, "--frozen",
      ] +
      (if profile == "release" { ["--release"] } else { [] })
    let start = @async.now()
    let output = @support.command("moon", args, app)
    let elapsed = (@async.now() - start).to_double()
    let (paths, diagnostics) = @project.build_records(output, "")
    guard paths is [executable] else {
      @support.reject("STYLE_BENCHMARK", Json(diagnostics).stringify())
    }
    (executable, elapsed)
  }
  let mut parity = true
  for index = 0; index < 2; index = index + 1 {
    let profiles = if index % 2 == 0 {
      ["debug", "release"]
    } else {
      ["release", "debug"]
    }
    let paths : Map[String, String] = Map([])
    for profile in profiles {
      let target = temporary + "/cold-" + index.to_string() + "-" + profile
      let (executable, elapsed) = build(profile, target)
      paths[profile] = executable
      if profile == "debug" {
        debug_cold.push(elapsed)
        warm_target = target
      } else {
        release_cold.push(elapsed)
      }
    }
    let digests : Array[Array[String]] = []
    for
      (profile, debugging) in [
        ("debug", false),
        ("debug", true),
        ("release", false),
      ] {
      let output = temporary +
        "/outputs-" +
        index.to_string() +
        "-" +
        profile +
        (if debugging { "-devtools" } else { "" })
      @fs.mkdir(output, recursive=true, allow_exist=true)
      let args = [
        "--tooling-protocol",
        "1",
        "--no-cache",
        "--mappings-package",
        @support.text(config, "mappingsPackage"),
        "--css-output",
        output + "/styles.css",
        "--mappings-output",
        output + "/styles.mbt",
        "--mappings-manifest-output",
        output + "/moon.pkg",
        "--bundle-output",
        output + "/styles.bundle.json",
      ]
      for bundle in bundles {
        args.append(["--dependency-bundle", bundle])
      }
      if debugging {
        args.append(["--debug-manifest-output", output + "/debug.json"])
      }
      let elapsed = timing(@shell.Cmd(paths[profile], args, cwd=app))
      if profile == "debug" {
        if debugging {
          devtools_execution.push(elapsed)
        } else {
          execution.push(elapsed)
        }
      }
      if debugging {
        guard @support.get(
            @support.json(output + "/debug.json"),
            "schemaVersion",
          ) ==
          Json(1) else {
          @support.reject("STYLE_BENCHMARK", "Invalid debug manifest")
        }
      }
      let hashes = []
      for file in ["styles.css", "styles.mbt", "moon.pkg", "styles.bundle.json"] {
        hashes.push(@support.file_hash(output + "/" + file))
      }
      digests.push(hashes)
    }
    parity = parity && digests[0] == digests[1] && digests[0] == digests[2]
  }
  let warm = []
  for _index = 0; _index < 3; _index = _index + 1 {
    warm.push(build("debug", warm_target).1)
  }
  let med = fn(values : Array[Double]) -> Double raise {
    numeric(summary(values), "medianMs")
  }
  let budgets = dx_budget(
    med(debug_cold),
    med(release_cold),
    med(warm),
    med(execution),
    med(devtools_execution),
    parity,
  )
  let report : Json = {
    "schemaVersion": 2,
    "toolchain": @json.parse(
      @support.command("moon", ["version", "--all", "--json"], root),
    ),
    "timings": {
      "coldDebug": summary(debug_cold),
      "coldRelease": summary(release_cold),
      "warmDebug": summary(warm),
      "execution": summary(execution),
      "devtoolsExecution": summary(devtools_execution),
    },
    "outputsEqual": parity,
    "budgets": budgets,
  }
  @support.write(
    root + "/.generated/dx-benchmark.json",
    report.stringify(indent=2) + "\n",
  )
  println(report.stringify(indent=2))
  guard @support.flag(budgets, "met") else {
    @support.reject(
      "STYLE_BENCHMARK", "Native development performance budget failed",
    )
  }
}
