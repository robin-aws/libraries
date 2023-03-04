
include "../Wrappers.dfy"
include "Common.dfy"

module {:options "/functionSyntax:4"} PythonConversions {

  import opened Wrappers
  import opened Common

  method {:extern} Increment(c: Cell, x: int)
    requires 0 <= x < 10
    modifies c
    ensures c.data == old(c.data) + x 
  {
    c.data := c.data + x; 
  }
}


