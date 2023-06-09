
module AtomicBox {

  class {:separated} {:concurrent} AtomicBox<T(==)> {

    // The {:separated} stay-fresh axiom: treat our Repr as permanently separated.
    lemma {:axiom} StayFresh() ensures fresh(this)

    ghost const inv: T -> bool
    var value: T

    constructor(value: T, ghost inv: T -> bool) 
      requires inv(value)
      ensures this.inv == inv
      ensures Valid()
    {
      this.value := value;
      this.inv := inv;
    }

    // {:concurrent} will require that the non-opaque preconditions
    // of every method/function are satisfied by the postconditions
    // of every method. In practice you'll almost always end up with a single Valid like this.
    ghost predicate Valid() 
      reads this
    {
      inv(value)
    }

    method Get() returns (t: T) 
      requires Valid()
      ensures inv(t)
      ensures Valid()
      // Opaque:
      ensures value == t
    {
      t := this.value;
    }

    method Put(newValue: T)
      requires Valid()
      requires inv(newValue)
      ensures Valid()
      // Opaque:
      modifies this
      ensures value == newValue
    {
      this.value := newValue;
    }

    method UpdateAndGet(f: T -> T) returns (newValue: T)
      requires Valid()
      requires forall t | inv(t) :: inv(f(t))
      ensures Valid()
      // Opaque:
      modifies this
      ensures value == f(old(value))
      ensures value == newValue
    {
      value := f(value);
      newValue := value;
    }
  }

}