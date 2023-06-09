
include "../MutableMap/MutableMap.dfy"
include "Actions.dfy"

module ConcurrentMutableMap {

  import opened DafnyLibraries
  import opened Wrappers
  import opened Actions

  class {:separated} {:concurrent} ConcurrentMutableMap<K(==), V(==)> {

    var wrapped: MutableMapTrait<K, V>

    constructor() {
      // MutableMap is currently synchronized in native code (Java so far)
      // but doesn't have to be for this use case.
      // It should be possible to communicate to Dafny that a native
      // implementation is concurrency-safe as well.
      this.wrapped := new MutableMap();
    }

    // Not allowed: wrapped value may be shared unsafely.
    // If we tried this the verifier would complain.
    // constructor(wrapped: MutableMapTrait<K, V>) {
    //   this.wrapped := wrapped;
    // }

    // The {:separated} stay-fresh axiom: treat our Repr as permanently separated.
    lemma {:axiom} StayFresh() ensures fresh(wrapped)

    method Put(k: K, v: V) {
      StayFresh();

      wrapped.Put(k, v);
    }

    method Get(k: K) returns (v: Option<V>) {
      StayFresh();

      // TODO: Ideally MutableMap would have a Get(): Option<V> as well
      var present := wrapped.HasKey(k);
      if present {
        var value := wrapped.Select(k);
        v := Some(value);
      } else {
        v := None;
      }
    }

    method GetOrCalculate(k: K, f: Action<K, V>) returns (v: V) {
      StayFresh();
      
      var present := wrapped.HasKey(k);
      if present {
        v := wrapped.Select(k);
      } else {
        v := f.Invoke(k);
        wrapped.Put(k, v);
      }
    }

    method Remove(k: K) {
      StayFresh();
      
      wrapped.Remove(k);
    }
  }
}