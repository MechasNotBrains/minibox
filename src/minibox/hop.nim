#:____________________________________________________________________
#  minibox  |  Copyright (C) Ivan Mar (sOkam!)  |  GPL-3.0-or-later  :
#:____________________________________________________________________
import ./key
export key


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
# @section Construction
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
# @section Access
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
# @section Insert
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
  if box.head == high(u32) or id < box.head:
    box.slots[id].skip = box.head
    box.head = id
  else:
    var prev = box.head
    while box.slots[prev].skip != high(u32) and box.slots[prev].skip < id:
      prev = box.slots[prev].skip
    box.slots[id].skip = box.slots[prev].skip
    box.slots[prev].skip = id
  return Key(index: id, gen: box.slots[id].gen)


#_______________________________________
# @section Delete
#_____________________________
func delete *[T](box :var Hop[T]; key :Key) :void=
  if not box.contains(key): return
  let id = key.index
  if box.head == id:
    box.head = box.slots[id].skip
  else:
    var prev = box.head
    while prev != high(u32) and box.slots[prev].skip != id:
      prev = box.slots[prev].skip
    if prev != high(u32):
      box.slots[prev].skip = box.slots[id].skip
  box.slots[id].live = false
  box.slots[id].gen += 1
  box.slots[id].next = box.free_head
  box.free_head = id
  box.len -= 1


#_______________________________________
# @section Iteration
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
