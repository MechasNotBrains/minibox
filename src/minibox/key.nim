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
