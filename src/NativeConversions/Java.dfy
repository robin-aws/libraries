
include "../Wrappers.dfy"
include "Common.dfy"

module JavaConversions {

  import opened Wrappers
  import opened Common

  method {:extern} Increment(c: Cell?, x: int)
    modifies 
      if c != null && 0 <= x < 10 then {c} else {}
    ensures 
      if c != null && 0 <= x < 10 then
        c.data == old(c.data) + x 
      else
        false
  {
    ThrowUnless(c != null, "No nulls dammit!");
    ThrowUnless(0 <= x < 10, "x out of range");

    c.data := c.data + x; 
  }
}