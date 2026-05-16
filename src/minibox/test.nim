#:____________________________________________________________________
#  minibox  |  Copyright (C) Ivan Mar (sOkam!)  |  GPL-3.0-or-later  :
#:____________________________________________________________________
import minitest
import ../minibox


describe "minibox.key | Construction":
  it "must create a null key with max index", proc() =
    NullKey.index.eq high(u32)
    NullKey.gen.eq 0u32

  it "must identify null keys", proc() =
    NullKey.isNull.eq true
    Key(index: 0, gen: 0).isNull.eq false


describe "minibox.basic | Insert":
  it "must insert and retrieve a value", proc() =
    var box = minibox.basic[int]()
    let key = box.insert(42)
    box[key].eq 42

  it "must assign sequential indices", proc() =
    var box = minibox.basic[int]()
    let first = box.insert(10)
    let second = box.insert(20)
    first.index.eq 0u32
    second.index.eq 1u32

  it "must track length", proc() =
    var box = minibox.basic[int]()
    box.len.eq 0u32
    discard box.insert(1)
    box.len.eq 1u32
    discard box.insert(2)
    box.len.eq 2u32

describe "minibox.basic | Access":
  it "must overwrite value with []=", proc() =
    var box = minibox.basic[int]()
    let key = box.insert(10)
    box[key] = 99
    box[key].eq 99

  it "must report contains for live keys", proc() =
    var box = minibox.basic[int]()
    let key = box.insert(5)
    box.contains(key).eq true
    box.contains(NullKey).eq false

describe "minibox.basic | Delete":
  it "must remove a value and decrement length", proc() =
    var box = minibox.basic[int]()
    let key = box.insert(42)
    box.delete(key)
    box.len.eq 0u32
    box.contains(key).eq false

  it "must reuse slots after deletion", proc() =
    var box = minibox.basic[int]()
    let first = box.insert(10)
    box.delete(first)
    let second = box.insert(20)
    second.index.eq first.index
    second.gen.eq first.gen + 1

  it "must invalidate stale keys after deletion", proc() =
    var box = minibox.basic[int]()
    let key = box.insert(42)
    box.delete(key)
    discard box.insert(99)
    box.contains(key).eq false

describe "minibox.basic | Iteration":
  it "must iterate all live values", proc() =
    var box = minibox.basic[int]()
    discard box.insert(10)
    discard box.insert(20)
    discard box.insert(30)
    var total = 0
    for value in box:
      total += value
    total.eq 60

  it "must skip deleted slots during iteration", proc() =
    var box = minibox.basic[int]()
    discard box.insert(10)
    let middle = box.insert(20)
    discard box.insert(30)
    box.delete(middle)
    var total = 0
    for value in box:
      total += value
    total.eq 40

  it "must yield keys and values with pairs", proc() =
    var box = minibox.basic[int]()
    let key_a = box.insert(100)
    let key_b = box.insert(200)
    var count = 0
    for key, value in box.pairs:
      if key == key_a: value.eq 100
      if key == key_b: value.eq 200
      count += 1
    count.eq 2

  it "must allow mutation with mitems", proc() =
    var box = minibox.basic[int]()
    discard box.insert(1)
    discard box.insert(2)
    for value in box.mitems:
      value *= 10
    var total = 0
    for value in box:
      total += value
    total.eq 30


describe "minibox.dense | Insert":
  it "must insert and retrieve a value", proc() =
    var box = minibox.dense[int]()
    let key = box.insert(42)
    box[key].eq 42

  it "must assign sequential indices", proc() =
    var box = minibox.dense[int]()
    let first = box.insert(10)
    let second = box.insert(20)
    first.index.eq 0u32
    second.index.eq 1u32

  it "must track length", proc() =
    var box = minibox.dense[int]()
    box.len.eq 0u32
    discard box.insert(1)
    box.len.eq 1u32

describe "minibox.dense | Access":
  it "must report contains for live keys", proc() =
    var box = minibox.dense[int]()
    let key = box.insert(5)
    box.contains(key).eq true
    box.contains(NullKey).eq false

describe "minibox.dense | Delete":
  it "must remove a value and decrement length", proc() =
    var box = minibox.dense[int]()
    let key = box.insert(42)
    box.delete(key)
    box.len.eq 0u32
    box.contains(key).eq false

  it "must reuse slots after deletion", proc() =
    var box = minibox.dense[int]()
    let first = box.insert(10)
    box.delete(first)
    let second = box.insert(20)
    second.index.eq first.index
    second.gen.eq first.gen + 1

  it "must preserve other values after swap-remove", proc() =
    var box = minibox.dense[int]()
    let key_a = box.insert(10)
    let key_b = box.insert(20)
    let key_c = box.insert(30)
    box.delete(key_a)
    box[key_b].eq 20
    box[key_c].eq 30

describe "minibox.dense | Iteration":
  it "must iterate all live values densely", proc() =
    var box = minibox.dense[int]()
    discard box.insert(10)
    discard box.insert(20)
    discard box.insert(30)
    var total = 0
    for value in box:
      total += value
    total.eq 60

  it "must not yield deleted values", proc() =
    var box = minibox.dense[int]()
    discard box.insert(10)
    let middle = box.insert(20)
    discard box.insert(30)
    box.delete(middle)
    var total = 0
    for value in box:
      total += value
    total.eq 40


describe "minibox.hop | Insert":
  it "must insert and retrieve a value", proc() =
    var box = minibox.hop[int]()
    let key = box.insert(42)
    box[key].eq 42

  it "must track length", proc() =
    var box = minibox.hop[int]()
    box.len.eq 0u32
    discard box.insert(1)
    box.len.eq 1u32

describe "minibox.hop | Access":
  it "must report contains for live keys", proc() =
    var box = minibox.hop[int]()
    let key = box.insert(5)
    box.contains(key).eq true
    box.contains(NullKey).eq false

describe "minibox.hop | Delete":
  it "must remove a value and decrement length", proc() =
    var box = minibox.hop[int]()
    let key = box.insert(42)
    box.delete(key)
    box.len.eq 0u32
    box.contains(key).eq false

  it "must reuse slots after deletion", proc() =
    var box = minibox.hop[int]()
    let first = box.insert(10)
    box.delete(first)
    let second = box.insert(20)
    second.index.eq first.index
    second.gen.eq first.gen + 1

describe "minibox.hop | Iteration":
  it "must iterate in index order", proc() =
    var box = minibox.hop[int]()
    discard box.insert(10)
    discard box.insert(20)
    discard box.insert(30)
    var values: seq[int]
    for value in box:
      values.add(value)
    values.eq @[10, 20, 30]

  it "must skip deleted slots during iteration", proc() =
    var box = minibox.hop[int]()
    discard box.insert(10)
    let middle = box.insert(20)
    discard box.insert(30)
    box.delete(middle)
    var values: seq[int]
    for value in box:
      values.add(value)
    values.eq @[10, 30]

  it "must maintain order after delete and reinsert", proc() =
    var box = minibox.hop[int]()
    let key_a = box.insert(10)
    discard box.insert(20)
    discard box.insert(30)
    box.delete(key_a)
    discard box.insert(99)
    var values: seq[int]
    for value in box:
      values.add(value)
    values.eq @[99, 20, 30]
