//
//  TupleExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-12-20.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// Adds a value into an N-tuple, returning an (N+1)-tuple.
///
/// Supports creating tuples up to 10 elements long.
internal func repack<A, B, C>(t: (A, B), value: C) -> (A, B, C) {
	return (t.0, t.1, value)
}

internal func repack<A, B, C, D>(t: (A, B, C), value: D) -> (A, B, C, D) {
	return (t.0, t.1, t.2, value)
}

internal func repack<A, B, C, D, E>(t: (A, B, C, D), value: E) -> (A, B, C, D, E) {
	return (t.0, t.1, t.2, t.3, value)
}

internal func repack<A, B, C, D, E, F>(t: (A, B, C, D, E), value: F) -> (A, B, C, D, E, F) {
	return (t.0, t.1, t.2, t.3, t.4, value)
}

internal func repack<A, B, C, D, E, F, G>(t: (A, B, C, D, E, F), value: G) -> (A, B, C, D, E, F, G) {
	return (t.0, t.1, t.2, t.3, t.4, t.5, value)
}

internal func repack<A, B, C, D, E, F, G, H>(t: (A, B, C, D, E, F, G), value: H) -> (A, B, C, D, E, F, G, H) {
	return (t.0, t.1, t.2, t.3, t.4, t.5, t.6, value)
}

internal func repack<A, B, C, D, E, F, G, H, I>(t: (A, B, C, D, E, F, G, H), value: I) -> (A, B, C, D, E, F, G, H, I) {
	return (t.0, t.1, t.2, t.3, t.4, t.5, t.6, t.7, value)
}

internal func repack<A, B, C, D, E, F, G, H, I, J>(t: (A, B, C, D, E, F, G, H, I), value: J) -> (A, B, C, D, E, F, G, H, I, J) {
	return (t.0, t.1, t.2, t.3, t.4, t.5, t.6, t.7, t.8, value)
}



// will allow you to build an Array or Tuple value, one value at time.
protocol IndexedCollectorType {
	// the type of the final tuple or Array
	typealias Value
	
	// number of elements in the tuple or array.
	var count : Int { get }

	// will update the tuple at index for a given input of type T
	// if T is the 'wrong' type than this method may throw an execption
	// return true if this is the first value for that index
	mutating func setValueAtIndex<T>(index:Int, value:T) -> Bool
	
	// convert the current values the desired final Tuple or Array
	// do not call until all values have at least one value, or you will get an nil exception
	func toValue() -> Value
}


class ArrayCollector<Element> : IndexedCollectorType {

	typealias Value = [Element]

	var values: [Element?]
	
	var count : Int

	required init(count:Int) {
		self.count = count
		self.values = [Element?](count: count,repeatedValue: nil)
	}
	
	final func setValueAtIndex<T>(index:Int, value:T) -> Bool {
		let isFirstValue = (self.values[index] == nil)
		self.values[index] = (value as! Element)
		return isFirstValue
	}

	final func toValue() -> Value {
		return self.values.map { $0! }
	}
	
}

class TupleCollector10<A,B,C,D,E,F,G,H,I,J> : IndexedCollectorType {
	
	typealias Value = (A,B,C,D,E,F,G,H,I,J)
	
	var values: (A?,B?,C?,D?,E?,F?,G?,H?,I?,J?)
	
	let count = 10
	
	required init() {
		self.values = (nil,nil,nil,nil,nil,nil,nil,nil,nil,nil)
	}
	
