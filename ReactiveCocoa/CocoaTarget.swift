import Foundation
import ReactiveSwift
import enum Result.NoError

/// A target that accepts action messages.
internal final class CocoaTarget<Value>: NSObject {
	let observer: Observer<Value, NoError>
	let transform: (Any?) -> Value
	
	init(_ observer: Observer<Value, NoError>, transform: @escaping (Any?) -> Value) {
		self.observer = observer
		self.transform = transform
	}

	
	@objc func sendNext(_ receiver: Any?) {
		observer.send(value: transform(receiver))
	}
}

protocol CocoaTargetProtocol: class {
	associatedtype Value
	init(_ observer: Observer<Value, NoError>, transform: @escaping (Any?) -> Value)
}

extension CocoaTarget:CocoaTargetProtocol{}

extension CocoaTargetProtocol where Value == Void {
	init(_ observer: Observer<(), NoError>) {
		self.init(observer, transform: { _ in })
	}
}
