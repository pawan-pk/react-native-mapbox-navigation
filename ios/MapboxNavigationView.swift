import MapboxDirections
import MapboxNavigationCore
import MapboxNavigationUIKit
import CoreLocation
import UIKit

// MARK: - Mapbox Navigation SDK v3 port
//
// Ported from the v2 implementation (Directions.shared + NavigationViewController(for:))
// to the v3 API:
//   - v2 `import MapboxNavigation` / `MapboxCoreNavigation`
//       → v3 `import MapboxNavigationUIKit` (drop-in UI) / `MapboxNavigationCore` (routing, voice).
//   - v2 `Directions.shared.calculateRoutes(options:) { result in }`
//       → v3 `MapboxNavigationProvider(coreConfig:).mapboxNavigation.routingProvider()
//             .calculateRoutes(options:)` (async; await `.result`).
//   - v2 `NavigationViewController(for: response, navigationOptions:)`
//       → v3 `NavigationViewController(navigationRoutes: NavigationRoutes, navigationOptions:)`
//         where `NavigationOptions` now requires `mapboxNavigation:`, `voiceController:`, `eventsManager:`.
//   - v2 `NavigationSettings.shared.voiceMuted` (removed in v3)
//       → v3 `provider.routeVoiceController.speechSynthesizer.muted`.
//   - simulation moves from `NavigationOptions(simulationMode:)` to `CoreConfig.locationSource`.
//
// The JS prop/event contract is unchanged from v2 (paper RCTViewManager + RCTDirectEventBlock).

extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

public protocol MapboxCarPlayDelegate {
    func connect(with navigationView: MapboxNavigationView)
    func disconnect()
}

public protocol MapboxCarPlayNavigationDelegate {
    func startNavigation(with navigationView: MapboxNavigationView)
    func endNavigation()
}

public class MapboxNavigationView: UIView, NavigationViewControllerDelegate {
    public weak var navViewController: NavigationViewController?

    // v3: the computed route set (replaces v2's `IndexedRouteResponse`).
    public var navigationRoutes: NavigationRoutes?

    // Must hold a STRONG ref to the provider for the whole navigation session — it owns the routing
    // provider, voice controller and events manager. If it deallocs, routing + voice stop working.
    private var navigationProvider: MapboxNavigationProvider?

    var embedded: Bool
    var embedding: Bool

    @objc public var startOrigin: NSArray = [] {
        didSet { setNeedsLayout() }
    }

    var waypoints: [Waypoint] = [] {
        didSet { setNeedsLayout() }
    }

    func setWaypoints(waypoints: [MapboxWaypoint]) {
        self.waypoints = waypoints.enumerated().map { (index, waypointData) in
            let name = waypointData.name as? String ?? "\(index)"
            let waypoint = Waypoint(coordinate: waypointData.coordinate, name: name)
            waypoint.separatesLegs = waypointData.separatesLegs
            return waypoint
        }
    }

    @objc var destination: NSArray = [] {
        didSet { setNeedsLayout() }
    }

    @objc var shouldSimulateRoute: Bool = false
    @objc var showsEndOfRouteFeedback: Bool = false
    @objc var showCancelButton: Bool = false
    @objc var hideStatusView: Bool = false
    @objc var mute: Bool = false
    @objc var distanceUnit: NSString = "imperial"
    @objc var language: NSString = "us"
    @objc var destinationTitle: NSString = "Destination"
    @objc var travelMode: NSString = "driving-traffic"

    @objc var onLocationChange: RCTDirectEventBlock?
    @objc var onRouteProgressChange: RCTDirectEventBlock?
    @objc var onError: RCTDirectEventBlock?
    @objc var onCancelNavigation: RCTDirectEventBlock?
    @objc var onArrive: RCTDirectEventBlock?
    @objc var vehicleMaxHeight: NSNumber?
    @objc var vehicleMaxWidth: NSNumber?

    override init(frame: CGRect) {
        self.embedded = false
        self.embedding = false
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        if navViewController == nil && !embedding && !embedded {
            embed()
        } else {
            navViewController?.view.frame = bounds
        }
    }

    public override func removeFromSuperview() {
        super.removeFromSuperview()
        // cleanup and teardown any existing resources
        self.navViewController?.removeFromParent()

        // MARK: End CarPlay Navigation
        if let carPlayNavigation = UIApplication.shared.delegate as? MapboxCarPlayNavigationDelegate {
            carPlayNavigation.endNavigation()
        }
        // v3: NavigationSettings is gone, so there is no `.navigationSettingsDidChange` observer to remove.
        // Release the provider so the trip session + voice tear down with the view.
        self.navigationProvider = nil
    }

    private func profileIdentifier() -> ProfileIdentifier {
        switch travelMode {
        case "cycling":
            return .cycling
        case "walking":
            return .walking
        case "driving":
            return .automobile
        default:
            return .automobileAvoidingTraffic
        }
    }

