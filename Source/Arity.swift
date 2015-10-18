//
//  Tuple.swift
//  Rex
//
//  Created by Neil Pankey on 10/17/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

public protocol ArityType {
    static var size: Int { get }

    // TODO Can this be guaranteed somehow?
    typealias TupleType
    var tuple: TupleType { get }
}

public protocol NullaryType: ArityType { }

extension NullaryType {
    public static var size: Int { return 0 }
}

public struct Nullary: NullaryType {
    public let tuple: () = ()
}


public protocol UnaryType: ArityType { }

extension UnaryType {
    public static var size: Int { return 1 }
}

public struct Unary<A>: UnaryType {
    public let tuple: A
}


public protocol BinaryType: ArityType { }

extension BinaryType {
    public static var size: Int { return 2 }
}

public struct Binary<A, B>: BinaryType {
    public let tuple: (A, B)
}


public protocol TernaryType: ArityType { }

extension TernaryType {
    public static var size: Int { return 3 }
}

public struct Ternary<A, B, C>: TernaryType {
    public let tuple: (A, B, C)
}