	final func setValueAtIndex<T>(index:Int, value:T) -> Bool {
		switch index {
		case 0:
			let isFirstValue = (self.values.0  == nil)
			self.values.0 = (value as! A)
			return isFirstValue
		case 1:
			let isFirstValue = (self.values.1  == nil)
			self.values.1 = (value as! B)
			return isFirstValue
		case 2:
			let isFirstValue = (self.values.2  == nil)
			self.values.2 = (value as! C)
			return isFirstValue
		case 3:
			let isFirstValue = (self.values.3  == nil)
			self.values.3 = (value as! D)
			return isFirstValue
		case 4:
			let isFirstValue = (self.values.4  == nil)
			self.values.4 = (value as! E)
			return isFirstValue
		case 5:
			let isFirstValue = (self.values.5  == nil)
			self.values.5 = (value as! F)
			return isFirstValue
		case 6:
			let isFirstValue = (self.values.6  == nil)
			self.values.6 = (value as! G)
			return isFirstValue
		case 7:
			let isFirstValue = (self.values.7  == nil)
			self.values.7 = (value as! H)
			return isFirstValue
		case 8:
			let isFirstValue = (self.values.8  == nil)
			self.values.8 = (value as! I)
			return isFirstValue
		case 9:
			let isFirstValue = (self.values.9  == nil)
			self.values.9 = (value as! J)
			return isFirstValue
		default:
			fatalError("index value must be 0..<\(self.count)")
		}
	}
	final func toValue() -> Value {
		return (values.0!,
			values.1!,
			values.2!,
			values.3!,
			values.4!,
			values.5!,
			values.6!,
			values.7!,
			values.8!,
			values.9!)
	}
}

class TupleCollector9<A,B,C,D,E,F,G,H,I> : IndexedCollectorType {
	
	typealias Value = (A,B,C,D,E,F,G,H,I)
	
	var values: (A?,B?,C?,D?,E?,F?,G?,H?,I?)
	
	let count = 9
	
	required init() {
		self.values = (nil,nil,nil,nil,nil,nil,nil,nil,nil)
	}
	
	final func setValueAtIndex<T>(index:Int, value:T) -> Bool {
		switch index {
		case 0:
			let isFirstValue = (self.values.0  == nil)
			self.values.0 = (value as! A)
			return isFirstValue
		case 1:
			let isFirstValue = (self.values.1  == nil)
			self.values.1 = (value as! B)
			return isFirstValue
		case 2:
			let isFirstValue = (self.values.2  == nil)
			self.values.2 = (value as! C)
			return isFirstValue
		case 3:
			let isFirstValue = (self.values.3  == nil)
			self.values.3 = (value as! D)
			return isFirstValue
		case 4:
			let isFirstValue = (self.values.4  == nil)
			self.values.4 = (value as! E)
			return isFirstValue
		case 5:
			let isFirstValue = (self.values.5  == nil)
			self.values.5 = (value as! F)
			return isFirstValue
		case 6:
			let isFirstValue = (self.values.6  == nil)
			self.values.6 = (value as! G)
			return isFirstValue
		case 7:
			let isFirstValue = (self.values.7  == nil)
			self.values.7 = (value as! H)
			return isFirstValue
		case 8:
			let isFirstValue = (self.values.8  == nil)
			self.values.8 = (value as! I)
			return isFirstValue
		default:
			fatalError("index value must be 0..<\(self.count)")
		}
	}
	final func toValue() -> Value {
		return (values.0!,
			values.1!,
			values.2!,
			values.3!,
			values.4!,
			values.5!,
			values.6!,
			values.7!,
			values.8!)
	}
}


class TupleCollector8<A,B,C,D,E,F,G,H> : IndexedCollectorType {
	
	typealias Value = (A,B,C,D,E,F,G,H)
	
	var values: (A?,B?,C?,D?,E?,F?,G?,H?)
	
	let count = 8
	
	required init() {
		self.values = (nil,nil,nil,nil,nil,nil,nil,nil)
	}
	
