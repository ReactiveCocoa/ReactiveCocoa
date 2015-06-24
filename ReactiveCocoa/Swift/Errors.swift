//
//  Errors.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Workaround for constraining generic type extensions with non-protocol types.
/// Unfortunately there's no way to guarantee that instances of types conforming
/// to this protocol can't be created.
///
/// See http://www.openradar.me/21512469
public protocol NoErrorType: ErrorType {}

/// An “error” that is impossible to construct.
///
/// This can be used to describe signals or producers where errors will never
/// be generated. For example, `Signal<Int, NoError>` describes a signal that
/// sends integers and is guaranteed never to error out.
public enum NoError: NoErrorType {}
