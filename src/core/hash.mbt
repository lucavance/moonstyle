// MurmurHash2 compatibility implementation derived from StyleX 0.19.
// Copyright (c) Meta Platforms, Inc. and affiliates. MIT licensed.

///|
let murmur_m : UInt32 = 0x5bd1e995

///|
fn byte_at(value : String, index : Int32) -> UInt32 {
  value.unsafe_get(index).to_uint() & 0xff
}

///|
fn murmurhash2(value : String, seed~ : UInt32 = 1) -> UInt32 {
  let mut remaining = value.length()
  let mut hash = seed ^ remaining.reinterpret_as_uint()
  let mut index = 0
  while remaining >= 4 {
    let mut block = byte_at(value, index) |
      (byte_at(value, index + 1) << 8) |
      (byte_at(value, index + 2) << 16) |
      (byte_at(value, index + 3) << 24)
    block = block * murmur_m
    block = block ^ (block >> 24)
    block = block * murmur_m
    hash = (hash * murmur_m) ^ block
    remaining = remaining - 4
    index = index + 4
  }
  if remaining == 3 {
    hash = hash ^ (byte_at(value, index + 2) << 16)
  }
  if remaining >= 2 {
    hash = hash ^ (byte_at(value, index + 1) << 8)
  }
  if remaining >= 1 {
    hash = hash ^ byte_at(value, index)
    hash = hash * murmur_m
  }
  hash = hash ^ (hash >> 13)
  hash = hash * murmur_m
  hash ^ (hash >> 15)
}

///|
fn hash(value : String) -> String {
  murmurhash2(value).to_string(radix=36)
}

///|
fn class_name(hash_input : String, prefix~ : String = "x") -> String {
  prefix + hash("<>" + hash_input)
}

///|
pub fn selector_marker_class_name(
  module_name : String,
  name : String,
) -> String {
  class_name("marker|" + module_name + "|" + name, prefix="m")
}

///|
pub fn view_transition_class_name(
  module_name : String,
  name : String,
) -> String {
  class_name("view-transition|" + module_name + "|" + name, prefix="vt")
}
