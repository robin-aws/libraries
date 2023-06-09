
include "ConcurrentMutableMap.dfy"
include "AtomicBox.dfy"
include "../BoundedInts.dfy"


module TTLCache {

  import opened DafnyLibraries
  import opened Wrappers
  import opened ConcurrentMutableMap
  import opened AtomicBox
  import opened BoundedInts
  import opened Actions
  
  class {:separated} Mutex {
    var locked: bool

    constructor() {
      locked := false;
    }

    method TryLock() returns (success: bool) 
      // Opaque:
      modifies this
    {
      if !locked {
        locked := true;
        return true;
      } else {
        return false;
      }
    }
    method Unlock()
      // Opaque:
      modifies this
    {
      locked := false;
    }
  }

  class Clock {
    static method {:extern} Timestamp() returns (r: int64)
  }

  const TTL_IN_NANOS: int64
  const TTL_GRACE_IN_NANOS: int64

  datatype State<T> = State(data: T, lastUpdatedNano: int64)
  datatype LockedState<T(==)> = LockedState(mutex: Mutex, state: State<T>) {
    method TryLock() returns (r: bool) {
      r := mutex.TryLock();
    }
    method Unlock() {
      mutex.Unlock();
    }
    method Update(data: T, createTimeNano: int64) returns (r: LockedState<T>) {
      // if (!lock.isHeldByCurrentThread()) {
      //   throw new IllegalStateException("Lock not held by current thread");
      // }
      r := this.(state := State(data, createTimeNano));
    }
  }

  class TTLCache<T(==)> {
    const cache: ConcurrentMutableMap<string, LockedState<T>>
    const lock: Mutex

    constructor() {
      cache := new ConcurrentMutableMap<string, LockedState<T>>();
    }

    method Load(key: string, f: string -> T) returns (r: T) {
      // (Pulling this to the top since we can't call it in expressions willy-nilly)
      var currentTime := Clock.Timestamp();
      var maybeLs := cache.Get(key);
      
      if maybeLs.None? {
        // The entry doesn't exist yet, so load a new one.
        r := LoadNewEntryIfAbsent(key, f, currentTime);
        return;
      }
      var ls := maybeLs.value;

      if (currentTime - ls.state.lastUpdatedNano > TTL_IN_NANOS + TTL_GRACE_IN_NANOS) {
        // The data has expired past the grace period.
        // Evict the old entry and load a new entry.
        cache.Remove(key);
        r := LoadNewEntryIfAbsent(key, f, currentTime);
        return;
      } else if (currentTime - ls.state.lastUpdatedNano <= TTL_IN_NANOS) {
        // The data hasn't expired. Return as-is from the cache.
        return ls.state.data;
      } else {
        var gotLock := ls.TryLock();
        if !gotLock {
          // We are in the TTL grace period. If we couldn't grab the lock, then some other
          // thread is currently loading the new value. Because we are in the grace period,
          // use the cached data instead of waiting for the lock.
          return ls.state.data;
        }
      }

      // This is true, but Dafny can't prove it.
      // The mutex's state is in an isolated subheap.
      // assert lock.locked

      // We are in the grace period and have acquired a lock.
      // Update the cache with the value determined by the loading function.
      // try {
      var loadedData: T := f(key);
      ls := ls.Update(loadedData, currentTime);
      return ls.state.data;
      // } finally {
      ls.Unlock();
      // }
    }

    // Not synchronized because we're relying on ConcurrentHashMap.GetOrCalculate() instead
    method LoadNewEntryIfAbsent(k: string, f: string -> T, timestampNano: int64) returns (r: T) {
      var maker := new LockedStateMaker(f, timestampNano);
      var ls := cache.GetOrCalculate(k, maker);
      r := ls.state.data;
    }
  }

  class LockedStateMaker<T(==)> extends Action<string, LockedState<T>> {
    const f: string -> T
    const timestampNano: int64

    constructor(f: string -> T, timestampNano: int64) {
      this.f := f;
      this.timestampNano := timestampNano;
    }

    method Invoke(key: string) returns (t: LockedState<T>) {
      var loadedData: T := f(key);
      var mutex := new Mutex();
      t := LockedState(mutex, State(loadedData, timestampNano));
    }
  }
}