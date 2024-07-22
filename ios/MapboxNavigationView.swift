
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

@objc
class MapboxNavigationView: UIView, NavigationViewControllerDelegate {
    weak var navViewController: NavigationViewController?
    var embedded: Bool
    var embedding: Bool
    
    @objc var startOrigin: NSArray = [] {
        didSet { setNeedsLayout() }
    }
    
    var waypoints: [Waypoint] = [] {
        didSet { setNeedsLayout() }
    }
    
    @objc func setWaypoints(coordinates: Array<MapboxCoordinate>) {
        waypoints = coordinates.map { Waypoint(coordinate: $0.coordinate) }
    }
    
    @objc var destination: NSArray = [] {
        didSet { setNeedsLayout() }
    }
    
    @objc var shouldSimulateRoute: Bool = false
    @objc var showsEndOfRouteFeedback: Bool = false
    @objc var showCancelButton: Bool = false
    @objc var hideStatusView: Bool = false
    @objc var mute: Bool = false
    @objc var language: NSString = "us"
    
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if (navViewController == nil && !embedding && !embedded) {
            embed()
        } else {
            navViewController?.view.frame = bounds
        }
    }
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
        // cleanup and teardown any existing resources
        self.navViewController?.removeFromParent()
    }
    
    private func embed() {
        guard startOrigin.count == 2 && destination.count == 2 else { return }
        
        embedding = true
        
        let originWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: startOrigin[1] as! CLLocationDegrees, longitude: startOrigin[0] as! CLLocationDegrees))
        var waypointsArray = [originWaypoint]
        
        // Add Waypoints
        waypointsArray.append(contentsOf: waypoints)
        
        let destinationWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: destination[1] as! CLLocationDegrees, longitude: destination[0] as! CLLocationDegrees))
        waypointsArray.append(destinationWaypoint)
        
        let options = NavigationRouteOptions(waypoints: waypointsArray, profileIdentifier: .automobileAvoidingTraffic)
        
        let locale = self.language.replacingOccurrences(of: "-", with: "_")
        options.locale = Locale(identifier: locale)
        
        Directions.shared.calculateRoutes(options: options) { [weak self] result in
            guard let strongSelf = self, let parentVC = strongSelf.parentViewController else {
                return
            }
            
            switch result {
            case .failure(let error):
                strongSelf.onError!(["message": error.localizedDescription])
            case .success(let response):
                let navigationOptions = NavigationOptions(simulationMode: strongSelf.shouldSimulateRoute ? .always : .never)
                let vc = NavigationViewController(for: response, navigationOptions: navigationOptions)
                
                vc.showsEndOfRouteFeedback = strongSelf.showsEndOfRouteFeedback
                StatusView.appearance().isHidden = strongSelf.hideStatusView
                
                NavigationSettings.shared.voiceMuted = strongSelf.mute;
                
                vc.delegate = strongSelf
                
                parentVC.addChild(vc)
                strongSelf.addSubview(vc.view)
                vc.view.frame = strongSelf.bounds
                vc.didMove(toParent: parentVC)
                strongSelf.navViewController = vc
            }
            
            strongSelf.embedding = false
            strongSelf.embedded = true
        }
    }
    
    func navigationViewController(_ navigationViewController: NavigationViewController, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
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
    
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        if (!canceled) {
            return;
        }
        onCancelNavigation?(["message": ""]);
    }
    
    func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
        onArrive?(["message": ""]);
        return true;
    }
}
