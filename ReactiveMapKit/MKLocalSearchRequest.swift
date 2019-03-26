import ReactiveSwift
import ReactiveCocoa
import Result
import MapKit

private let defaultLocalSearchError = NSError(domain: "org.reactivecocoa.ReactiveCocoa.Reactivity.MKLocalSearchRequest",
											  code: 1,
											  userInfo: nil)
@available(tvOS 9.2, *)
extension Reactive where Base: MKLocalSearch.Request {
	/// A SignalProducer which performs an `MKLocalSearch`.
	public var search: SignalProducer<MKLocalSearch.Response, AnyError> {
		return SignalProducer {[base = self.base] observer, lifetime in
			let search = MKLocalSearch(request: base)
			search.start { response, error in
				if let response = response {
					observer.send(value: response)
					observer.sendCompleted()
				} else {
					observer.send(error: AnyError(error ?? defaultLocalSearchError))
				}
			}
			lifetime.observeEnded(search.cancel)
		}
	}
}
