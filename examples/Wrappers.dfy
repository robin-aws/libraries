// RUN: %dafny /compile:3 "%s" > "%t"
// RUN: %diff "%s.expect" "%t"

include "../src/Wrappers.dfy"

module Demo {
  import opened Wrappers

  // ------ Demo for Option ----------------------------
  // We use Option when we don't need to pass around a reason for the failure,
  // ie when just 'None' is sufficient:

  class MyMap<K(==), V> {
    var m: map<K, V>
    constructor () {
      m := map[];
    }
    function method Get(k: K): Option<V>
      reads this
    {
      if k in m then Some(m[k]) else None()
    }
    method Put(k: K, v: V) 
      modifies this
    {
      this.m := this.m[k := v];
    }
  }

  method TestMyMap() {
    var m := new MyMap<string, string>();
    m.Put("message", "Hello");
    Greet(m);

    m.Put("name", "Dafny");
    Greet(m);
  }

  method Greet(m: MyMap<string, string>) {
    var o: Option<string> := m.Get("message");
    if o.Some? {
      print o.value, "\n";
    } else {
      print "oops\n";
    }

    var r: Result<string, string> := FindName(m);
    if r.Success? {
      print r.value, "\n";
    } else {
      print "Error: ", r.error, "\n";
    }
  }

  // Sometimes we want to go from Option to Result:
  method FindName(m: MyMap<string, string>) returns (res: Result<string, string>) {
    // Will return a default error message in case of None:
    res := m.Get("name").ToResult();
    // We can also match on the option to write a custom error:
    match m.Get("name")
    case Some(n) => res := Success(n);
    case None => res := Failure("'name' was not found");
  }

  // Propogating failures using :- statements
  method GetGreeting(m: MyMap<string, string>) returns (res: Option<string>) {
    var message: string :- m.Get("message");
    var nameResult := FindName(m);
    var name :- nameResult.ToOption();
    res := Some(message + " " + name);
  }

  // Covariance - we can assign an Option<Car> to an Option<Vehicle>
  // since Car is a subtype of Vehicle.
  method MaybeGetMeAVehicle() returns (vehicleOption: Option<Vehicle>) {
    var car := new Car();
    var carOption: Option<Car> := Some(car);
    // This line fails to type check without the "+T" declaration
    // on Option.
    vehicleOption := carOption;
  }

  trait Vehicle {}
  class Car extends Vehicle {
    constructor()
  }

  // ------ Demo for Result ----------------------------
  // We use Result when we want to give a reason for the failure:

  class MyFilesystem {
    var files: map<string, string>
    constructor() {
      files := map[];
    }

    // Result<()> is used to return a Result without any data
    method WriteFile(path: string, contents: string) returns (res: Result<(), string>)
      modifies this
    {
      if path in files {
        files := files[path := contents];
        res := Success(()); // `()` is the only value of type `()`
      } else {
        // The "Result" datatype allows us to give precise error messages
        // instead of just "None"
        res := Failure("File not found, use 'Create' before");
      }
    }

    method CreateFile(path: string) returns (res: Result<(), string>)
      modifies this
    {
      if path in files {
        res := Failure("File already exists");
      } else {
        files := files[path := ""];
        res := Success(());
      }
    }

    method ReadFile(path: string) returns (res: Result<string, string>) {
      if path in files {
        res := Success(files[path]);
      } else {
        res := Failure("File not found");
      }
    }
  }

  // Propogating failures using :- statements
  method CopyFile(fs: MyFilesystem, fromPath: string, toPath: string) returns (res: Result<(), string>)
    modifies fs
  {
    var contents :- fs.ReadFile(fromPath);
    var _ :- fs.CreateFile(toPath);
    var _ :- fs.WriteFile(toPath, contents);
    res := Success(());
  }

  method TestMyFilesystem() {
    var fs := new MyFilesystem();
    // Note: these verbose "outcome.Failure?" patterns will soon
    // not be needed any more, see https://github.com/dafny-lang/rfcs/pull/1
    var outcome: Result<(), string> := fs.CreateFile("test.txt");
    if outcome.Failure? {
      print outcome.error, "\n";
      return;
    }
    outcome := fs.WriteFile("test.txt", "Test dummy file");
    if outcome.Failure? {
      print outcome.error, "\n";
      return;
    }
    var fileResult: Result<string, string> := fs.ReadFile("test.txt");
    if outcome.Failure? {
      print fileResult.error, "\n";
      return;
    }
    if fileResult.Success? {
      print fileResult.value, "\n";
    }
  }

  method Main() {
    TestMyMap();
    TestMyFilesystem();
  }

}
