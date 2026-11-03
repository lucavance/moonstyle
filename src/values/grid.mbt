///|
enum TrackKind {
  Fixed
  Flexible
  Intrinsic
  MinMax(Bool)
  FitContent
  Named
  Repeat(Bool, Bool)
} derive(Eq, Debug)

///|
pub extend TrackKind with Eq::{equal, not_equal}

///|
pub extend TrackKind with @debug.Debug::{to_repr}

///|
fn make_track(expression : Expression, kind : TrackKind) -> GridTrack {
  { css: expression.to_css(), expression, kind, }
}

///|
fn invalid_track(message : String) -> GridTrack {
  make_track(
    literal_expression(issue_css("STYLE_GRID_TRACK", message), "grid-track"),
    Intrinsic,
  )
}

///|
fn GridTrack::is_fixed(self : GridTrack) -> Bool {
  match self.kind {
    Fixed | MinMax(true) | Repeat(true, _) | Named => true
    _ => false
  }
}

///|
fn GridTrack::is_breadth(self : GridTrack) -> Bool {
  match self.kind {
    Fixed | Flexible | Intrinsic => true
    _ => false
  }
}

///|
fn make_tracks(tracks : Array[GridTrack]) -> GridTrackList {
  let values = tracks.map(track => track.expression)
  let mut previous_named = false
  for track in tracks {
    if previous_named && track.kind == Named {
      values.push(
        literal_expression(
          issue_css(
            "STYLE_GRID_TRACK", "Combine names for one grid line in a single named_lines call",
          ),
          "grid-track",
        ),
      )
      break
    }
    previous_named = track.kind == Named
  }
  let auto_count = tracks
    .filter(track => {
      match track.kind {
        Repeat(_, true) => true
        _ => false
      }
    })
    .length()
  if tracks.is_empty() || tracks.every(track => track.kind == Named) {
    values.push(
      literal_expression(
        issue_css("STYLE_GRID_TRACK", "A track list requires a track size"),
        "grid-track",
      ),
    )
  }
  if auto_count > 1 ||
    (auto_count == 1 && !tracks.every(track => track.is_fixed())) {
    values.push(
      literal_expression(
        issue_css(
          "STYLE_GRID_AUTO_REPEAT", "Auto-repeat permits one repetition and requires fixed-size tracks",
        ),
        "grid-track",
      ),
    )
  }
  let expression = group_expression("grid-track-list", "", values, " ", "")
  {
    css: expression.to_css(),
    expression,
    tracks: tracks.copy(),
    subgrid: false,
  }
}

///|
fn make_repeat(
  count : String,
  tracks : GridTrackList,
  automatic : Bool,
) -> GridTrack {
  if tracks.subgrid ||
    tracks.tracks.any(track => {
      match track.kind {
        Repeat(_, _) => true
        _ => false
      }
    }) {
    return invalid_track(
      "Nested repeats and subgrid inside repeat are not supported by the grid grammar",
    )
  }
  if automatic && !tracks.tracks.every(track => track.is_fixed()) {
    return invalid_track("Auto-repeat requires fixed-size tracks")
  }
  make_track(
    group_expression(
      "grid-track",
      "repeat(" + count + ", ",
      [tracks.expression],
      "",
      ")",
    ),
    Repeat(tracks.tracks.every(track => track.is_fixed()), automatic),
  )
}

///|
pub fn auto_fit(tracks : GridTrackList) -> GridTrack {
  make_repeat("auto-fit", tracks, true)
}

///|
pub fn auto_fill(tracks : GridTrackList) -> GridTrack {
  make_repeat("auto-fill", tracks, true)
}

///|
pub fn track_auto() -> GridTrack {
  make_track(literal_expression("auto", "grid-track"), Intrinsic)
}

///|
pub fn track_min_content() -> GridTrack {
  make_track(literal_expression("min-content", "grid-track"), Intrinsic)
}

///|
pub fn track_max_content() -> GridTrack {
  make_track(literal_expression("max-content", "grid-track"), Intrinsic)
}

///|
pub fn[T : LengthPercentageMathInput] fit_content(value : T) -> GridTrack {
  make_track(
    group_expression(
      "grid-track",
      "fit-content(",
      [value.length_percentage_math().expression.constrain("nonnegative")],
      "",
      ")",
    ),
    FitContent,
  )
}

///|
fn grid_name_start(code : Int32) -> Bool {
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  code == 95 ||
  code >= 128
}

///|
fn valid_custom_ident(name : String) -> Bool {
  if name.is_empty() {
    return false
  }
  let first = name.unsafe_get(0).to_int()
  if first == 45 {
    if name.length() < 2 {
      return false
    }
    let second = name.unsafe_get(1).to_int()
    if second != 45 && !grid_name_start(second) {
      return false
    }
  } else if !grid_name_start(first) {
    return false
  }
  for index = 1; index < name.length(); index = index + 1 {
    let code = name.unsafe_get(index).to_int()
    if !grid_name_start(code) && code != 45 && !(code >= 48 && code <= 57) {
      return false
    }
  }
  !["initial", "inherit", "unset", "revert", "revert-layer", "default"].contains(
    name.to_lower(),
  )
}

///|
fn valid_grid_name(name : String) -> Bool {
  valid_custom_ident(name) && !["auto", "span"].contains(name.to_lower())
}

///|
// CSS Grid 2 line-names use custom-ident; reserved keywords are ASCII caseless.
// https://www.w3.org/TR/css-grid-2/#named-lines
pub fn named_lines(names : Array[String]) -> GridTrack {
  if names.any(name => !valid_grid_name(name)) {
    return invalid_track("Grid line names must be unescaped custom identifiers")
  }
  make_track(
    literal_expression("[" + names.join(" ") + "]", "grid-track"),
    Named,
  )
}

///|
pub fn subgrid(lines~ : Array[Array[String]] = []) -> GridTrackList {
  let tracks = lines.map(named_lines)
  let values = [literal_expression("subgrid", "grid-track")]
  for track in tracks {
    values.push(track.expression)
  }
  let expression = group_expression("grid-track-list", "", values, " ", "")
  { css: expression.to_css(), expression, tracks, subgrid: true, }
}

///|
pub fn GridTrackList::expression(self : GridTrackList) -> Expression {
  if self.auto_tracks_allowed() {
    self.expression
  } else {
    { ..self.expression, category: "grid-template-track-list", }
  }
}

///|
pub fn GridTrackList::auto_tracks_allowed(self : GridTrackList) -> Bool {
  !self.subgrid &&
  self.tracks.every(track => {
    match track.kind {
      Named | Repeat(_, _) => false
      _ => true
    }
  })
}

///|
pub fn invalid_expression(code : String, message : String) -> Expression {
  literal_expression(issue_css(code, message), "invalid")
}
