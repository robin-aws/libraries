
include "../Wrappers.dfy"
include "Common.dfy"

module {:options "/functionSyntax:4"} JavascriptConversions {

  import opened Wrappers
  import opened Common

  class JavascriptObject {
    predicate Contains(n: string)
    function Get(n: string): any requires Contains(n)
    function TryGet(n: string): Result<any, string>
  }

  function IncrementArguments(o: any): Result<(Cell, int), string> {
    var options :- Cast<JavascriptObject>(o, "argument must be an object");
    var c :- options.TryGet("c");
    var cell :- Cast<Cell>(c, "c must be a Cell");
    var x :- options.TryGet("x");
    var xInt :- Cast<int>(x, "x must be an int");
    :- Need(0 <= xInt < 10, "x out of range");
    Success((cell, xInt))
  }

  method {:extern} Increment(o: any)
    modifies
      match IncrementArguments(o)
      case Success((c, x)) => {c}
      case _ => {}
    ensures 
      match IncrementArguments(o)
      case Success((c, x)) => c.data == old(c.data) + x 
      case _ => false
  {
    var maybeOptions: Result<(Cell, int), string> := IncrementArguments(o);
    var options := GetOrThrow(maybeOptions);
    var (c, x) := options;
    c.data := c.data + x as int;
  }
}


