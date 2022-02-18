
// include "../Actions.dfy"
include "../Frames.dfy"
include "../Wrappers.dfy"
include "../Collections/Sequences/Seq.dfy"

module Enumerators {

  // import opened Actions
  import opened Frames
  import opened Wrappers
  import opened Seq

  trait {:termination false} Enumerator<T> extends Validatable {
    
    // The Valid() predicate from the Validatable trait ends up
    // becoming the "enumeration invariant", which in turn becomes
    // the loop invariant in a while loop that uses an enumerator.

    ghost var enumerated: seq<T>

    // Any enumerator that produces one value at a time
    // and provably terminates is equivalent to an enumerator
    // that produces a specific seq<T>. This value may be underspecified
    // such that it is not known, even its length, until after all
    // values have been produced.
    // Dafny doesn't let you pass around an underspecified value though,
    // so we don't define a "to be enumerated" field or function.

    predicate method HasNext() 
      reads Repr
      requires Valid()
      decreases Repr, 0
      ensures Decreases() == 0 ==> !HasNext()

    method Next() returns (element: T)
      requires Valid()
      requires HasNext()
      modifies Repr
      decreases Repr
      ensures Valid()
      ensures Repr <= old(Repr)
      ensures Decreases() < old(Decreases())
      ensures enumerated == old(enumerated) + [element]

    // Would be better as an arbitrary termination clause somehow instead
    // https://github.com/dafny-lang/dafny/issues/762
    function Decreases(): nat
      reads Repr
      decreases Repr
      requires Valid()
  }

  // TODO: Common EagerEnumerator<T> that wraps a Enumerator<Option<T>>
  // for cases like Filter or IteratorAdaptor that can't calculate HasNext() 
  // ahead of time?

  class SeqEnumerator<T> extends Enumerator<T> {

    const elements: seq<T>
    var index: nat

    constructor(s: seq<T>) 
      ensures Valid()
      ensures fresh(Repr - {this})
      ensures enumerated == []
      ensures elements == s
    {
      elements := s;
      index := 0;

      enumerated := [];
      Repr := {this};
    }

    predicate Valid() 
      reads this, Repr 
      ensures Valid() ==> this in Repr 
      decreases Repr
    {
      && this in Repr
      && 0 <= index <= |elements|
      && enumerated == elements[0..index]
    }

    function Decreases(): nat
      reads Repr
      requires Valid()
    {
      |elements| - index
    }

    predicate method HasNext() 
      reads Repr
      requires Valid()
      decreases Repr, 0
      ensures Decreases() == 0 ==> !HasNext()
      ensures !HasNext() ==> enumerated == elements
    {
      index < |elements|
    }

    method Next() returns (element: T)
      requires Valid()
      requires HasNext()
      modifies Repr
      decreases Repr
      ensures Valid()
      ensures Repr <= old(Repr)
      ensures Decreases() < old(Decreases())
      ensures enumerated == old(enumerated) + [element]
    {
      element := elements[index];
      enumerated := enumerated + [element];
      index := index + 1;
    }
  }

  class SetEnumerator<T(==)> extends Enumerator<T> {
    ghost const original: set<T>
    var remaining: set<T>

    constructor(s: set<T>) 
      ensures Valid() 
      ensures fresh(Repr)
      ensures enumerated == []
      ensures original == s
    {
      this.original := s;
      this.remaining := s;

      enumerated := [];
      Repr := {this};
    }

    predicate Valid() 
      reads this, Repr 
      ensures Valid() ==> this in Repr
    {
      && this in Repr
      && multiset(enumerated) + multiset(remaining) == multiset(original)
    }

    predicate method HasNext()
      requires Valid()
      reads this, Repr
      decreases Repr, 0
      ensures Decreases() == 0 ==> !HasNext()
    {
      |remaining| > 0
    }

    method Next() returns (element: T)
      requires Valid()
      requires HasNext()
      modifies Repr
      decreases Repr
      ensures Valid()
      ensures Repr <= old(Repr)
      ensures Decreases() < old(Decreases())
      ensures enumerated == old(enumerated) + [element]
    {
      var picked: T :| picked in remaining;
      element := picked;
      remaining := remaining - {element};
      enumerated := enumerated + [element];
    }

    function Decreases(): nat 
      reads this, Repr
      requires Valid() 
    {
      |remaining|
    }
  }

  class MappingEnumerator<T, R> extends Enumerator<R> {
    const wrapped: Enumerator<T>
    const f: T -> R

