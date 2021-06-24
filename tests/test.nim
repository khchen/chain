#====================================================================
#
#        Chain - Nim's function chaining and method cascading
#                 (c) Copyright 2021 Ward
#
#====================================================================

import unittest, chain, std/with

when (compiles do: import wNim/[wFrame, wButton]):
  import wNim/[wFrame, wButton]

suite "Test Suites for Chain":
  setup:
    type
      Object = object
        data: int
        child: Child

      Child = object
        data: int

    proc inc(o: var Object, value = 1) {.used.} = o.data.inc(value)
    proc dec(o: var Object, value = 1) {.used.} = o.data.dec(value)

  test "Parameters or block syntax.":
    var a1 = 44
    chain(a1, +=4, -=5)

    var o1 = Object(data: 1)
    chain(o1, inc(2), dec(1))

    check:
      a1 == 43
      o1 == Object(data: 2)

    var a2 = 44
    chain a2:
      += 4
      -= 5

    var o2 = Object(data: 1)
    chain o2:
      inc 2
      dec 1

    check:
      a2 == 43
      o2 == Object(data: 2)

  test "`as` syntax to create named variable that can be used in block.":
    chain("a" as s, add "b", add "c")
    check s == "abc"

    chain Object() as o:
      data = 1
      (check o == Object(data: 1))
      (check _ == Object(data: 1))
      data = 2
      (check o == Object(data: 2))
      (check _ == Object(data: 2))
      chain _.child:
        data = 3
      (check o.child == Child(data: 3))

    check o == Object(data: 2, child: Child(data: 3))

  test "Expressions will be only evaluate one time.":
    var count1, count2: int
    template next1(): int = count1.inc; count1
    template next2(): int = count2.inc; count2
    proc nop(x: int) = discard

    with next1:
      nop; nop; nop

    chain next2:
      nop; nop; nop

    check:
      count1 == 3
      count2 == 1

  test "Nested fields, calls, and nested chain.":
    var o1 = Object()
    chain o1:
      child.data = 1

    var o2 = chained Object():
      child.data = 1

    var o3 = Object()
    chain o3:
      chain _.child:
        data = 1

    var o4 = chained Object():
      child = chained Child():
        data = 1

    check:
      o1 == Object(child: Child(data: 1))
      o2 == Object(child: Child(data: 1))
      o3 == Object(child: Child(data: 1))
      o4 == Object(child: Child(data: 1))

    proc selfcheck(o: Object) = check o.data == 1
    proc dup(o: Object): Object = Object(data: o.data)

    chain Object(data: 1):
      selfcheck
      selfcheck()
      dup.selfcheck
      dup.selfcheck()
      dup().selfcheck
      dup().selfcheck()
      dup.dup().dup.selfcheck

  test "Underscore can be used anywhere to represent `this` object.":
    chain "abc":
      chain _ & "def":
        &= "ghi"
        _.add _
        _[0] = 'z'
        (check _ == "zbcdefghiabcdefghi")

    chain "abc":
      (check _ == "abc")
      chain "def":
        (check _ == "def")

    var o = Object()
    chain o:
      data = 1
      (check _ == Object(data: 1))
      _.data = 2
      (check _ == Object(data: 2))

      child = Child()
      chain _.child:
        data = 1
        (check _ == Child(data: 1))
        _.data = 2
        (check _ == Child(data: 2))

  test "Works in control flow statements.":
    var o: array[15, Object]

    chain o[0]:
      block:
        data = 1

    block:
      chain o[1]:
        defer:
          data = 1

    chain o[2]:
      try: data = 1
      except: discard

    chain o[3]:
      try:
        data = 2
        raise newException(ValueError, "")
      except ValueError:
        data = 1

    chain o[4]:
      try:
        data = 2
        raise newException(ValueError, "")
      except:
        data = 3
      finally:
        data = 1

    chain o[5]:
      if true: data = 1
      else: data = 2

    chain o[6]:
      if false: data = 2
      elif true: data = 1
      else: data = 3

    chain o[7]:
      if false: data = 2
      elif false: data = 3
      else: data = 1

    chain o[8]:
      when true: data = 1
      else: data = 2

    chain o[9]:
      when false: data = 2
      elif true: data = 1
      else: data = 3

    chain o[10]:
      for i in 1..1:
        data = i

    chain o[11]:
      while true:
        data = 1
        break

    chain o[12]:
      case _.data:
      of 0: data = 1
      else: data = 2

    chain o[13]:
      case _.data:
      of 1: data = 2
      else: data = 1

    chain o[14]:
      block:
        defer:
          try: discard
          finally:
            if true:
              when true:
                for i in 1..1:
                  while true:
                    data = 1
                    break

    for i in o:
      check i == Object(data: 1)

  when declared(wFrame):
    test "Works with wNim.":
      chain Frame(): # don't use as to check anonymous variable
        title = "Frame"

        chain Button(_) as button:
          label = "Button"

        proc layout() =
          _.autolayout "HV: |[button]|"

        (layout())

      check:
        button.label == "Button"
        button.parent.title == "Frame"
        button.size == button.parent.clientSize
