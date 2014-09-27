//
//  Identity.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-09-26.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// The identity function, which returns its argument.
///
/// This can be used to prove to the typechecker that a given type A is
/// equivalent to a given type B.
///
/// For example, the following global function is normally impossible to bring
/// into the `Signal<T>` class:
///
///     func merge<U>(signal: Signal<Signal<U>>) -> Signal<U>
///
/// However, you can work around this restriction using an instance method with
/// an “evidence” parameter:
///
///     func merge<U>(evidence: Signal<T> -> Signal<Signal<U>>) -> Signal<U>
///
/// Which would then be invoked with the identity function, like this:
///
///     signal.merge(identity)
///
/// This will verify that `signal`, which is nominally `Signal<T>`, is logically
/// equivalent to `Signal<Signal<U>>`. If that's not actually the case, a type
/// error will result.
public func identity<A>(a: A) -> A {
  return a;
}