// MARK: Renamed APIs in Swift 3.0
import ReactiveCocoa
import enum Result.NoError

extension SignalProtocol {
    @available(*, unavailable, renamed:"mute(for:clock:)")
    public func muteFor(_ interval: TimeInterval, clock: DateSchedulerProtocol) -> Signal<Value, Error> { fatalError() }

    @available(*, unavailable, renamed:"timeout(after:with:on:)")
    public func timeoutAfter(_ interval: TimeInterval, withEvent event: Event<Value, Error>, onScheduler scheduler: DateSchedulerProtocol) -> Signal<Value, Error> { fatalError() }
}

extension SignalProducerProtocol {
    @available(*, unavailable, renamed:"mute(for:clock:)")
    public func muteFor(_ interval: TimeInterval, clock: DateSchedulerProtocol) -> SignalProducer<Value, Error> { fatalError() }

    @available(*, unavailable, renamed:"timeout(after:with:on:)")
    public func timeoutAfter(_ interval: TimeInterval, withEvent event: Event<Value, Error>, onScheduler scheduler: DateSchedulerProtocol) -> SignalProducer<Value, Error> { fatalError() }

    @available(*, unavailable, renamed:"group(by:)")
    public func groupBy<Key: Hashable>(_ grouping: (Value) -> Key) -> SignalProducer<(Key, SignalProducer<Value, Error>), Error> { fatalError() }

    @available(*, unavailable, renamed:"defer(by:on:)")
    public func deferred(_ interval: TimeInterval, onScheduler scheduler: DateSchedulerProtocol) -> SignalProducer<Value, Error> { fatalError() }
}

extension UserDefaults {
    @available(*, unavailable, renamed:"rex_value(forKey:)")
    public func rex_valueForKey(_ key: String) -> SignalProducer<AnyObject?, NoError> { fatalError() }
}

extension NSObject {
    @available(*, unavailable, renamed:"rex_producer(forKeyPath:)")
    public func rex_producerForKeyPath<T>(_ keyPath: String) -> SignalProducer<T, NoError> { fatalError() }
}

extension Data {
    @available(*, unavailable, renamed:"rex_data(contentsOf:options:)")
    public static func rex_dataWithContentsOfURL(_ url: URL, options: Data.ReadingOptions = []) -> SignalProducer<Data, NSError> { fatalError() }
}

extension Data {
    @available(*, unavailable, renamed:"rex_data(contentsOf:options:)")
    public static func rex_dataWithContentsOfURL(_ url: URL, options: NSData.ReadingOptions = []) -> SignalProducer<NSData, NSError> { fatalError() }
}
