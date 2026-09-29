// LocationManager.swift

import Foundation
import CoreLocation
import FirebaseFirestore

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    private var userID: String?

    init(userID: String?) {
        super.init()
        self.userID = userID
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 25
        locationManager.requestAlwaysAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, let userID = userID else { return }
        let geoPoint = GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        db.collection("users").document(userID).updateData([
            "location": geoPoint,
            "locationUpdatedAt": Timestamp()
        ])
    }

    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }
}
final class OneShotLocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentLocation(timeout: TimeInterval = 8.0) async -> CLLocation? {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            return nil
        @unknown default:
            return nil
        }

        return await withCheckedContinuation { (continuation: CheckedContinuation<CLLocation?, Never>) in
            self.continuation = continuation
            self.manager.requestLocation()

            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self else { return }
                if let cont = self.continuation {
                    self.continuation = nil
                    cont.resume(returning: nil)
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }
}

