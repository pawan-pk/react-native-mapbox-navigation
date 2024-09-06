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
    if appDelegate.currentMapboxNavigationView?.navViewController != nil {
      appDelegate.currentMapboxNavigationView?.beginCarPlayNavigation()
    }
//    else if let indexedRouteResponse = appDelegate.currentMapboxNavigationView?.indexedRouteResponse {
//      appDelegate.carPlayManager.previewRoutes(for: indexedRouteResponse)
//    }
  }
}

// MARK: CarPlay Manager extension
extension AppDelegate: CarPlayManagerDelegate {
  
}

// MARK: MapboxNavigationView extension
extension MapboxNavigationView {
  
  private func commonInit() {
      if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
          appDelegate.currentMapboxNavigationView = self
      }
  }
  
  public func beginCarPlayNavigation() {
      let delegate = UIApplication.shared.delegate as? AppDelegate
      
      if let service = navViewController?.navigationService,
         let location = service.router.location {
          delegate?.carPlayManager.beginNavigationWithCarPlay(using: location.coordinate, navigationService: service)
      }
  }
}