	final func setValueAtIndex<T>(index:Int, value:T) -> Bool {
		switch index {
		case 0:
			let isFirstValue = (self.values.0  == nil)
			self.values.0 = (value as! A)
			return isFirstValue
		case 1:
			let isFirstValue = (self.values.1  == nil)
			self.values.1 = (value as! B)
			return isFirstValue
		case 2:
			let isFirstValue = (self.values.2  == nil)
			self.values.2 = (value as! C)
			return isFirstValue
		case 3:
			let isFirstValue = (self.values.3  == nil)
			self.values.3 = (value as! D)
			return isFirstValue
		case 4:
			let isFirstValue = (self.values.4  == nil)
			self.values.4 = (value as! E)
			return isFirstValue
		case 5:
			let isFirstValue = (self.values.5  == nil)
			self.values.5 = (value as! F)
			return isFirstValue
		case 6:
			let isFirstValue = (self.values.6  == nil)
			self.values.6 = (value as! G)
			return isFirstValue
		case 7:
			let isFirstValue = (self.values.7  == nil)
			self.values.7 = (value as! H)
			return isFirstValue
		default:
			fatalError("index value must be 0..<\(self.count)")
		}
	}
	final func toValue() -> Value {
		return (values.0!,
			values.1!,
			values.2!,
			values.3!,
			values.4!,
			values.5!,
			values.6!,
			values.7!)
	}
}

class TupleCollector7<A,B,C,D,E,F,G> : IndexedCollectorType {
	
	typealias Value = (A,B,C,D,E,F,G)
	
	var values: (A?,B?,C?,D?,E?,F?,G?)
	
	let count = 7
	
	required init() {
		self.values = (nil,nil,nil,nil,nil,nil,nil)
	}
	
	final func setValueAtIndex<T>(index:Int, value:T) -> Bool {
		switch index {
		case 0:
			let isFirstValue = (self.values.0  == nil)
			self.values.0 = (value as! A)
			return isFirstValue
		case 1:
			let isFirstValue = (self.values.1  == nil)
			self.values.1 = (value as! B)
			return isFirstValue
		case 2:
			let isFirstValue = (self.values.2  == nil)
			self.values.2 = (value as! C)
			return isFirstValue
		case 3:
			let isFirstValue = (self.values.3  == nil)
			self.values.3 = (value as! D)
			return isFirstValue
		case 4:
			let isFirstValue = (self.values.4  == nil)
			self.values.4 = (value as! E)
			return isFirstValue
		case 5:
			let isFirstValue = (self.values.5  == nil)
			self.values.5 = (value as! F)
			return isFirstValue
		case 6:
			let isFirstValue = (self.values.6  == nil)
			self.values.6 = (value as! G)
			return isFirstValue
		default:
			fatalError("index value must be 0..<\(self.count)")
		}
	}
	final func toValue() -> Value {
		return (values.0!,
			values.1!,
			values.2!,
			values.3!,
			values.4!,
			values.5!,
			values.6!)
	}
}

class TupleCollector6<A,B,C,D,E,F> : IndexedCollectorType {
	
	typealias Value = (A,B,C,D,E,F)
	
	var values: (A?,B?,C?,D?,E?,F?)
	
	let count = 6
	
	required init() {
		self.values = (nil,nil,nil,nil,nil,nil)
	}
	
	final func setValueAtIndex<T>(index:Int, value:T) -> Bool {
		switch index {
		case 0:
			let isFirstValue = (self.values.0  == nil)
			self.values.0 = (value as! A)
			return isFirstValue
		case 1:
			let isFirstValue = (self.values.1  == nil)
			self.values.1 = (value as! B)
			return isFirstValue
		case 2:
			let isFirstValue = (self.values.2  == nil)
			self.values.2 = (value as! C)
			return isFirstValue
		case 3:
			let isFirstValue = (self.values.3  == nil)
			self.values.3 = (value as! D)
			return isFirstValue
		case 4:
			let isFirstValue = (self.values.4  == nil)
			self.values.4 = (value as! E)
			return isFirstValue
		case 5:
			let isFirstValue = (self.values.5  == nil)
			self.values.5 = (value as! F)
			return isFirstValue
		default:
			fatalError("index value must be 0..<\(self.count)")
		}
	}
	final func toValue() -> Value {
		return (values.0!,
			values.1!,
			values.2!,
			values.3!,
			values.4!,
			values.5!)
	}
}

