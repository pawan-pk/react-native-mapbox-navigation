import CarPlay
import MapboxMaps
import MapboxNavigation
import MapboxDirections
import MapboxCoreNavigation
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
    carPlayManager.carPlayNavigationViewController?.exitNavigation(byCanceling: true)
  }
}

// MARK: CarPlay Manager extension
extension AppDelegate: CarPlayManagerDelegate {
  func carPlayManager(_ carPlayManager: CarPlayManager, didPresent navigationViewController: CarPlayNavigationViewController) {
    if let navigationMapView = carPlayManager.carPlayNavigationViewController?.navigationMapView,
       let navigationViewportDataSource = navigationMapView.navigationCamera.viewportDataSource as? NavigationViewportDataSource {
      navigationViewportDataSource.options.followingCameraOptions.zoomUpdatesAllowed = false
      // Map Zoom Level for Navigating
      navigationViewportDataSource.followingCarPlayCamera.zoom = 15.0
      let puck = UserPuckCourseView(frame: CGRect(origin: .zero, size: 40.0))
      navigationMapView.userLocationStyle = .courseView(puck)
    }
  }
  func carPlayManager(_ carPlayManager: CarPlayManager, didBeginNavigationWith service: any NavigationService) {
  }

  func carPlayManager(_ carPlayManager: CarPlayManager,
                      mapButtonsCompatibleWith traitCollection: UITraitCollection,
                      in template: CPTemplate,
                      for activity: CarPlayActivity) -> [CPMapButton]? {
    
    guard let carPlayMapViewController = carPlayManager.carPlayMapViewController,
          let mapTemplate = template as? CPMapTemplate else {
      return nil
    }
    switch activity {
    case .browsing:
      let mapButtons = [
        carPlayMapViewController.recenterButton,
        carPlayMapViewController.panningInterfaceDisplayButton(for: mapTemplate),
        carPlayMapViewController.zoomInButton,
        carPlayMapViewController.zoomOutButton,
      ]
      
      return mapButtons
    case .previewing, .navigating, .panningInBrowsingMode, .panningInNavigationMode:
      return nil
    }
  }
  
  func carPlayManager(_ carPlayManager: CarPlayManager, leadingNavigationBarButtonsCompatibleWith traitCollection: UITraitCollection, in template: CPTemplate, for activity: CarPlayActivity) -> [CPBarButton]? {
    switch activity {
    case .navigating:
      return [carPlayManager.alternativeRoutesButton]
    case .browsing, .panningInBrowsingMode, .panningInNavigationMode, .previewing:
      return []
    }
  }
  
  func carPlayManager(_ carPlayManager: CarPlayManager, trailingNavigationBarButtonsCompatibleWith traitCollection: UITraitCollection, in carPlayTemplate: CPTemplate, for activity: CarPlayActivity) -> [CPBarButton]? {
    return []
  }
}
