#====================================================================
#
#        Chain - Nim's function chaining and method cascading
#                 (c) Copyright 2021 Ward
#
#====================================================================

import macros, strutils

proc deunderscore(x, n: NimNode): NimNode =
  # Remove underscore (replace into x)
  result = n

  # replace `_` to the symbol x
  if n.kind == nnkIdent:
    if n.eqIdent("_"):
      result = x

  # for nested chain, only replace `_` for first arg.
  elif n.kind in nnkCallKinds and (n[0].eqIdent("chain") or n[0].eqIdent("chained")):
    n[1] = x.deunderscore(n[1])

  elif n.len != 0:
    for i in 0..<n.len:
      n[i] = x.deunderscore(n[i])

proc methodize(x, call: NimNode): NimNode =
  # Convert all call, asign, or dot into method syntax with x, including try, defer, block, etc
  # Exceptions: starting with "_.", "chain", or chained
  var call = call
  if call.len == 0:
    call = x.newDotExpr(call)

  elif call.kind in nnkCallKinds + {nnkAsgn, nnkDotExpr}:
    if not (call[0].eqIdent("_") or call[0].eqIdent("chain") or call[0].eqIdent("chained")):
      call[0] = x.methodize(call[0])

  elif call.kind in {nnkStmtList, nnkDefer, nnkTryStmt, nnkFinally, nnkIfStmt, nnkWhenStmt, nnkElse}:
    for i in 0..<call.len:
      call[i] = x.methodize(call[i])

  elif call.kind in {nnkBlockStmt, nnkElifBranch, nnkWhileStmt, nnkOfBranch}:
    call[1] = x.methodize(call[1])

  elif call.kind == nnkExceptBranch:
    if call.len == 2:
      call[1] = x.methodize(call[1])
    else:
      call[0] = x.methodize(call[0])

  elif call.kind == nnkForStmt:
    call[2] = x.methodize(call[2])

  elif call.kind == nnkCaseStmt:
    for i in 1..<call.len:
      call[i] = x.methodize(call[i])

  result = x.deunderscore(call)

macro chainimpl(x: untyped, calls: varargs[untyped]): untyped =
  # Support both parameters(chain(f, setColor(2, 3, 4), setPosition(0.0, 1.0))) or block format
  result = newStmtList()

  for call in calls:
    if call.kind == nnkStmtList:
      for i in call:
        result.add methodize(x, i)
    else:
      result.add methodize(x, call)

macro chainraw(expression, returnable: bool, x: untyped, calls: varargs[untyped]): untyped =
  var id: NimNode
  result = newStmtList()

  if x.kind == nnkInfix and x[0].kind == nnkIdent and x[0].eqIdent("as"):
    # For "exp as ident" syntax, assign exp to ident (create if necessary)
    let exp = x[1]
    id = x[2]

    result.add quote do:
      when (compiles do: `id` = `exp`):
        `id` = `exp`
      else:
        var `id` {.inject.} = `exp`
      chainimpl(`id`, `calls`)

  elif expression.boolVal:
    # If x is expression, we need a anonymous variable to avoid evaluating repeatedly.
    # However, a gensym'ed symbols cannot pass into another macro (got undeclared identifier error).
    # So we need to create our own hygienic symbol.
    id = ident(genSym(nskVar, "anonymous").repr) # a trick to create anonymous_xxxxx
                                                 # not 100%, but good enough
    result.add quote do:
      var `id` {.used.} = `x`
      chainimpl(`id`, `calls`)

  else:
    # If x is an variable, don't worry about evaluating repeatedly.
    id = x
    result.add quote do:
      chainimpl(`id`, `calls`)

  if returnable.boolVal:
    result.add quote do:
      `id`

template chain*(x: untyped, calls: varargs[untyped]): untyped =
  ## Similar to std/with, but more powerful.
  ## Features:
  ##  * Parameters syntax or block syntax (like std/with).
  ##  * `as` syntax to create named variable that can be used in block.
  ##  * Expressions will be only evaluate one time (by create anonymous variable).
  ##  * Nested fields, nested calls, and nested chain.
  ##  * Underscore can be used anywhere to represent `this` object.
  ##  * Works in control flow statements, including block, try/except/finally, defer, if, when, for, while, case, etc.
  ## Use `chain` wisely can improve readability, but overuse may lead opposite effect.
  when compiles(x.astToStr):
    # if x is stmtList, it must be from template -> consider it as expressions.
    when compiles(unsafeaddr x) and countLines(x.astToStr) == 1:
      chainraw(false, false, x, calls)
    else:
      chainraw(true, false, x, calls)
  else: # `as` syntax goes here
    chainraw(true, false, x, calls)

template chained*(x: untyped, calls: varargs[untyped]): untyped =
  ## Just like chain, but returns the value at last.
  # when compiles(unsafeaddr x) and countLines(x.astToStr) == 1:
  when compiles(x.astToStr):
    when compiles(unsafeaddr x) and countLines(x.astToStr) == 1:
      chainraw(false, true, x, calls)
    else:
      chainraw(true, true, x, calls)
  else:
    chainraw(true, true, x, calls)
