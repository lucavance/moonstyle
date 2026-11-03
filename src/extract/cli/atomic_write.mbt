///|
priv struct Artifact {
  target : String
  temporary : String
  backup : String
  content : String
}

///|
#borrow(from, to)
extern "C" fn rename_ffi(from : Bytes, to : Bytes) -> Int32 = "moonstyle_atomic_rename"

///|
#borrow(path)
extern "C" fn mkdirs_ffi(path : Bytes) -> Int32 = "moonstyle_atomic_mkdirs"

///|
fn rename_path(from : String, to : String) -> Bool {
  rename_ffi(c_string(from), c_string(to)) == 0
}

///|
fn create_directories(path : String) -> Bool {
  mkdirs_ffi(c_string(path)) == 0
}

///|
fn c_string(value : String) -> Bytes {
  let encoded = @utf8.encode(value)
  Bytes::makei(encoded.length() + 1, index => {
    if index < encoded.length() {
      encoded[index]
    } else {
      b'\x00'
    }
  })
}

///|
fn remove_if_present(path : String) -> Unit {
  if @fs.path_exists(path) {
    @fs.remove_file(path) catch {
      _ => ()
    }
  }
}

///|
fn cleanup_staging(artifacts : Array[Artifact]) -> Unit {
  for artifact in artifacts {
    remove_if_present(artifact.temporary)
    remove_if_present(artifact.backup)
  }
}

///|
fn restore_backups(artifacts : Array[Artifact]) -> Unit {
  for artifact in artifacts {
    if @fs.path_exists(artifact.backup) {
      remove_if_present(artifact.target)
      ignore(rename_path(artifact.backup, artifact.target))
    }
  }
}

///|
fn write_artifacts_atomically(artifacts : Array[Artifact]) -> Unit {
  cleanup_staging(artifacts)
  try {
    for artifact in artifacts {
      @fs.write_string_to_file(artifact.temporary, artifact.content)
    }
  } catch {
    _ => {
      cleanup_staging(artifacts)
      abort("Failed to stage generated style artifacts")
    }
  }

  for artifact in artifacts {
    if @fs.path_exists(artifact.target) &&
      !rename_path(artifact.target, artifact.backup) {
      restore_backups(artifacts)
      cleanup_staging(artifacts)
      abort("Failed to back up generated style artifacts")
    }
  }

  for artifact in artifacts {
    if !rename_path(artifact.temporary, artifact.target) {
      restore_backups(artifacts)
      cleanup_staging(artifacts)
      abort("Failed to replace generated style artifacts")
    }
  }
  cleanup_staging(artifacts)
}

///|
fn artifacts_match(artifacts : Array[Artifact]) -> Bool {
  artifacts.every(artifact => {
    if !@fs.path_exists(artifact.target) {
      return false
    }
    let existing = @fs.read_file_to_string(artifact.target) catch {
      _ => return false
    }
    existing == artifact.content
  })
}

///|
fn write_artifacts_if_changed(artifacts : Array[Artifact]) -> Bool {
  if artifacts_match(artifacts) {
    return false
  }
  write_artifacts_atomically(artifacts)
  true
}
