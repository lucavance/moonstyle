///|
fn numeric(value : Json, key : String) -> Double raise {
  guard @support.get(value, key) is Number(number, ..) &&
    !number.is_nan() &&
    !number.is_inf() else {
    @support.reject("STYLE_BENCHMARK", "Invalid numeric field " + key)
  }
  number
}

///|
fn rounded(value : Double) -> Double {
  @double.round(value * 1000.0) / 1000.0
}

///|
pub fn summary(samples : Array[Double]) -> Json raise {
  guard !samples.is_empty() &&
    samples.all(value => !value.is_nan() && !value.is_inf()) else {
    @support.reject("STYLE_BENCHMARK", "Samples must be finite and nonempty")
  }
  let samples = samples.map(rounded)
  let ordered = samples.copy()
  ordered.sort()
  let count = ordered.length()
  let middle = count / 2
  {
    "medianMs": rounded(
      if count % 2 == 0 {
        (ordered[middle - 1] + ordered[middle]) / 2.0
      } else {
        ordered[middle]
      },
    ),
    "p95Ms": ordered[@double.ceil(count.to_double() * 0.95).to_int() - 1],
    "minMs": ordered[0],
    "maxMs": ordered[count - 1],
    "samplesMs": samples,
  }
}

///|
pub fn paired(full : Array[Double], adaptive : Array[Double]) -> Json raise {
  guard full.length() == adaptive.length() &&
    full.all(value => value > 0.0) &&
    adaptive.all(value => value > 0.0) else {
    @support.reject(
      "STYLE_BENCHMARK", "Paired timings must be positive and have equal lengths",
    )
  }
  {
    "full": summary(full),
    "adaptive": summary(adaptive),
    "delta": summary(adaptive.mapi((index, value) => value - full[index])),
  }
}

///|
pub fn budget(name : String, timings : Json) -> Json raise {
  let full = @support.get(timings, "full")
  let adaptive = @support.get(timings, "adaptive")
  if name == "small" {
    let median_limit = (numeric(full, "medianMs") * 1.05).max(
      numeric(full, "medianMs") + 1.0,
    )
    let p95_limit = (numeric(full, "p95Ms") * 1.15).max(
      numeric(full, "p95Ms") + 1.0,
    )
    {
      "kind": "distribution-no-regression",
      "thresholds": {
        "medianMaximumMs": rounded(median_limit),
        "p95MaximumMs": rounded(p95_limit),
      },
      "observed": {
        "adaptiveMedianMs": numeric(adaptive, "medianMs"),
        "adaptiveP95Ms": numeric(adaptive, "p95Ms"),
      },
      "met": numeric(adaptive, "medianMs") <= median_limit &&
      numeric(adaptive, "p95Ms") <= p95_limit,
    }
  } else {
    let speedup = rounded(
      numeric(full, "medianMs") / numeric(adaptive, "medianMs"),
    )
    {
      "kind": "minimum-speedup",
      "thresholds": { "minimumSpeedup": 3 },
      "observed": { "speedup": speedup },
      "met": speedup >= 3.0,
    }
  }
}

///|
fn workloads() -> Array[(String, Int32, Int32, Int32, Int32, String)] {
  [
    ("small", 2, 100, 20, 100, "balanced-alternating-blocks"),
    ("medium", 60, 6000, 10, 20, "alternating-pairs"),
    ("large", 100, 10000, 10, 20, "alternating-pairs"),
  ]
}

///|
async fn candidate(root : String) -> Json {
  let bundle = @support.json(
    root + "/validation/src/generated/styles.bundle.json",
  )
  let api = @support.json(root + "/src/properties/property-api.json")
  let metadata = @support.json(root + "/src/properties/property-metadata.json")
  {
    "artifactSchemaVersion": @support.get(bundle, "schemaVersion"),
    "propertyApiSchemaVersion": @support.get(api, "schemaVersion"),
    "propertyCount": @support.array(@support.get(metadata, "properties")).length(),
    "semantics": @support.get(bundle, "semantics"),
  }
}

