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
}

// MARK: CarPlay Manager extension
extension AppDelegate: CarPlayManagerDelegate {
  func carPlayManager(_ carPlayManager: CarPlayManager,
                      mapButtonsCompatibleWith traitCollection: UITraitCollection,
                      in template: CPTemplate,
                      for activity: CarPlayActivity) -> [CPMapButton]? {
    switch activity {
    case .browsing:
      guard let carPlayMapViewController = carPlayManager.carPlayMapViewController,
            let mapTemplate = template as? CPMapTemplate else {
        return nil
      }
      
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
