module Actions {

  trait {:termination false} Action<T, R> {
    method Invoke(t: T) returns (r: R)
  }

}