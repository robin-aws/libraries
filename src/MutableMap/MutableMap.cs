/*******************************************************************************
*  Copyright by the contributors to the Dafny Project
*  SPDX-License-Identifier: MIT
*******************************************************************************/

using System.Numerics;
using System.Collections.Generic;
using System.Collections.Concurrent;

namespace DafnyLibraries {

  partial class MutableMap<K, V> {

    // TODO: Verify non-Concurrent is safe
    Dictionary<K, V> m = new Dictionary<K, V>();

    public Dafny.IMap<K,V> content() {
      var list = new List<Dafny.Pair<K, V>>();
      foreach (var entry in m) {
        list.Add(new Dafny.Pair<K, V>(entry.Key, entry.Value));
      }
      // TODO: deal with null keys
      return Dafny.Map<K, V>.FromCollection(list);
    }

    public void Put(K k, V v) {
      m[k] = v;
    }

    public Dafny.ISet<K> Keys() {
      // TODO: deal with null keys
      return Dafny.Set<K>.FromCollection(m.Keys);
    }

    public bool HasKey(K key) {
      return m.ContainsKey(key);
    }

    public Dafny.ISet<V> Values() {
      // TODO: deal with null keys
      return Dafny.Set<V>.FromCollection(m.Values);
    }

    public Dafny.ISet<_System._ITuple2<K,V>> Items() {
      var list = new List<_System.Tuple2<K, V>>();
      foreach (var entry in m) {
        list.Add(new _System.Tuple2<K, V>(entry.Key, entry.Value));
      }
      // TODO: deal with null keys
      return Dafny.Set<_System.Tuple2<K, V>>.FromCollection(list);
    }

    public V Select(K k) {
      // This should always succeed because of the Dafny pre-condition
      var success = m.TryGetValue(k, out var result);
      if (!success) {
        throw new Dafny.HaltException($"key missing from MutableMap: {k}");
      }
      return result;
    }

    public void Remove(K k) {
      m.Remove(k);
    }

    public BigInteger Size() {
      return new BigInteger(m.Count);
    }
  }
}