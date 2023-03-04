method Main() {

    try {
        Test1();
    } recover (message: string) {
        print "Doh";
    }


}

method {:test} Test1() {
    expect 1 != 2;
}

method Main() {

    $foreach m <- Reflect.AllMethods() {
        try {
            $m.Name();
        } recover (message: string) {
            print "Doh";
        }
    }
}