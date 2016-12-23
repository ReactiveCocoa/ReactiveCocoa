import ReactiveSwift

extension Reactive: ReactiveProtocol {}

public protocol ReactiveProtocol {
	associatedtype Base
	var base: Base { get }
}
