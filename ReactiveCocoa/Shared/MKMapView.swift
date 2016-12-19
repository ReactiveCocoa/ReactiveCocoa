import ReactiveSwift
import MapKit

@available(tvOS 9.2, *)
extension Reactive where Base: MKMapView {

	/// Sets the map type.
	public var mapType: BindingTarget<MKMapType> {
		return makeBindingTarget { $0.mapType = $1 }
	}

	/// Sets if zoom is enabled for map.
	public var isZoomEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isZoomEnabled = $1 }
	}

	/// Sets if scroll is enabled for map.
	public var isScrollEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isScrollEnabled = $1 }
	}

	#if !os(tvOS)
	/// Sets if pitch is enabled for map.
	public var isPitchEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isPitchEnabled = $1 }
	}

	/// Sets if rotation is enabled for map.
	public var isRotateEnabled: BindingTarget<Bool> {
		return makeBindingTarget { $0.isRotateEnabled = $1 }
	}
	#endif
}
