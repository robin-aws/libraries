

// Append-only sequence
class {:separated} ConcurrentJournal<T> {

  var elements: seq<T>

  constructor()
    ensures elements == []
  {
    elements := [];
  }

  twostate predicate Invariant()
    reads this
  {
    && old(elements) <= elements
  }

  method Add(e: T)
    modifies this
    ensures Invariant()

    // Sequential version - will verify against the body of the method,
    // but not be true in concurrent mode.
    // ensures events == old(events) + [e]

    // This is the weakened form that clients assume externally instead.
    // Follows from the combination of the sequential ensures plus the twostate invariant.
    ensures exists others :: elements == old(elements) + [e] + others
  {
    elements := elements + [e];
    assert elements == old(elements) + [e] + [];
  }

  twostate predicate AddedWith(p: T -> bool) 
    reads this
    requires Invariant()
  {
    exists e <- elements[|old(elements)|..] :: p(e)
  }
}

// "Some subset of indexes exist such that those elements in order
//  satsify this list of predicates"
// (Name needs improving)
predicate ContainsWith<T>(ts: seq<T>, s: seq<T -> bool>) {
  if |ts| == 0 then
    |s| == 0
  else
    || ContainsWith(ts[1..], s)
    || (0 < |s| && s[0](ts[0]) && ContainsWith(ts[1..], s[1..]))
}

method HistoryClient() {
  var history := new ConcurrentJournal();
  assert |history.elements| == 0;

  history.Add(42);

  assert 42 in history.elements;
  // Not necessarily true:
  // assert history.elements == [42];

  DoThing(history);
  // True, but will likely need a lemma or two connecting
  // AddedWith to ContainesWith in order to verify
  assert ContainsWith(history.elements, [
    (x1: int) => x1 == 42,
    (x2: int) => x2 > 10
  ]);
}


method DoThing(history: ConcurrentJournal<int>)
  modifies history
  ensures history.Invariant()
  ensures history.AddedWith((e: int) => 10 < e)
{
  // ...

  history.Add(20);
  // Also needs help to verify
  assert history.AddedWith((e: int) => 10 < e);
}