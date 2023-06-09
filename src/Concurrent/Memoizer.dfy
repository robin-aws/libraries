


class {:separated} Memoizer<T(==), R(==)> {

  const f: T -> R
  var answers: map<T, R>

  predicate Valid() 
    reads this
  {
    forall t <- answers :: answers[t] == f(t)
  }

  constructor(f: T -> R) {
    this.f := f;
  }

  function Apply(t: T): R reads this requires Valid() {
    f(t)
  } by method {
    if t in answers {
      return answers[t];
    } else {
      var r := f(t);
      answers := answers[t := r];
      return r;
    }
  }
}