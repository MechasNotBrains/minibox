#:____________________________________________________________________
#  minibox  |  Copyright (C) Ivan Mar (sOkam!)  |  GPL-3.0-or-later  :
#:____________________________________________________________________


#_______________________________________
# @section Type Aliases
#_____________________________
type u32 * = uint32


#_______________________________________
# @section Key
#_____________________________
type Key * = object
  index  *:u32  ## Slot position within the container.
  gen    *:u32  ## Generation counter. Mismatches indicate a stale handle.

const NullKey * = Key(index: high(u32), gen: 0)

func isNull *(key :Key) :bool= key.index == high(u32)


#_______________________________________
# @section Slot
#_____________________________
type Slot [T] = object
  gen    :u32       ## Current generation of this slot.
  live   :bool      ## Whether this slot holds a live value.
  value  :T         ## Stored value (only valid when live == true).
  next   :u32       ## Next free slot index (only valid when live == false).


#_______________________________________
# @section Basic (generational arena)
#_____________________________
type Basic *[T] = object
  slots     :seq[Slot[T]]
  len       *:u32         ## Number of live elements.
  free_head :u32          ## Head of the freelist chain.


#_______________________________________
# @section Construction
#_____________________________
func basic *[T]() :Basic[T]=
  Basic[T](slots: @[], len: 0, free_head: high(u32))

func basic *[T](capacity :u32) :Basic[T]=
  result = Basic[T](slots: newSeq[Slot[T]](capacity), len: 0, free_head: 0)
  for id in 0..<capacity:
    result.slots[id].next = id + 1
  if capacity > 0:
    result.slots[capacity - 1].next = high(u32)


#_______________________________________
# @section Access
#_____________________________
func contains *[T](box :Basic[T]; key :Key) :bool=
  if key.isNull: return false
  if key.index >= box.slots.len.u32: return false
  let slot = box.slots[key.index]
  slot.live and slot.gen == key.gen

func `[]` *[T](box :Basic[T]; key :Key) :T=
  assert box.contains(key), "minibox: access with invalid key"
  box.slots[key.index].value

func `[]` *[T](box :var Basic[T]; key :Key) :var T=
  assert box.contains(key), "minibox: access with invalid key"
  box.slots[key.index].value

func `[]=` *[T](box :var Basic[T]; key :Key; value :T) :void=
  assert box.contains(key), "minibox: access with invalid key"
  box.slots[key.index].value = value


#_______________________________________
# @section Insert
#_____________________________
func insert *[T](box :var Basic[T]; value :T) :Key=
  if box.free_head == high(u32):
    let id = box.slots.len.u32
    box.slots.add Slot[T](gen: 0, live: true, value: value, next: high(u32))
    box.len += 1
    return Key(index: id, gen: 0)
  else:
    let id = box.free_head
    box.free_head = box.slots[id].next
    box.slots[id].live = true
    box.slots[id].value = value
    box.len += 1
    return Key(index: id, gen: box.slots[id].gen)


#_______________________________________
# @section Delete
#_____________________________
func delete *[T](box :var Basic[T]; key :Key) :void=
  if not box.contains(key): return
  box.slots[key.index].live = false
  box.slots[key.index].gen += 1
  box.slots[key.index].next = box.free_head
  box.free_head = key.index
  box.len -= 1


#_______________________________________
# @section Iteration
#_____________________________
iterator items *[T](box :Basic[T]) :T=
  for slot in box.slots:
    if slot.live:
      yield slot.value

iterator pairs *[T](box :Basic[T]) :(Key, T)=
  for id, slot in box.slots:
    if slot.live:
      yield (Key(index: id.u32, gen: slot.gen), slot.value)

iterator mitems *[T](box :var Basic[T]) :var T=
  for slot in box.slots.mitems:
    if slot.live:
      yield slot.value

iterator mpairs *[T](box :var Basic[T]) :(Key, var T)=
  for id in 0..<box.slots.len:
    if box.slots[id].live:
      yield (Key(index: id.u32, gen: box.slots[id].gen), box.slots[id].value)


#_______________________________________
# @section Sparse Slot (for Dense)
#_____________________________
type SparseSlot = object
  gen        :u32   ## Current generation of this slot.
  dense_id  :u32   ## Index into the dense array (only valid when live).
  live       :bool  ## Whether this slot holds a live value.
  next       :u32   ## Next free slot index (only valid when live == false).


