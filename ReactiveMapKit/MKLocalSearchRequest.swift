import ReactiveSwift
import ReactiveCocoa
import Result
import MapKit

#if os(iOS) || os(tvOS) || os(macOS)
	private let defaultLocalSearchError = NSError(domain: "org.reactivecocoa.ReactiveCocoa.Reactivity.MKLocalSearchRequest",
												  code: 1,
												  userInfo: nil)
	@available(tvOS 9.2, *)
	extension Reactive where Base: MKLocalSearchRequest {
		/// A SignalProducer which performs an `MKLocalSearch`.
		public var search: SignalProducer<MKLocalSearchResponse, AnyError> {
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
#endif