///|
async fn sizes(root : String) -> Json {
  let sizes : Map[String, Json] = Map([])
  for
    (key, file) in [
      ("css", "styles.generated.css"),
      ("mappings", "styles.generated.mbt"),
      ("mappingsManifest", "moon.pkg"),
      ("bundle", "styles.bundle.json"),
    ] {
    let path = root + "/validation/src/generated/" + file
    let compressed = @shell.Cmd("gzip", ["-n", "-6", "-c", path]).output()
    compressed.check()
    sizes[key] = {
      "rawBytes": @fs.read_file(path).binary().length(),
      "gzipBytes": compressed.stdout_bytes().length(),
    }
  }
  Json::object(sizes)
}

///|
async fn timing(command : @shell.Cmd) -> Double {
  let start = @async.now()
  let result = command.output()
  result.check()
  (@async.now() - start).to_double()
}

///|
async fn scenario(
  repository : String,
  parent : String,
  configuration : (String, Int32, Int32, Int32, Int32, String),
  semantics : Json,
) -> Json {
  let (name, modules, rules, warmups, measured, ordering) = configuration
  let root = parent + "/" + name
  let module_name = "benchmark/" + name
  @support.write(
    root + "/moon.mod",
    "name = " +
    Json(module_name).stringify() +
    "\nimport { \"lampclaw/moonstyle@0.3.0\" }\n",
  )
  @support.write(
    root + "/moon.work",
    "members = [\".\", " + Json(repository).stringify() + "]\n",
  )
  @support.write(
    root + "/styles/moon.pkg",
    "import { \"lampclaw/moonstyle\" }\n",
  )
  let references = []
  let bundles = []
  for module_index = 0; module_index < modules; module_index = module_index + 1 {
    let dependency = module_name + "/dependency-" + module_index.to_string()
    let entries : Array[Json] = Array::makei(rules / modules, index => {
      let class_name = "x-" +
        name +
        "-" +
        module_index.to_string() +
        "-" +
        index.to_string()
      {
        "property": "color",
        "className": class_name,
        "ltr": "." +
        class_name +
        "{color:rgb(" +
        (index % 255).to_string() +
        " 40 80)}",
        "rtl": null,
        "priority100": 300000,
      }
    })
    let semantic : Json = {
      "schemaVersion": 14,
      "module": dependency,
      "mappingsPackage": dependency + "/generated",
      "semantics": semantics,
      "directDependencies": [],
      "dependencyClosure": [],
      "contracts": [],
      "namespaces": [],
      "rules": entries,
      "globals": [],
      "recipes": [],
      "markers": [],
      "viewTransitionClasses": [],
    }
    let digest = @support.hash(semantic.stringify())
    let fields = @support.copy(semantic)
    fields["semanticDigest"] = Json(digest)
    let bundle = root +
      "/bundles/dependency-" +
      module_index.to_string() +
      ".bundle.json"
    @support.write(bundle, Json::object(fields).stringify())
    bundles.push(bundle)
    references.push(
      "@moonstyle.dependency_ref(" +
      Json(dependency).stringify() +
      ", " +
      Json(digest).stringify() +
      ")",
    )
  }
  @support.write(
    root + "/styles/styles.mbt",
    "pub fn registry() -> @moonstyle.Registry { @moonstyle.registry(" +
    Json(module_name + "/app").stringify() +
    ", [], dependencies=[" +
    references.join(",") +
    "]) }\n",
  )
  ignore(@project.initialize(root, extractor=Some("extractor")))
  let (paths, diagnostics) = @project.build(root, "extractor")
  guard paths is [executable] &&
    diagnostics.all(item => @support.get(item, "severity") != Json("error")) else {
    @support.reject("STYLE_BENCHMARK", Json(diagnostics).stringify())
  }
  let cache = root + "/cache"
  @fs.mkdir(root + "/generated", recursive=true, allow_exist=true)
  let args = [
    "--tooling-protocol",
    "1",
    "--cache-dir",
    cache,
    "--mappings-package",
    module_name + "/generated",
    "--css-output",
    "generated/styles.css",
    "--mappings-output",
    "generated/styles.mbt",
    "--mappings-manifest-output",
    "generated/moon.pkg",
    "--bundle-output",
    "generated/styles.bundle.json",
  ]
  for bundle in bundles {
    args.append(["--dependency-bundle", bundle])
  }
  let environment = {
    "MOONSTYLE_CACHE_IDENTITY": @support.hash(
      bundles.map(bundle => bundle).join("\n"),
    ),
  }
  let run = async fn(full : Bool) -> Double {
    timing(
      @shell.Cmd(
        executable,
        args + (if full { ["--no-cache"] } else { [] }),
        cwd=root,
        env=environment,
      ),
    )
  }
  ignore(run(false))
  let sample = async fn(index : Int32) -> (Double, Double) {
    if name == "small" {
      if index % 2 == 0 {
        let f1 = run(true)
        let a1 = run(false)
        let a2 = run(false)
        let f2 = run(true)
        ((f1 + f2) / 2.0, (a1 + a2) / 2.0)
      } else {
        let a1 = run(false)
        let f1 = run(true)
        let f2 = run(true)
        let a2 = run(false)
        ((f1 + f2) / 2.0, (a1 + a2) / 2.0)
      }
    } else if index % 2 == 0 {
      let full = run(true)
      (full, run(false))
    } else {
      let adaptive = run(false)
      (run(true), adaptive)
    }
  }
  for index = 0; index < warmups; index = index + 1 {
    ignore(sample(index))
  }
  let full = []
  let adaptive = []
  for index = 0; index < measured; index = index + 1 {
    let pair = sample(index)
    full.push(pair.0)
    adaptive.push(pair.1)
  }
  let timings = paired(full, adaptive)
  let result = budget(name, timings)
  println(
    "Measured " +
    name +
    " cache workload: " +
    @support.get(result, "met").stringify(),
  )
  {
    "modules": modules,
    "rules": rules,
    "measurement": {
      "warmups": warmups,
      "measuredRuns": measured,
      "ordering": ordering,
    },
    "timings": timings,
    "speedup": rounded(
      numeric(@support.get(timings, "full"), "medianMs") /
      numeric(@support.get(timings, "adaptive"), "medianMs"),
    ),
    "p95Ratio": rounded(
      numeric(@support.get(timings, "adaptive"), "p95Ms") /
      numeric(@support.get(timings, "full"), "p95Ms"),
    ),
    "budget": result,
    "budgetMet": @support.get(result, "met"),
  }
}

