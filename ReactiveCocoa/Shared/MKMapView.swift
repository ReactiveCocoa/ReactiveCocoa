import ReactiveSwift
import MapKit

@available(tvOS 9.2, *)
extension Reactive where Base: MKMapView {

	/// Sets the map type.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.mapType)` instead.")
	public var mapType: BindingTarget<MKMapType> {
		return makeBindingTarget { $0.mapType = $1 }
	}

	/// Sets if zoom is enabled for map.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.isZoomEnabled)` instead.")
	public var isZoomEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isZoomEnabled = $1 }
	}

	/// Sets if scroll is enabled for map.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.isScrollEnabled)` instead.")
	public var isScrollEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isScrollEnabled = $1 }
	}

	#if !os(tvOS)
	/// Sets if pitch is enabled for map.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.isPitchEnabled)` instead.")
	public var isPitchEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isPitchEnabled = $1 }
	}

	/// Sets if rotation is enabled for map.
	@available(swift, deprecated: 3.2, message:"Use `reactive(\\.isRotateEnabled)` instead.")
	public var isRotateEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isRotateEnabled = $1 }
	}
	#endif
}
