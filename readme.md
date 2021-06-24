# Chain
For object oriented programming, function chaining and method cascading syntax is really convenient. We already have [`std/with`](https://nim-lang.github.io/Nim/with.html) and [`cascade`](https://github.com/citycide/cascade). However, when I use them to write real GUI program (for example, [wNim](https://github.com/khchen/wNim)), both of them have a lot of limit. So I write this `chain` macro, which is designed to be drop-in replacement for these two module, and more powerful.

Features:
  * Parameters syntax or block syntax (like `std/with`).
  * `as` syntax to create named variable that can be used in block.
  * Expressions will be evaluated only one time (by create anonymous variable).
  * Nested fields, nested calls, and nested chain.
  * Underscore can be used anywhere to represent `this` object.
  * Works in control flow statements, including block, try/except/finally, defer, if, when, for, while, case, etc.

Notice: using `chain` wisely can improve readability, but overuse may lead opposite effect.

## Basic Usage
Replace `std/with`:
```nim
var x = "yay"
chain x:
  add "abc"
  add "efg"
doAssert x == "yayabcefg"
```

Replace `cascade`:
```nim
chain Button() as btn: # btn can be used inside and outside the block
  text = "ok"
  width = 30
  color = "#13a89e"
  enable()
```
or
```nim
var btn = chained Button(): # btn cannot be used inside the block
  text = "ok"
  width = 30
  color = "#13a89e"
  enable()
```

I recommend `chain ... as` instead of `chained` because it is more convenient. However, the choice is yours.

## Features in detail
* Parameters syntax.
  ```nim
    var a = 44
    chain(a, +=4, -=5)
    doAssert a == 43

    type Point = object
      x, y: int

    proc setX(pt: var Point, x: int) = pt.x = x
    proc setY(pt: var Point, y: int) = pt.y = y

    chain(Point() as pt, setX(1), setY(2))
    doAssert pt == Point(x: 1, y: 2)
  ```

* Block syntax.
  ```nim
    chain 44 as a:
      +=4
      -=5
    doAssert a == 43

    chain Point() as pt:
      setX(1)
      setY(2)
    doAssert pt == Point(x: 1, y: 2)
  ```

* `chain` can accept both variable or expression. For expression, unlike `std/with`, it will be evaluate only one time.
  ```nim
    var count1, count2: int
    template next1(): int = count1.inc; count1
    template next2(): int = count2.inc; count2
    proc nop(x: int) = discard

    with next1: # std/with will call next1() three times
      nop; nop; nop

    chain next2: # chain will call next2() only one time
      nop; nop; nop

    doAssert count1 == 3
    doAssert count2 == 1
  ```

* Nested fields, nested calls, and nested chain. In summary, `chain` add `_.` to every calls and assignments, except `chain`, `chained`, and `_`(underscore).
  ```nim
    # pseudocode
    chain a:
      b.c.d = e
      f.g.h()
      chain i:
        j.k.l = m
        n.o.p()
  ```
  To add a expression without `_.`, use parentheses to enclose it.
  ```nim
    chain Point() as pt:
      x = 1
      _.x = 1
      (pt.x = 1)
      # all the same
  ```

* Underscore can be used anywhere to represent `this` object.
  ```nim
    chain "abc":
      (doAssert _ == "abc")
      chain "def":
        (doAssert _ == "def")

    chain "abc":
      chain _ & "def":
        &= "ghi"
        _.add _
        _[0] = 'z'
        (doAssert _ == "zbcdefghiabcdefghi")
  ```

* Works in control flow statements, including block, try/except/finally, defer, if, when, for, while, case, etc.
  ```nim
    chain 1:
      block:
        +=1
        defer:
          +=1
          try:
            +=1
          finally:
            +=1
            if true:
              +=1
              when true:
                +=1
                for i in 1..1:
                  +=1
                  while true:
                    +=1
                    break

      (doAssert _ == 9)
  ```

* GUI example.
   ```nim
    import wNim/[wApp, wFrame, wMenuBar, wMenu]
    import chain

    chain App():
      chain Frame():
        title = "wNim"
        size = (640, 480)

        wIdExit do ():
          _.close()

        chain MenuBar(_):
          chain Menu(_, "&File"):
            append(wIdOpen, "&Open")
            appendSeparator()
            append(wIdExit, "E&xit")

        show()
        center()

      mainLoop()

   ```

## License
Read license.txt for more details.

Copyright (c) 2021 Kai-Hung Chen, Ward. All rights reserved.
