import CarPlay
import MapboxNavigation
import MapboxCoreNavigation
import react_native_mapbox_navigation

class CarSceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  static let coarseLocationManager: CLLocationManager = {
    let coarseLocationManager = CLLocationManager()
    coarseLocationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    return coarseLocationManager
  }()
  
  func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController, to window: CPWindow) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
    appDelegate.carPlayManager.delegate = appDelegate
    appDelegate.carPlayManager.templateApplicationScene(templateApplicationScene,
                                                        didConnectCarInterfaceController: interfaceController,
                                                        to: window)
    if let indexedRouteResponse = appDelegate.currentMapboxNavigationView?.indexedRouteResponse {
      appDelegate.carPlayManager.previewRoutes(for: indexedRouteResponse)
    }
  }
  
  func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnect interfaceController: CPInterfaceController, from window: CPWindow) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
    appDelegate.carPlayManager.delegate = nil
    appDelegate.carPlayManager.templateApplicationScene(templateApplicationScene,
                                                        didDisconnectCarInterfaceController: interfaceController,
                                                        from: window)
    if let navigationViewController = appDelegate.currentMapboxNavigationView?.navViewController {
      navigationViewController.didDisconnectFromCarPlay()
    }
  }
}

// MARK: CarPlay Manager extension
extension AppDelegate: CarPlayManagerDelegate {
  func carPlayManager(_ carPlayManager: CarPlayManager, didPresent navigationViewController: CarPlayNavigationViewController) {
    if let navigationViewportDataSource = carPlayManager.carPlayNavigationViewController?.navigationMapView?.navigationCamera.viewportDataSource as? NavigationViewportDataSource {
        navigationViewportDataSource.options.followingCameraOptions.zoomUpdatesAllowed = false
      // Map Zoom Level for Navigating
      navigationViewportDataSource.followingCarPlayCamera.zoom = 15.0
    }
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