class TupleCollector5<A,B,C,D,E> : IndexedCollectorType {
	
	typealias Value = (A,B,C,D,E)
	
	var values: (A?,B?,C?,D?,E?)
	
	let count = 5
	
	required init() {
		self.values = (nil,nil,nil,nil,nil)
	}
	
	final func setValueAtIndex<T>(index:Int, value:T) -> Bool {
		switch index {
		case 0:
			let isFirstValue = (self.values.0  == nil)
			self.values.0 = (value as! A)
			return isFirstValue
		case 1:
			let isFirstValue = (self.values.1  == nil)
			self.values.1 = (value as! B)
			return isFirstValue
		case 2:
			let isFirstValue = (self.values.2  == nil)
			self.values.2 = (value as! C)
			return isFirstValue
		case 3:
			let isFirstValue = (self.values.3  == nil)
			self.values.3 = (value as! D)
			return isFirstValue
		case 4:
			let isFirstValue = (self.values.4  == nil)
			self.values.4 = (value as! E)
			return isFirstValue
		default:
			fatalError("index value must be 0..<\(self.count)")
		}
	}
	final func toValue() -> Value {
		return (values.0!,
			values.1!,
			values.2!,
			values.3!,
			values.4!)
	}
}

class TupleCollector4<A,B,C,D> : IndexedCollectorType {
	
	typealias Value = (A,B,C,D)
	
	var values: (A?,B?,C?,D?)
	
	let count = 4
	
	required init() {
		self.values = (nil,nil,nil,nil)
	}
	
	final func setValueAtIndex<T>(index:Int, value:T) -> Bool {
		switch index {
		case 0:
			let isFirstValue = (self.values.0  == nil)
			self.values.0 = (value as! A)
			return isFirstValue
		case 1:
			let isFirstValue = (self.values.1  == nil)
			self.values.1 = (value as! B)
			return isFirstValue
		case 2:
			let isFirstValue = (self.values.2  == nil)
			self.values.2 = (value as! C)
			return isFirstValue
		case 3:
			let isFirstValue = (self.values.3  == nil)
			self.values.3 = (value as! D)
			return isFirstValue
		default:
			fatalError("index value must be 0..<\(self.count)")
		}
	}
	final func toValue() -> Value {
		return (values.0!,
			values.1!,
			values.2!,
			values.3!)
	}
}

class TupleCollector3<A,B,C> : IndexedCollectorType {
	
	typealias Value = (A,B,C)
	
	var values: (A?,B?,C?)
	
	let count = 3
	
	required init() {
		self.values = (nil,nil,nil)
	}
	
	final func setValueAtIndex<T>(index:Int, value:T) -> Bool {
		switch index {
		case 0:
			let isFirstValue = (self.values.0  == nil)
			self.values.0 = (value as! A)
			return isFirstValue
		case 1:
			let isFirstValue = (self.values.1  == nil)
			self.values.1 = (value as! B)
			return isFirstValue
		case 2:
			let isFirstValue = (self.values.2  == nil)
			self.values.2 = (value as! C)
			return isFirstValue
		default:
			fatalError("index value must be 0..<\(self.count)")
		}
	}
	final func toValue() -> Value {
		return (values.0!,
			values.1!,
			values.2!)
	}
}

class TupleCollector2<A,B> : IndexedCollectorType {
	
	typealias Value = (A,B)
	
	var values: (A?,B?)
	
	let count = 2
	
	required init() {
		self.values = (nil,nil)
	}
	
	final func setValueAtIndex<T>(index:Int, value:T) -> Bool {
		switch index {
		case 0:
			let isFirstValue = (self.values.0  == nil)
			self.values.0 = (value as! A)
			return isFirstValue
		case 1:
			let isFirstValue = (self.values.1  == nil)
			self.values.1 = (value as! B)
			return isFirstValue
		default:
			fatalError("tuples bigger than \(self.count) items not supported")
		}
	}
	
	final func toValue() -> Value {
		return (values.0!,
			values.1!)
	}
}






