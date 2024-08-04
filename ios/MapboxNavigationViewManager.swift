//
//  MapboxNavigationViewManager.swift
//  react-native-mapbox-navigation
//
//  Created by Pawan Kushwaha on 10/07/2024.
//

@objc(MapboxNavigationViewManager)
class MapboxNavigationViewManager: RCTViewManager {
    override func view() -> UIView! {
        return MapboxNavigationView();
    }
    
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc(setWaypoints:coordinates:)
    public func setWaypoints(view: Any, coordinates: [MapboxCoordinate]) {
        guard let currentView = view as? MapboxNavigationView else {
            return
        }
        let waypoints = coordinates.compactMap { $0.coordinate }
        currentView.setWaypoints(coordinates: waypoints)
    }
}