    constructor(f: T -> R, wrapped: Enumerator<T>) 
      requires wrapped.Valid()
      requires wrapped.enumerated == []
      ensures Valid() 
      ensures fresh(Repr - wrapped.Repr)
      ensures enumerated == []
      ensures this.wrapped == wrapped
      ensures this.f == f
    {
      this.wrapped := wrapped;
      this.f := f;
      Repr := {this} + wrapped.Repr;
      enumerated := [];
    }

    predicate Valid() 
      reads this, Repr 
      ensures Valid() ==> this in Repr
      decreases Repr
    {
      && this in Repr
      && ValidComponent(wrapped)
      && enumerated == Seq.Map(f, wrapped.enumerated)
    }

    predicate method HasNext()
      reads Repr
      requires Valid()
      decreases Repr, 0
      ensures Decreases() == 0 ==> !HasNext()
    {
      wrapped.HasNext()
    }

    method Next() returns (element: R)
      requires Valid()
      requires HasNext()
      modifies Repr
      decreases Repr
      ensures Valid()
      ensures Repr <= old(Repr)
      ensures Decreases() < old(Decreases())
      ensures enumerated == old(enumerated) + [element]
    {
      var t := wrapped.Next();
      element := f(t);
      enumerated := enumerated + [element];
    }

    function Decreases(): nat 
      reads this, Repr
      requires Valid() 
    {
      wrapped.Decreases()
    }
  }

  class ConcatEnumerator<T> extends Enumerator<T> {

    // TODO: Unset once each is Done() to allow garbage collection?
    const first: Enumerator<T>
    const second: Enumerator<T>

    constructor(first: Enumerator<T>, second: Enumerator<T>)
      requires first.Valid()
      requires second.Valid()
      requires first.Repr !! second.Repr
      ensures Valid() 
      ensures fresh(Repr - first.Repr - second.Repr) 
      ensures this.first == first
      ensures this.second == second
    {
      this.first := first;
      this.second := second;
      
      enumerated := first.enumerated + second.enumerated;
      Repr := {this} + first.Repr + second.Repr;
    }

    predicate Valid() reads this, Repr ensures Valid() ==> this in Repr {
      && this in Repr
      && ValidComponent(first)
      && ValidComponent(second)
      && first.Repr !! second.Repr
      // && (first.HasNext() ==> second.enumerated == [])
      && enumerated == first.enumerated + second.enumerated
    }

    predicate method HasNext()
      requires Valid()
      reads this, Repr
      decreases Repr, 0
      ensures Decreases() == 0 ==> !HasNext()
    {
      first.HasNext() || second.HasNext()
    }

    method Next() returns (element: T)
      requires Valid()
      requires HasNext()
      modifies Repr
      decreases Repr
      ensures Valid()
      ensures Repr <= old(Repr)
      ensures Decreases() < old(Decreases())
      ensures enumerated == old(enumerated) + [element]
    {
      if first.HasNext() {
        element := first.Next();
      } else {
        element := second.Next();
      }

      Repr := {this} + first.Repr + second.Repr;
      enumerated := enumerated + [element];
    }

    function Decreases(): nat 
      reads this, Repr 
      requires Valid() 
    {
      first.Decreases() + second.Decreases()
    }
  }

  // TODO: Prove the semantics!
  class Filter<T> extends Enumerator<T> {
    const wrapped: Enumerator<T>
    const filter: T -> bool
    var next: Option<T>

    constructor(wrapped: Enumerator<T>, filter: T -> bool) 
      requires wrapped.Valid()
      requires wrapped.enumerated == []
      modifies wrapped.Repr
      ensures Valid()
    {
      this.wrapped := wrapped;
      this.filter := filter;
      this.next := None;
      Repr := {this} + wrapped.Repr;
      enumerated := [];
      new;
      FindNext();
    }

    predicate Valid() reads this, Repr ensures Valid() ==> this in Repr {
      && this in Repr
      && ValidComponent(wrapped)
      // && (if next.Some? then enumerated + [next.value] else enumerated) == Seq.Filter(filter, wrapped.enumerated)
    }

    predicate method HasNext()
      reads Repr
      requires Valid()
      decreases Repr, 0
      ensures Decreases() == 0 ==> !HasNext()
    {
      next.Some?
    }

    method Next() returns (element: T)
      requires Valid()
      requires HasNext()
      modifies Repr
      decreases Repr
      ensures Valid()
      ensures Repr <= old(Repr)
      ensures Decreases() < old(Decreases())
      ensures enumerated == old(enumerated) + [element]
    {
      element := next.value;
      enumerated := enumerated + [element];

      FindNext();
    }

