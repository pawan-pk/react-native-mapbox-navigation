//import UIKit
//import MapboxNavigation
//import CarPlay
//import MapboxGeocoder
//import MapboxCoreNavigation
//import MapboxDirections
//import MapboxMaps
//
//let CarPlayWaypointKey: String = "MBCarPlayWaypoint"
//
//extension NavigationGeocodedPlacemark {
//   /**
//    Initializes a newly created `NavigationGeocodedPlacemark` object with a `GeocodedPlacemark`
//    instance and an optional subtitle.
//    
//    - parameter geocodedPlacemark: A `GeocodedPlacemark` instance, properties of which will be used in
//    `NavigationGeocodedPlacemark`.
//    - parameter subtitle: Subtitle, which can contain additional information regarding placemark
//    (e.g. address).
//    */
//   init(geocodedPlacemark: GeocodedPlacemark, subtitle: String?) {
//       self.init(title: geocodedPlacemark.formattedName, subtitle: subtitle, location: geocodedPlacemark.location, routableLocations: geocodedPlacemark.routableLocations)
//   }
//}
//
//// MARK: - CPApplicationDelegate methods
//
///**
//This example application delegate implementation is used for "Example-CarPlay" target.
//
//In order to run the "Example-CarPlay" example app with CarPlay functionality enabled, one must first obtain a CarPlay entitlement from Apple.
//
//Once the entitlement has been obtained and loaded into your ADC account:
//- Create a provisioning profile which includes the entitlement
//- Download and select the provisioning profile for the "Example-CarPlay" example app
//- Be sure to select an iOS simulator or device running iOS 12 or greater
//*/
//extension AppDelegate: CPApplicationDelegate {
//   
//   func application(_ application: UIApplication,
//                    didConnectCarInterfaceController interfaceController: CPInterfaceController,
//                    to window: CPWindow) {
//
//   }
//   
//   func application(_ application: UIApplication,
//                    didDisconnectCarInterfaceController interfaceController: CPInterfaceController,
//                    from window: CPWindow) {
//       carPlayManager.delegate = nil
////       carPlaySearchController.delegate = nil
//       carPlayManager.application(application, didDisconnectCarInterfaceController: interfaceController, from: window)
//       
//       if let navigationViewController = currentAppRootViewController?.activeNavigationViewController {
//           navigationViewController.didDisconnectFromCarPlay()
//       }
//   }
//}
//
//// MARK: - CarPlayManagerDelegate methods
//
//extension AppDelegate: CarPlayManagerDelegate {
//   func carPlayManager(_ carPlayManager: CarPlayManager, selectedPreviewFor trip: CPTrip, using routeChoice: CPRouteChoice) {
//       guard let indexedRouteResponse = routeChoice.indexedRouteResponse,
//             shouldPreviewRoutes(for: indexedRouteResponse) else { return }
////       currentAppRootViewController?.indexedRouteResponse = indexedRouteResponse
//   }
//   
//   private func shouldPreviewRoutes(for indexedRouteResponse: IndexedRouteResponse) -> Bool {
////       guard let rootResponse = currentAppRootViewController?.indexedRouteResponse else {
////           return true
////       }
////       return indexedRouteResponse.routeResponse.routes != rootResponse.routeResponse.routes ||
////       indexedRouteResponse.routeIndex != rootResponse.routeIndex
//     return true
//   }
//
//   func carPlayManagerWillCancelPreview(
//       _ carPlayManager: CarPlayManager,
//       configuration: inout CarPlayManagerCancelPreviewConfiguration
//   ) {
//       configuration.popToRoot = false
//   }
//
//   func carPlayManagerDidCancelPreview(_ carPlayManager: CarPlayManager) {
////       currentAppRootViewController?.indexedRouteResponse = nil
//   }
//   
//   func carPlayManager(_ carPlayManager: CarPlayManager,
//                       navigationServiceFor indexedRouteResponse: IndexedRouteResponse,
//                       desiredSimulationMode: SimulationMode) -> NavigationService? {
////       if let navigationViewController = self.window?.rootViewController?.presentedViewController as? NavigationViewController,
////          let navigationService = navigationViewController.navigationService {
////           // Do not set simulation mode if we already have an active navigation session.
////           return navigationService
////       }
//       
//       return MapboxNavigationService(indexedRouteResponse: indexedRouteResponse,
//                                      customRoutingProvider: nil,
//                                      credentials: NavigationSettings.shared.directions.credentials,
//                                      simulating: desiredSimulationMode)
//   }
//   
//   func carPlayManager(_ carPlayManager: CarPlayManager, didPresent navigationViewController: CarPlayNavigationViewController) {
////       currentAppRootViewController?.beginNavigationWithCarPlay(navigationService: navigationViewController.navigationService)
//       navigationViewController.compassView.isHidden = false
//       
//       // Render part of the route that has been traversed with full transparency, to give the illusion of a disappearing route.
//       navigationViewController.routeLineTracksTraversal = true
//       navigationViewController.navigationMapView?.showsRestrictedAreasOnRoute = true
//       
//       // Example of building highlighting in 3D.
//       navigationViewController.waypointStyle = .extrudedBuilding
//       
//       guard let navigationMapView = navigationViewController.navigationMapView else { return }
//       // Provide the custom layer position for route line in active navigation.
//       let route = navigationViewController.navigationService.route
//       if navigationMapView.mapView.mapboxMap.style.layerExists(withId: "road-intersection") {
//           navigationMapView.show([route], layerPosition: .below("road-intersection"), legIndex: 0)
//       } else {
//           navigationMapView.show([route], legIndex: 0)
//       }
//   }
//   
//   func carPlayManagerDidEndNavigation(_ carPlayManager: CarPlayManager,
//                                       byCanceling canceled: Bool) {
//       // Dismiss NavigationViewController if it's present in the navigation stack
////       currentAppRootViewController?.dismissActiveNavigationViewController()
//   }
//
//   func carPlayManager(_ carPlayManager: CarPlayManager, shouldPresentArrivalUIFor waypoint: Waypoint) -> Bool {
//       return true
//   }
//   
//   func carPlayManager(_ carPlayManager: CarPlayManager,
//                       leadingNavigationBarButtonsCompatibleWith traitCollection: UITraitCollection,
//                       in template: CPTemplate,
//                       for activity: CarPlayActivity) -> [CPBarButton]? {
////       guard let interfaceController = self.carPlayManager.interfaceController else {
////           return nil
////       }
////       
////       switch activity {
////       case .browsing:
////           let searchTemplate = CPSearchTemplate()
////           searchTemplate.delegate = carPlaySearchController
////           let searchButton = carPlaySearchController.searchTemplateButton(searchTemplate: searchTemplate,
////                                                                           interfaceController: interfaceController,
////                                                                           traitCollection: traitCollection)
////           return [searchButton]
////       case .navigating, .previewing, .panningInBrowsingMode, .panningInNavigationMode:
//           return nil
////       }
//   }
//   
//   func carPlayManager(_ carPlayManager: CarPlayManager,
//                       didFailToFetchRouteBetween waypoints: [Waypoint]?,
//                       options: RouteOptions,
//                       error: DirectionsError) -> CPNavigationAlert? {
//       let title = NSLocalizedString("CARPLAY_OK",
//                                     bundle: .main,
//                                     value: "OK",
//                                     comment: "CPAlertTemplate OK button title")
//       
//       let action = CPAlertAction(title: title,
//                                  style: .default,
//                                  handler: { _ in })
//       
//       let alert = CPNavigationAlert(titleVariants: [error.localizedDescription],
//                                     subtitleVariants: [error.failureReason ?? ""],
//                                     imageSet: nil,
//                                     primaryAction: action,
//                                     secondaryAction: nil,
//                                     duration: 5)
//       return alert
//   }
//   
//   func carPlayManager(_ carPlayManager: CarPlayManager,
//                       trailingNavigationBarButtonsCompatibleWith traitCollection: UITraitCollection,
//                       in template: CPTemplate,
//                       for activity: CarPlayActivity) -> [CPBarButton]? {
//       switch activity {
//       case .previewing:
//           let disableSimulateText = NSLocalizedString("CARPLAY_DISABLE_SIMULATION",
//                                                       bundle: .main,
//                                                       value: "Disable Simulation",
//                                                       comment: "CPBarButton title, which allows to disable location simulation")
//           
//           let enableSimulateText = NSLocalizedString("CARPLAY_ENABLE_SIMULATION",
//                                                      bundle: .main,
//                                                      value: "Enable Simulation",
//                                                      comment: "CPBarButton title, which allows to enable location simulation")
//           
//           let simulationButton = CPBarButton(type: .text) { (barButton) in
//               carPlayManager.simulatesLocations = !carPlayManager.simulatesLocations
//               barButton.title = carPlayManager.simulatesLocations ? disableSimulateText : enableSimulateText
//           }
//           simulationButton.title = carPlayManager.simulatesLocations ? disableSimulateText : enableSimulateText
//           return [simulationButton]
//       case .browsing:
//           let favoriteTemplateButton = CPBarButton(type: .image) { [weak self] button in
////               guard let self = self else { return }
////               let listTemplate = self.favoritesListTemplate()
////               listTemplate.delegate = self
////               carPlayManager.interfaceController?.pushTemplate(listTemplate, animated: true)
//           }
//           favoriteTemplateButton.image = UIImage(named: "carplay_star", in: nil, compatibleWith: traitCollection)
//           return [favoriteTemplateButton]
//       case .navigating, .panningInBrowsingMode, .panningInNavigationMode:
//           return nil
//       }
//   }
//   
//   func carPlayManager(_ carPlayManager: CarPlayManager,
//                       mapButtonsCompatibleWith traitCollection: UITraitCollection,
//                       in template: CPTemplate,
//                       for activity: CarPlayActivity) -> [CPMapButton]? {
//       switch activity {
//       case .browsing:
//           guard let carPlayMapViewController = carPlayManager.carPlayMapViewController,
//               let mapTemplate = template as? CPMapTemplate else {
//               return nil
//           }
//           
//           let mapButtons = [
//               carPlayMapViewController.recenterButton,
//               carPlayMapViewController.panningInterfaceDisplayButton(for: mapTemplate),
//               carPlayMapViewController.zoomInButton,
//               carPlayMapViewController.zoomOutButton
//           ]
//           
//           return mapButtons
//       case .previewing, .navigating, .panningInBrowsingMode, .panningInNavigationMode:
//           return nil
//       }
//   }
//   
//   func carPlayManager(_ carPlayManager: CarPlayManager,
//                       shouldShowNotificationFor maneuver: CPManeuver,
//                       in mapTemplate: CPMapTemplate) -> Bool {
//       return true
//   }
//   
//   func carPlayManager(_ carPlayManager: CarPlayManager,
//                       shouldShowNotificationFor navigationAlert: CPNavigationAlert,
//                       in mapTemplate: CPMapTemplate) -> Bool {
//       return true
//   }
//   
//   func carPlayManager(_ carPlayManager: CarPlayManager,
//                       shouldUpdateNotificationFor maneuver: CPManeuver,
//                       with travelEstimates: CPTravelEstimates,
//                       in mapTemplate: CPMapTemplate) -> Bool {
//       return true
//   }
//}
//
//extension GeocodedPlacemark {
//   
//   var subtitle: String? {
//       if let addressDictionary = addressDictionary,
//          var lines = addressDictionary["formattedAddressLines"] as? [String] {
//           // Chinese addresses have no commas and are reversed.
//           if scope == .address {
//               if qualifiedName?.contains(", ") ?? false {
//                   lines.removeFirst()
//               } else {
//                   lines.removeLast()
//               }
//           }
//           
//           let separator = NSLocalizedString("ADDRESS_LINE_SEPARATOR",
//                                             value: ", ",
//                                             comment: "Delimiter between lines in an address when displayed inline")
//           
//           if let regionCode = administrativeRegion?.code,
//              let abbreviatedRegion = regionCode.components(separatedBy: "-").last,
//              (abbreviatedRegion as NSString).intValue == 0 {
//               // Cut off country and postal code and add abbreviated state/region code at the end.
//               
//               let subtitle = lines.prefix(2).joined(separator: separator)
//               
//               let scopes: PlacemarkScope = [
//                   .region,
//                   .district,
//                   .place,
//                   .postalCode
//               ]
//               
//               if scopes.contains(scope) {
//                   return subtitle
//               }
//               
//               return subtitle.appending("\(separator)\(abbreviatedRegion)")
//           }
//           
//           if scope == .country {
//               return ""
//           }
//           
//           if qualifiedName?.contains(", ") ?? false {
//               return lines.joined(separator: separator)
//           }
//           
//           return lines.joined()
//       }
//       
//       return description
//   }
//}
//
//// MARK: - CPListTemplateDelegate methods
//
//extension AppDelegate: CPListTemplateDelegate {
//   
//   func listTemplate(_ listTemplate: CPListTemplate,
//                     didSelect item: CPListItem,
//                     completionHandler: @escaping () -> Void) {
//       // Selected a list item for the list of favorites.
//       guard let userInfo = item.userInfo as? CarPlayUserInfo,
//             let waypoint = userInfo[CarPlayWaypointKey] as? Waypoint else {
//                 completionHandler()
//                 return
//             }
//       
//       carPlayManager.previewRoutes(to: waypoint, completionHandler: completionHandler)
//   }
//}
