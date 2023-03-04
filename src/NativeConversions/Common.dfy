
include "../Wrappers.dfy"

module Common {

  import opened Wrappers

  type any = object
  
  function Cast<R>(value: any, error: string): Result<R, string> {
    if value is R then Success(value as R) else Failure(error)
  }
    // Not actually implementable yet

  trait {:extern} Exception {}
  class {:extern} RuntimeException extends Exception {
    constructor {:extern} (s: string)
  }

  method {:extern} Throw(e: Exception) ensures false

  method ThrowUnless(p: bool, message: string)
    ensures p
  {
    if !p {
      var e := new RuntimeException(message);
      Throw(e);
    }
  }

  method GetOrThrow<T>(r: Result<T, string>) returns (value: T) 
    ensures r.Success? ==> value == r.value
    ensures r.Failure? ==> false
  {
    match r {
      case Success(value) => return value;
      case Failure(message) => {
        var e := new RuntimeException(message);
        Throw(e);
      }
    }
  }

  class Cell {
    var data: int
  }
}