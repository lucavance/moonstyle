///|
test "HTTP paths cannot escape the generated site" {
  for
    path in [
      "/../moon.mod", "/.git/config", "/%2e%2e/moon.mod", "/a\\b", "file",
    ] {
    assert_eq(@devserver.request_path(path), None)
  }
  assert_eq(@devserver.request_path("/"), Some("index.html"))
  assert_eq(@devserver.request_path("/styles.css?v=1"), Some("styles.css"))
}

///|
test "CSS maps preserve authored coordinates without embedding source text" {
  let manifest : Json = {
    "module": "local/app",
    "globals": [],
    "rules": [
      {
        "css": ".x{color:red}",
        "origins": [
          {
            "module": "local/app",
            "source": {
              "absoluteFile": "/project/styles.mbt",
              "line": 3,
              "column": 5,
            },
          },
        ],
      },
    ],
  }
  let map = @devserver.source_map("/* generated */\n.x{color:red}\n", manifest)
  assert_eq(@support.get(map, "sources"), Json(["/project/styles.mbt"]))
  assert_eq(@support.get(map, "sourcesContent"), Json([""]))
  assert_eq(@support.get(map, "mappings"), Json(";AAEI;"))
}
