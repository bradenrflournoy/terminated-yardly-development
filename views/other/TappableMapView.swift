// TappableMapView.swift

import SwiftUI
import MapKit
import CoreLocation

struct TappableMapView: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D?
    let onCoordinateSelected: (CLLocationCoordinate2D) -> Void
    let allowedDistanceMeters: Double = 100

    let locationManager = CLLocationManager()

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        locationManager.requestWhenInUseAuthorization()
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow

        let gesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(gesture)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeAnnotations(uiView.annotations)

        if let coordinate = coordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            uiView.addAnnotation(annotation)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TappableMapView

        init(_ parent: TappableMapView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let tappedCoordinate = mapView.convert(point, toCoordinateFrom: mapView)

            if let userLocation = mapView.userLocation.location {
                let tappedLocation = CLLocation(latitude: tappedCoordinate.latitude, longitude: tappedCoordinate.longitude)
                let distance = userLocation.distance(from: tappedLocation)
                if distance <= parent.allowedDistanceMeters {
                    parent.coordinate = tappedCoordinate
                    parent.onCoordinateSelected(tappedCoordinate)
                }
            }
        }
    }
}