///|
pub async fn measure(root : String, output : String?) -> Unit {
  let temporary = @fs.tmpdir(prefix="moonstyle-performance-")
  defer @fs.rmdir(temporary, recursive=true)
  let identity = candidate(root)
  let scenarios : Map[String, Json] = Map([])
  for configuration in workloads() {
    scenarios[configuration.0] = scenario(
      root,
      temporary,
      configuration,
      @support.get(identity, "semantics"),
    )
  }
  let report : Json = {
    "schemaVersion": 5,
    "recordedAt": @support.command("date", ["-u", "+%Y-%m-%dT%H:%M:%SZ"], root)
    .trim()
    .to_owned(),
    "candidate": identity,
    "machine": @support.command("uname", ["-a"], root).trim().to_owned(),
    "toolchain": @json.parse(
      @support.command("moon", ["version", "--all", "--json"], root),
    ),
    "scenarios": Json::object(scenarios),
    "budgetsMet": scenarios
    .values()
    .all(value => @support.flag(value, "budgetMet")),
    "sizes": sizes(root),
  }
  if output is Some(path) {
    let path = @support.project_path(root, path)
    guard path.has_prefix("benchmarks/") && path.has_suffix(".json") else {
      @support.reject(
        "STYLE_USAGE", "Benchmark output must be a JSON file under benchmarks/",
      )
    }
    ignore(
      @project.transact(root, Map([(path, report.stringify(indent=2) + "\n")])),
    )
  }
  guard @support.flag(report, "budgetsMet") else {
    @support.reject("STYLE_BENCHMARK", report.stringify(indent=2))
  }
  println(report.stringify(indent=2))
}

