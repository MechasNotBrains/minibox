#:____________________________________________________________________
#  minibox  |  Copyright (C) Ivan Mar (sOkam!)  |  GPL-3.0-or-later  :
#:____________________________________________________________________
import ./key
export key


#_______________________________________
# @section Sparse Slot
#_____________________________
type SparseSlot = object
  gen       :u32   ## Current generation of this slot.
  dense_id  :u32   ## Index into the dense array (only valid when live).
  live      :bool  ## Whether this slot holds a live value.
  next      :u32   ## Next free slot index (only valid when live == false).


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
# @section Construction
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
# @section Access
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
# @section Insert
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
# @section Delete
#_____________________________
func delete *[T](box :var Dense[T]; key :Key) :void=
  if not box.contains(key): return
  let sparse_id = key.index
  let dense_id = box.sparse[sparse_id].dense_id
  let last_dense = box.dense.len.u32 - 1
  if dense_id != last_dense:
    box.dense[dense_id] = box.dense[last_dense]
    box.dense_ids[dense_id] = box.dense_ids[last_dense]
    box.sparse[box.dense_ids[dense_id]].dense_id = dense_id
  box.dense.setLen(box.dense.len - 1)
  box.dense_ids.setLen(box.dense_ids.len - 1)
  box.sparse[sparse_id].live = false
  box.sparse[sparse_id].gen += 1
  box.sparse[sparse_id].next = box.free_head
  box.free_head = sparse_id
  box.len -= 1


#_______________________________________
# @section Iteration
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
