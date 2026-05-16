#:____________________________________________________________________
#  minibox  |  Copyright (C) Ivan Mar (sOkam!)  |  GPL-3.0-or-later  :
#:____________________________________________________________________
import ./key
export key


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
