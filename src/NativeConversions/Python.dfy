
include "../Wrappers.dfy"
include "Common.dfy"

module {:options "/functionSyntax:4"} PythonConversions {

  import opened Wrappers
  import opened Common

  function IncrementArguments(c: any, x: any): Result<(Cell, int), string> {
    var cell :- Cast<Cell>(c, "c must be a Cell");
    var xInt :- Cast<int>(x, "x must be an int");
    :- Need(0 <= xInt < 10, "x out of range");
    Success((cell, xInt))
  }

  method {:extern} Increment(cAny: any, xAny: any)
     modifies
      match IncrementArguments(cAny, xAny)
      case Success((c, x)) => {c}
      case _ => {}
    ensures 
      match IncrementArguments(cAny, xAny)
      case Success((c, x)) => c.data == old(c.data) + x 
      case _ => false
  {
    var maybeOptions: Result<(Cell, int), string> := IncrementArguments(cAny, xAny);
    var options := GetOrThrow(maybeOptions);
    var (c, x) := options;

    c.data := c.data + x; 
  }
}