    private func embed() {
        guard startOrigin.count == 2 && destination.count == 2 else { return }

        embedding = true

        let originWaypoint = Waypoint(
            coordinate: CLLocationCoordinate2D(
                latitude: startOrigin[1] as! CLLocationDegrees,
                longitude: startOrigin[0] as! CLLocationDegrees
            )
        )
        var waypointsArray = [originWaypoint]
        waypointsArray.append(contentsOf: waypoints)

        let destinationWaypoint = Waypoint(
            coordinate: CLLocationCoordinate2D(
                latitude: destination[1] as! CLLocationDegrees,
                longitude: destination[0] as! CLLocationDegrees
            ),
            name: destinationTitle as String
        )
        waypointsArray.append(destinationWaypoint)

        // NavigationRouteOptions is unchanged in v3 (subclass of MapboxDirections.RouteOptions).
        let options = NavigationRouteOptions(waypoints: waypointsArray, profileIdentifier: profileIdentifier())
        let locale = self.language.replacingOccurrences(of: "-", with: "_")
        options.locale = Locale(identifier: locale)
        options.distanceMeasurementSystem = distanceUnit == "imperial" ? .imperial : .metric

        // v3: the provider replaces v2's Directions.shared + NavigationSettings.shared.
        // Simulation is expressed via CoreConfig.locationSource (was NavigationOptions(simulationMode:)).
        let provider = MapboxNavigationProvider(
            coreConfig: .init(
                locationSource: shouldSimulateRoute ? .simulation(initialLocation: nil) : .live
            )
        )
        self.navigationProvider = provider
        let mapboxNavigation = provider.mapboxNavigation

        // v3: apply mute via the provider's voice controller before the first instruction fires.
        provider.routeVoiceController.speechSynthesizer.muted = self.mute

        // v3: calculateRoutes(options:) is async and returns an awaitable request exposing `.result`.
        let request = mapboxNavigation.routingProvider().calculateRoutes(options: options)

        Task { [weak self] in
            switch await request.result {
            case .failure(let error):
                await MainActor.run {
                    guard let strongSelf = self else { return }
                    strongSelf.onError?(["message": error.localizedDescription])
                    strongSelf.embedding = false
                }
            case .success(let routes):
                await MainActor.run {
                    guard let strongSelf = self else { return }
                    guard let parentVC = strongSelf.parentViewController else {
                        strongSelf.embedding = false
                        return
                    }
                    strongSelf.navigationRoutes = routes

                    // v3 NavigationOptions requires mapboxNavigation:, voiceController:, eventsManager:.
                    let navigationOptions = NavigationOptions(
                        mapboxNavigation: mapboxNavigation,
                        voiceController: provider.routeVoiceController,
                        eventsManager: provider.eventsManager()
                    )

                    // v3 init takes the computed NavigationRoutes + NavigationOptions.
                    let vc = NavigationViewController(
                        navigationRoutes: routes,
                        navigationOptions: navigationOptions
                    )

                    vc.showsEndOfRouteFeedback = strongSelf.showsEndOfRouteFeedback
                    StatusView.appearance().isHidden = strongSelf.hideStatusView

                    vc.delegate = strongSelf

                    parentVC.addChild(vc)
                    strongSelf.addSubview(vc.view)
                    vc.view.frame = strongSelf.bounds
                    vc.didMove(toParent: parentVC)
                    strongSelf.navViewController = vc

                    strongSelf.embedding = false
                    strongSelf.embedded = true

                    // MARK: Start CarPlay Navigation
                    if let carPlayNavigation = UIApplication.shared.delegate as? MapboxCarPlayNavigationDelegate {
                        carPlayNavigation.startNavigation(with: strongSelf)
                    }
                }
            }
        }
    }

    // v3 NavigationViewControllerDelegate — `didUpdate progress:` is unchanged from v2.
    public func navigationViewController(_ navigationViewController: NavigationViewController, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
        onLocationChange?([
            "longitude": location.coordinate.longitude,
            "latitude": location.coordinate.latitude,
            "heading": location.course,
            "accuracy": location.horizontalAccuracy.magnitude
        ])
        onRouteProgressChange?([
            "distanceTraveled": progress.distanceTraveled,
            "durationRemaining": progress.durationRemaining,
            "fractionTraveled": progress.fractionTraveled,
            "distanceRemaining": progress.distanceRemaining
        ])
    }

    // Unchanged from v2.
    public func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        if !canceled { return }
        onCancelNavigation?(["message": "Navigation Cancel"])
    }

    // v3 BREAKING CHANGE: `didArriveAt` returns Void (v2 returned Bool — dropped `-> Bool` / `return true`).
    public func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) {
        onArrive?([
            "name": waypoint.name ?? waypoint.description,
            "longitude": waypoint.coordinate.longitude,
            "latitude": waypoint.coordinate.latitude
        ])
    }
}
