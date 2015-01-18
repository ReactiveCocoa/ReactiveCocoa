//
//  Errors.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// An “error” that is impossible to construct.
///
/// This can be used to describe signals or producers where errors will never
/// be generated.
public enum NoError {}
