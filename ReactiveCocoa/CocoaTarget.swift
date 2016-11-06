import Foundation
import ReactiveSwift
import enum Result.NoError

/// A target that accepts action messages.
internal final class CocoaTarget<Value>: NSObject {
	private let observer: Observer<Value, NoError>
	private let transform: (Any?) -> Value
	
	internal init(_ observer: Observer<Value, NoError>, transform: @escaping (Any?) -> Value) {
		self.observer = observer
		self.transform = transform
	}
	
	@objc internal func sendNext(_ receiver: Any?) {
		observer.send(value: transform(receiver))
	}
}

internal protocol CocoaTargetProtocol: class {
	associatedtype Value
	init(_ observer: Observer<Value, NoError>, transform: @escaping (Any?) -> Value)
}

extension CocoaTarget: CocoaTargetProtocol {}

extension CocoaTargetProtocol where Value == Void {
	internal init(_ observer: Observer<(), NoError>) {
		self.init(observer, transform: { _ in })
	}
}
