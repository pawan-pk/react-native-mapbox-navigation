
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections

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
    public var indexedRouteResponse: IndexedRouteResponse?
    
    var embedded: Bool
    var embedding: Bool

    @objc public var startOrigin: NSArray = [] {
        didSet { setNeedsLayout() }
    }
    
    var waypoints: [Waypoint] = [] {
        didSet { setNeedsLayout() }
    }
    
    func setWaypoints(coordinates: [CLLocationCoordinate2D]) {
        waypoints = coordinates.map { Waypoint(coordinate: $0) }
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

        if (navViewController == nil && !embedding && !embedded) {
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
        NotificationCenter.default.removeObserver(self, name: .navigationSettingsDidChange, object: nil)
    }

    private func embed() {
        guard startOrigin.count == 2 && destination.count == 2 else { return }

        embedding = true

        let originWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: startOrigin[1] as! CLLocationDegrees, longitude: startOrigin[0] as! CLLocationDegrees))
        var waypointsArray = [originWaypoint]

        // Add Waypoints
        waypointsArray.append(contentsOf: waypoints)

        let destinationWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: destination[1] as! CLLocationDegrees, longitude: destination[0] as! CLLocationDegrees), name: destinationTitle as String)
        waypointsArray.append(destinationWaypoint)

        let options = NavigationRouteOptions(waypoints: waypointsArray, profileIdentifier: .automobileAvoidingTraffic)

        let locale = self.language.replacingOccurrences(of: "-", with: "_")
        options.locale = Locale(identifier: locale)
        options.distanceMeasurementSystem =  distanceUnit == "imperial" ? .imperial : .metric

        Directions.shared.calculateRoutes(options: options) { [weak self] result in
            guard let strongSelf = self, let parentVC = strongSelf.parentViewController else {
                return
            }

            switch result {
            case .failure(let error):
                strongSelf.onError!(["message": error.localizedDescription])
            case .success(let response):
                strongSelf.indexedRouteResponse = response
                let navigationOptions = NavigationOptions(simulationMode: strongSelf.shouldSimulateRoute ? .always : .never)
                let vc = NavigationViewController(for: response, navigationOptions: navigationOptions)

                vc.showsEndOfRouteFeedback = strongSelf.showsEndOfRouteFeedback
                StatusView.appearance().isHidden = strongSelf.hideStatusView

                NavigationSettings.shared.voiceMuted = strongSelf.mute
                NavigationSettings.shared.distanceUnit = strongSelf.distanceUnit == "imperial" ? .mile : .kilometer

                vc.delegate = strongSelf

                parentVC.addChild(vc)
                strongSelf.addSubview(vc.view)
                vc.view.frame = strongSelf.bounds
                vc.didMove(toParent: parentVC)
                strongSelf.navViewController = vc
            }

            strongSelf.embedding = false
            strongSelf.embedded = true
            
            // MARK: Start CarPlay Navigation
            if let carPlayNavigation = UIApplication.shared.delegate as? MapboxCarPlayNavigationDelegate {
                carPlayNavigation.startNavigation(with: strongSelf)
            }
        }
    }

    public func navigationViewController(_ navigationViewController: NavigationViewController, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
        onLocationChange?([
            "longitude": location.coordinate.longitude,
            "latitude": location.coordinate.latitude,
            "heading": 0,
            "accuracy": location.horizontalAccuracy.magnitude
        ])
        onRouteProgressChange?([
            "distanceTraveled": progress.distanceTraveled,
            "durationRemaining": progress.durationRemaining,
            "fractionTraveled": progress.fractionTraveled,
            "distanceRemaining": progress.distanceRemaining
        ])
    }

    public func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        if (!canceled) {
            return;
        }
        onCancelNavigation?(["message": ""]);
    }

    public func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
        onArrive?(["message": ""]);
        return true;
    }
}
