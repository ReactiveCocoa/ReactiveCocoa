import ReactiveSwift
import ReactiveCocoa
import Quick
import Nimble
import enum Result.NoError
import MapKit

@available(tvOS 9.2, *)
class MKMapViewSpec: QuickSpec {
    override func spec() {
		var mapView: MKMapView!
		weak var _mapView: MKMapView?

		beforeEach {
			mapView = MKMapView(frame: .zero)
			_mapView = mapView
		}

		afterEach {
			mapView = nil
			// using toEventually(beNil()) here
			// since it takes time to release MKMapView
			expect(_mapView).toEventually(beNil())
		}

		it("should accept changes from bindings to its map type") {
			expect(mapView.mapType) == MKMapType.standard

			let (pipeSignal, observer) = Signal<MKMapType, NoError>.pipe()

			mapView.reactive.mapType <~ pipeSignal

			observer.send(value: MKMapType.satellite)
			expect(mapView.mapType) == MKMapType.satellite

			observer.send(value: MKMapType.hybrid)
			expect(mapView.mapType) == MKMapType.hybrid
		}
    }
}
