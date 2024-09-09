import react_native_mapbox_navigation

extension AppDelegate: MapboxCarPlayNavigationDelegate {
  func startNavigation(with navigationView: MapboxNavigationView) {
    currentMapboxNavigationView = navigationView
    // Check if already in navigation
    if let indexedRouteResponse = navigationView.indexedRouteResponse {
      carPlayManager.previewRoutes(for: indexedRouteResponse)
    }
  }
  
  func endNavigation() {
    currentMapboxNavigationView = nil
    carPlayManager.cancelRoutesPreview()
  }
}