    method FindNext() 
      requires Valid()
      modifies Repr
      decreases Repr, 0
      ensures Valid()
      ensures Repr <= old(Repr)
      ensures old(next.Some?) ==> Decreases() < old(Decreases())
      ensures unchanged(this`enumerated)
    {
      // TODO: Had to unroll the loop a bit to prove that Decreases() decreases,
      // is it possible to clean this up?
      if (!wrapped.HasNext()) {
        next := None;
      } else {
        var t := wrapped.Next();
        if filter(t) {
          next := Some(t);
        }
        while (wrapped.HasNext() && next.None?)
          invariant Valid()
          invariant wrapped.Repr < old(Repr)
          invariant Repr == old(Repr)
          invariant unchanged(this`enumerated)
          decreases wrapped.Decreases()
        {
          var t := wrapped.Next();
          if filter(t) {
            next := Some(t);
          }
        }
      }
    }

    function Decreases(): nat 
      reads this, Repr
      requires Valid() 
    {
      wrapped.Decreases() + (if next.Some? then 1 else 0)
    }
  }

  method CollectToSeq<T>(e: Enumerator<T>) returns (s: seq<T>)
    requires e.Valid()
    // TODO: Might remove this
    requires e.enumerated == []
    modifies e.Repr
    ensures e.Valid()
    ensures !e.HasNext()
    ensures s == e.enumerated
  {
    s := [];
    while (e.HasNext())
      invariant e.Valid() && e.Repr <= old(e.Repr)
      decreases e.Decreases()

      invariant s == e.enumerated
    {
      var element := e.Next();
      s := s + [element];
    }
  }

  method Max(s: set<int>) returns (max: int)
    requires |s| > 0
    ensures max in s
    ensures forall x | x in s :: max >= x
  {
    var first: int :| first in s;
    max := first;
    var rest := s - {max};

    var sEnum: SetEnumerator<int> := new SetEnumerator(rest);
    while (sEnum.HasNext()) 
      invariant sEnum.Valid()
      invariant fresh(sEnum.Repr)
      invariant max == Seq.Max([first] + sEnum.enumerated)
      decreases sEnum.Decreases()
    {
      var element := sEnum.Next();

      if max < element {
        max := element;
      }
    }
    assert max == Seq.Max([first] + sEnum.enumerated);
    assert multiset(sEnum.enumerated) == multiset(rest);
  }

  method Example1() {
    var numbers := [1, 2, 3, 4, 5];

    var e: Enumerator<int> := new SeqEnumerator(numbers);
    while (e.HasNext()) 
      invariant e.Valid() && fresh(e.Repr)
      decreases e.Decreases()
    {
      var element := e.Next();

      print element, "\n";
    }
  }

  method Example2() {
    var first := [1, 2, 3, 4, 5];
    var second := [6, 7, 8];
    var e1 := new SeqEnumerator(first);
    var e2 := new SeqEnumerator(second);
    var e := new ConcatEnumerator(e1, e2);
   
    while (e.HasNext()) 
      invariant e.Valid() && fresh(e.Repr)
      decreases e.Decreases()
    {
      var element := e.Next();

      print element, "\n";
    }
  }

  method PrintWithCommas() {
    var first := [1, 2, 3, 4, 5];
    var e := new SeqEnumerator(first);
   
    while (e.HasNext()) 
      invariant e.Valid() && fresh(e.Repr)
      decreases e.Decreases()
    {
      var element := e.Next();

      print element;
      if e.HasNext() {
        print ", ";
      }
    }
    print "\n";
  }

  method MappingExample() {
    var first := [1, 2, 3, 4, 5];
    var e1 := new SeqEnumerator(first);
    var e := new MappingEnumerator(x => x + 2, e1);
   
    var result: seq<int> := [];
    while (e.HasNext()) 
      invariant e.Valid() && fresh(e.Repr)
      decreases e.Decreases()
    {
      var element := e.Next();

      result := result + [element];
    }
    assert e.enumerated == Seq.Map(x => x + 2, first);
  }

  // TODO: Explicit example of working with lazy iterators, more emphasis on `HasNext` being a pure function
  // TODO: Need to give background on Validatable, the fact that Valid() is the loop invariant
  // TODO: Mention `enumerated` ghost variable, proving semantics based on that
  // TODO: Are ghost enumerators a thing? :)
  // TODO: Most enumerator constructors should ensure enumerated == [] and other things
  //       Important to have end to end examples to ensure correctness invariants are actually usable!
  // TODO: Framing invariant is a pain in the butt, seems to need a label to be generic
}