#_______________________________________
# @section Dense (packed generational arena)
#_____________________________
type Dense *[T] = object
  sparse    :seq[SparseSlot]  ## Sparse array indexed by Key.index.
  dense     :seq[T]           ## Packed values. No holes.
  dense_ids :seq[u32]         ## Maps dense index -> sparse index (for swap-remove fixup).
  len       *:u32             ## Number of live elements.
  free_head :u32              ## Head of the freelist chain in sparse.


#_______________________________________
# @section Construction (Dense)
#_____________________________
func dense *[T]() :Dense[T]=
  Dense[T](sparse: @[], dense: @[], dense_ids: @[], len: 0, free_head: high(u32))

func dense *[T](capacity :u32) :Dense[T]=
  result = Dense[T](sparse: newSeq[SparseSlot](capacity), dense: @[], dense_ids: @[], len: 0, free_head: 0)
  for id in 0..<capacity:
    result.sparse[id].next = id + 1
  if capacity > 0:
    result.sparse[capacity - 1].next = high(u32)


#_______________________________________
# @section Access (Dense)
#_____________________________
func contains *[T](box :Dense[T]; key :Key) :bool=
  if key.isNull: return false
  if key.index >= box.sparse.len.u32: return false
  let slot = box.sparse[key.index]
  slot.live and slot.gen == key.gen

func `[]` *[T](box :Dense[T]; key :Key) :T=
  assert box.contains(key), "minibox: access with invalid key"
  box.dense[box.sparse[key.index].dense_id]

func `[]` *[T](box :var Dense[T]; key :Key) :var T=
  assert box.contains(key), "minibox: access with invalid key"
  box.dense[box.sparse[key.index].dense_id]


#_______________________________________
# @section Insert (Dense)
#_____________________________
func insert *[T](box :var Dense[T]; value :T) :Key=
  let dense_id = box.dense.len.u32
  box.dense.add value
  if box.free_head == high(u32):
    let id = box.sparse.len.u32
    box.sparse.add SparseSlot(gen: 0, dense_id: dense_id, live: true, next: high(u32))
    box.dense_ids.add id
    box.len += 1
    return Key(index: id, gen: 0)
  else:
    let id = box.free_head
    box.free_head = box.sparse[id].next
    box.sparse[id].dense_id = dense_id
    box.sparse[id].live = true
    box.dense_ids.add id
    box.len += 1
    return Key(index: id, gen: box.sparse[id].gen)


#_______________________________________
# @section Delete (Dense)
#_____________________________
func delete *[T](box :var Dense[T]; key :Key) :void=
  if not box.contains(key): return
  let sparse_id = key.index
  let dense_id = box.sparse[sparse_id].dense_id
  let last_dense = box.dense.len.u32 - 1
  # Swap-remove from dense array.
  if dense_id != last_dense:
    box.dense[dense_id] = box.dense[last_dense]
    box.dense_ids[dense_id] = box.dense_ids[last_dense]
    # Fix up the sparse slot that pointed to the moved element.
    box.sparse[box.dense_ids[dense_id]].dense_id = dense_id
  box.dense.setLen(box.dense.len - 1)
  box.dense_ids.setLen(box.dense_ids.len - 1)
  # Mark sparse slot as dead.
  box.sparse[sparse_id].live = false
  box.sparse[sparse_id].gen += 1
  box.sparse[sparse_id].next = box.free_head
  box.free_head = sparse_id
  box.len -= 1


#_______________________________________
# @section Iteration (Dense)
#_____________________________
iterator items *[T](box :Dense[T]) :T=
  for val in box.dense:
    yield val

iterator pairs *[T](box :Dense[T]) :(Key, T)=
  for id in 0..<box.dense.len:
    let sparse_id = box.dense_ids[id]
    yield (Key(index: sparse_id, gen: box.sparse[sparse_id].gen), box.dense[id])

iterator mitems *[T](box :var Dense[T]) :var T=
  for val in box.dense.mitems:
    yield val

iterator mpairs *[T](box :var Dense[T]) :(Key, var T)=
  for id in 0..<box.dense.len:
    let sparse_id = box.dense_ids[id]
    yield (Key(index: sparse_id, gen: box.sparse[sparse_id].gen), box.dense[id])


