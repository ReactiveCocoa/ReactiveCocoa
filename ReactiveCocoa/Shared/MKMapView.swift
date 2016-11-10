import ReactiveSwift
import MapKit

@available(tvOS 9.2, *)
extension Reactive where Base: MKMapView {

	/// Sets the map type.
	public var mapType: BindingTarget<MKMapType> {
		return makeBindingTarget { $0.mapType = $1 }
	}

}
