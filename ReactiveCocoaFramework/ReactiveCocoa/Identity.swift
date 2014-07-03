//
//  Identity.swift
//  RxSwift
//
//  Created by Maxwell Swadling on 19/06/2014.
//  Copyright (c) 2014 Maxwell Swadling. All rights reserved.
//

import Foundation

/// The identity function, which returns its argument.
///
/// This can be used to prove to the typechecker that a given type A is
/// equivalent to a given type B.
/// 
/// For example, the following global function is normally impossible to bring
/// into the `Stream<T>` class:
/// 
///     func flatten<U>(stream: Stream<Stream<U>>) -> Stream<U>
/// 
/// However, you can work around this restriction using an instance method with
/// an “evidence” parameter:
/// 
///     func flatten<U>(evidence: Stream<T> -> Stream<Stream<U>>) -> Stream<U>
/// 
/// Which would then be invoked with the identity function, like this:
/// 
///     stream.flatten(identity)
/// 
/// This will verify that `stream`, which is nominally `Stream<T>`, is logically
/// equivalent to `Stream<Stream<U>>`. If that's not actually the case, a type
/// error will result.
func identity<A>(id: A) -> A {
	return id
}
