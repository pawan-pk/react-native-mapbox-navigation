import CarPlay
import MapboxMaps

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