#_______________________________________
# @section Hop Slot
#_____________________________
type HopSlot [T] = object
  gen    :u32   ## Current generation of this slot.
  live   :bool  ## Whether this slot holds a live value.
  value  :T     ## Stored value (only valid when live == true).
  next   :u32   ## Next free slot (freelist chain, only when dead).
  skip   :u32   ## Next live slot index (for iteration). Points to self when live.


#_______________________________________
# @section Hop (skip-link generational arena)
#_____________________________
type Hop *[T] = object
  slots     :seq[HopSlot[T]]
  len       *:u32         ## Number of live elements.
  free_head :u32          ## Head of the freelist chain.
  head      :u32          ## First live slot index (entry point for iteration).


#_______________________________________
# @section Construction (Hop)
#_____________________________
func hop *[T]() :Hop[T]=
  Hop[T](slots: @[], len: 0, free_head: high(u32), head: high(u32))

func hop *[T](capacity :u32) :Hop[T]=
  result = Hop[T](slots: newSeq[HopSlot[T]](capacity), len: 0, free_head: 0, head: high(u32))
  for id in 0..<capacity:
    result.slots[id].next = id + 1
  if capacity > 0:
    result.slots[capacity - 1].next = high(u32)


#_______________________________________
# @section Access (Hop)
#_____________________________
func contains *[T](box :Hop[T]; key :Key) :bool=
  if key.isNull: return false
  if key.index >= box.slots.len.u32: return false
  let slot = box.slots[key.index]
  slot.live and slot.gen == key.gen

func `[]` *[T](box :Hop[T]; key :Key) :T=
  assert box.contains(key), "minibox: access with invalid key"
  box.slots[key.index].value

func `[]` *[T](box :var Hop[T]; key :Key) :var T=
  assert box.contains(key), "minibox: access with invalid key"
  box.slots[key.index].value


#_______________________________________
# @section Insert (Hop)
#_____________________________
func insert *[T](box :var Hop[T]; value :T) :Key=
  var id :u32
  if box.free_head == high(u32):
    id = box.slots.len.u32
    box.slots.add HopSlot[T](gen: 0, live: true, value: value, next: high(u32), skip: high(u32))
  else:
    id = box.free_head
    box.free_head = box.slots[id].next
    box.slots[id].live = true
    box.slots[id].value = value
    box.slots[id].skip = high(u32)
  box.len += 1
  # Maintain skip-link chain: insert into sorted linked list.
  if box.head == high(u32) or id < box.head:
    # New head.
    box.slots[id].skip = box.head
    box.head = id
  else:
    # Walk to find predecessor.
    var prev = box.head
    while box.slots[prev].skip != high(u32) and box.slots[prev].skip < id:
      prev = box.slots[prev].skip
    box.slots[id].skip = box.slots[prev].skip
    box.slots[prev].skip = id
  return Key(index: id, gen: box.slots[id].gen)


#_______________________________________
# @section Delete (Hop)
#_____________________________
func delete *[T](box :var Hop[T]; key :Key) :void=
  if not box.contains(key): return
  let id = key.index
  # Remove from skip-link chain.
  if box.head == id:
    box.head = box.slots[id].skip
  else:
    var prev = box.head
    while prev != high(u32) and box.slots[prev].skip != id:
      prev = box.slots[prev].skip
    if prev != high(u32):
      box.slots[prev].skip = box.slots[id].skip
  # Mark dead and push to freelist.
  box.slots[id].live = false
  box.slots[id].gen += 1
  box.slots[id].next = box.free_head
  box.free_head = id
  box.len -= 1


#_______________________________________
# @section Iteration (Hop)
#_____________________________
iterator items *[T](box :Hop[T]) :T=
  var cur = box.head
  while cur != high(u32):
    yield box.slots[cur].value
    cur = box.slots[cur].skip

iterator pairs *[T](box :Hop[T]) :(Key, T)=
  var cur = box.head
  while cur != high(u32):
    yield (Key(index: cur, gen: box.slots[cur].gen), box.slots[cur].value)
    cur = box.slots[cur].skip

iterator mitems *[T](box :var Hop[T]) :var T=
  var cur = box.head
  while cur != high(u32):
    yield box.slots[cur].value
    cur = box.slots[cur].skip

iterator mpairs *[T](box :var Hop[T]) :(Key, var T)=
  var cur = box.head
  while cur != high(u32):
    yield (Key(index: cur, gen: box.slots[cur].gen), box.slots[cur].value)
    cur = box.slots[cur].skip