///|
pub async fn audit(root : String) -> Unit {
  let identity = candidate(root)
  let pinned = @support.get(@support.json(root + "/toolchain.json"), "tools")
  let expected_sizes = sizes(root)
  let reports = [
    @support.json(root + "/benchmarks/0.3.0-candidate-1.json"),
    @support.json(root + "/benchmarks/0.3.0-candidate-2.json"),
  ]
  let mut timestamp = ""
  for report in reports {
    let items = @support.array(
      @support.get(@support.get(report, "toolchain"), "items"),
    )
    for (name, key) in [("moon", "moonCli"), ("moonc", "moonCompiler")] {
      let matching = items.filter(item => {
        @support.get(item, "name") == Json(name)
      })
      guard matching is [item] else {
        @support.reject(
          "STYLE_BENCHMARK",
          "Missing recorded toolchain component: " + name,
        )
      }
      let version = @support.text(item, "version")
      let expected = @support.text(pinned, key)
      guard (version.has_prefix(expected) || version.has_prefix("v" + expected)) &&
        (
          name != "moon" ||
          version.contains(@support.text(pinned, "moonRevision"))
        ) else {
        @support.reject(
          "STYLE_BENCHMARK", "Recorded benchmark toolchain differs from toolchain.json",
        )
      }
    }
    guard @support.get(report, "schemaVersion") == Json(5) &&
      @support.get(report, "candidate") == identity &&
      @support.get(report, "sizes") == expected_sizes &&
      @support.flag(report, "budgetsMet") else {
      @support.reject(
        "STYLE_BENCHMARK", "Candidate benchmark identity, sizes or budget is stale",
      )
    }
    let next = @support.text(report, "recordedAt")
    guard re"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$".execute(next[:])
      is Some(_) &&
      next.lexical_compare(timestamp) > 0 else {
      @support.reject(
        "STYLE_BENCHMARK", "Benchmark reports must have ordered distinct timestamps",
      )
    }
    timestamp = next
    for configuration in workloads() {
      let (name, modules, rules, warmups, measured, ordering) = configuration
      let value = @support.get(@support.get(report, "scenarios"), name)
      guard @support.get(value, "modules") == Json(modules) &&
        @support.get(value, "rules") == Json(rules) &&
        @support.get(value, "measurement") ==
        (
          { "warmups": warmups, "measuredRuns": measured, "ordering": ordering } :
          Json) else {
        @support.reject("STYLE_BENCHMARK", "Frozen workload changed: " + name)
      }
      let samples = fn(key : String) -> Array[Double] raise {
        let samples = @support.array(
          @support.get(
            @support.get(@support.get(value, "timings"), key),
            "samplesMs",
          ),
        )
        guard samples.length() == measured else {
          @support.reject("STYLE_BENCHMARK", "Incorrect sample count")
        }
        samples.map(value => {
          match value {
            Number(value, ..) => value
            _ => @support.reject("STYLE_BENCHMARK", "Invalid sample")
          }
        })
      }
      let timings = paired(samples("full"), samples("adaptive"))
      let expected_budget = budget(name, timings)
      let speedup = rounded(
        numeric(@support.get(timings, "full"), "medianMs") /
        numeric(@support.get(timings, "adaptive"), "medianMs"),
      )
      let p95_ratio = rounded(
        numeric(@support.get(timings, "adaptive"), "p95Ms") /
        numeric(@support.get(timings, "full"), "p95Ms"),
      )
      guard @support.get(value, "timings") == timings &&
        @support.get(value, "budget") == expected_budget &&
        numeric(value, "speedup") == speedup &&
        numeric(value, "p95Ratio") == p95_ratio &&
        @support.flag(expected_budget, "met") &&
        @support.flag(value, "budgetMet") else {
        @support.reject(
          "STYLE_BENCHMARK",
          "Performance evidence is not reproducible: " + name,
        )
      }
    }
  }
  for key in ["machine", "toolchain", "candidate", "sizes"] {
    guard @support.get(reports[0], key) == @support.get(reports[1], key) else {
      @support.reject("STYLE_BENCHMARK", "Performance reports differ: " + key)
    }
  }
  println(
    "Two native benchmark reports match the candidate and pass every frozen cache budget.",
  )
}
