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

public struct Nullary: ArityType {
    public static var size: Int {
        return 0
    }

    public let tuple: () = ()
}

public struct Unary<A>: ArityType {
    public static var size: Int {
        return 1
    }

    public let tuple: A
}

public struct Binary<A, B>: ArityType {
    public static var size: Int {
        return 2
    }

    public let tuple: (A, B)
}

public struct Ternary<A, B, C>: ArityType {
    public static var size: Int {
        return 3
    }
    
    public let tuple: (A, B, C)
}
