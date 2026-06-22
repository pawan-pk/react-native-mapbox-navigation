import MapboxDirections
import MapboxNavigationCore
import MapboxNavigationUIKit
import MapboxMaps
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

// Custom day/night styles that load a caller-supplied Mapbox style URI (so the
// nav map can match the host app's other maps) and apply a caller-supplied font
// family — both injected via props, nothing app-specific is baked into the fork.
// Subclass DayStyle/NightStyle — NOT StandardDay/NightStyle, which override
// applyMapStyle(to:) to force the Mapbox Standard style and ignore mapStyleURL.
// The plain DayStyle/NightStyle inherit Style.applyMapStyle(to:), which loads
// `mapStyleURL`. `apply()` runs each time the StyleManager applies the style,
// so we re-assert our URL + font there (after super sets the day/night colors).
private final class ResupplyDayStyle: DayStyle {
    var customMapStyleURL: URL?
    var customFontFamily: String?
    override func apply() {
        super.apply()
        if let url = customMapStyleURL { mapStyleURL = url }
        if let family = customFontFamily, family.isEmpty == false { fontFamily = family }
    }
}

private final class ResupplyNightStyle: NightStyle {
    var customMapStyleURL: URL?
    var customFontFamily: String?
    override func apply() {
        super.apply()
        if let url = customMapStyleURL { mapStyleURL = url }
        if let family = customFontFamily, family.isEmpty == false { fontFamily = family }
    }
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
            var waypoint = Waypoint(coordinate: waypointData.coordinate, name: name)
            waypoint.separatesLegs = waypointData.separatesLegs
            return waypoint
        }
    }

    @objc var destination: NSArray = [] {
        didSet { setNeedsLayout() }
    }

    @objc var shouldSimulateRoute: Bool = false
    @objc var showsEndOfRouteFeedback: Bool = false
    // Whether the SDK's report-issue / feedback floating button is shown.
    // Defaults to the SDK default (shown); callers opt out via the prop.
    @objc var showsReportFeedback: Bool = true
    // Whether the bottom-banner cancel (X) button is shown. Defaults to `false`
    // — the host app provides its own exit control, so the SDK's cancel button
    // is suppressed via a cancel-button-free bottom banner (the ETA / distance /
    // arrival banner is kept). Set `true` to restore the SDK's default banner.
    @objc var showCancelButton: Bool = false
    @objc var hideStatusView: Bool = false
    @objc var mute: Bool = false
    @objc var distanceUnit: NSString = "imperial"
    @objc var language: NSString = "us"
    @objc var destinationTitle: NSString = "Destination"
    @objc var travelMode: NSString = "driving-traffic"

    // 'day' | 'night' | 'auto'. Explicit values pin the style (and apply live
    // on prop change via the VC's StyleManager); 'auto' keeps the SDK default
    // (StandardDay/NightStyle switching with time of day).
    @objc var theme: NSString = "auto" {
        didSet { applyTheme() }
    }

    // App Mapbox style URI (e.g. "mapbox://styles/mapbox/light-v11"). When set,
    // the nav map uses it instead of the SDK Standard style so it matches the
    // app's other maps. Empty = prior SDK-default behavior.
    @objc var styleUrl: NSString = "" {
        didSet { applyTheme() }
    }

    // Caller-supplied font family (PostScript family name, e.g. "Rubik") for the
    // nav UI labels. Empty = the SDK default font. The font must be registered
    // in the host app (bundled / runtime-loaded) for UIFont to resolve it.
    @objc var fontFamily: NSString = "" {
        didSet { applyTheme() }
    }

    // Bottom camera inset (points). Keeps the route/puck framed above an app
    // overlay (the donation bottom sheet) drawn over the lower nav view.
    @objc var bottomInset: NSNumber = 0 {
        didSet { applyViewportPadding() }
    }

    // Host-app-supplied location-puck image (e.g. a per-vehicle-type icon the
    // app resolves from its own assets). nil = the SDK's default puck. RN
    // converts the JS image source to a UIImage via RCTConvert.
    @objc var puckImage: UIImage? {
        didSet { applyVehiclePuck() }
    }

    // Host-app-supplied destination-marker image (e.g. the app's donor pin).
    // nil = the SDK's default destination marker. Applied in the `didAdd
    // finalDestinationAnnotation` delegate.
    @objc var destinationImage: UIImage?

    private func resupplyDayStyle() -> ResupplyDayStyle {
        let style = ResupplyDayStyle()
        style.customMapStyleURL = URL(string: styleUrl as String)
        style.customFontFamily = fontFamily as String
        return style
    }

    private func resupplyNightStyle() -> ResupplyNightStyle {
        let style = ResupplyNightStyle()
        style.customMapStyleURL = URL(string: styleUrl as String)
        style.customFontFamily = fontFamily as String
        return style
    }

    // True when the caller supplied any custom styling (map style and/or font),
    // in which case we route through the Resupply styles instead of the SDK
    // Standard styles.
    private var hasCustomStyle: Bool {
        (styleUrl as String).isEmpty == false || (fontFamily as String).isEmpty == false
    }

    // Initial styles passed through NavigationOptions(styles:) in embed().
    // With custom styling we use the Resupply day/night styles; otherwise we
    // keep the prior SDK-default behavior (Standard styles / nil for auto).
    private func stylesForTheme() -> [Style]? {
        switch theme {
        case "day":
            return [hasCustomStyle ? resupplyDayStyle() : StandardDayStyle()]
        case "night":
            return [hasCustomStyle ? resupplyNightStyle() : StandardNightStyle()]
        default:
            return hasCustomStyle ? [resupplyDayStyle(), resupplyNightStyle()] : nil
        }
    }

    // Live re-style for theme / styleUrl / fontFamily changes after the VC is
    // embedded (pre-embed, the initial style goes through NavigationOptions).
    private func applyTheme() {
        guard let vc = navViewController else { return }
        switch theme {
        case "day":
            vc.styleManager.automaticallyAdjustsStyleForTimeOfDay = false
            vc.styleManager.styles = [hasCustomStyle ? resupplyDayStyle() : StandardDayStyle()]
            vc.styleManager.applyStyle(type: .day)
        case "night":
            vc.styleManager.automaticallyAdjustsStyleForTimeOfDay = false
            vc.styleManager.styles = [hasCustomStyle ? resupplyNightStyle() : StandardNightStyle()]
            vc.styleManager.applyStyle(type: .night)
        default:
            vc.styleManager.styles = hasCustomStyle
                ? [resupplyDayStyle(), resupplyNightStyle()]
                : [StandardDayStyle(), StandardNightStyle()]
            vc.styleManager.automaticallyAdjustsStyleForTimeOfDay = true
        }
    }

    // Push the SDK camera's bottom padding so the route/puck clear the app's
    // bottom sheet. Only the bottom edge is overridden — the SDK's own top/
    // side padding (which frames content under the maneuver banner) is kept.
    // No-op until the VC (and its map) exist.
    private func applyViewportPadding() {
        guard let mapView = navViewController?.navigationMapView else { return }
        var padding = mapView.viewportPadding
        padding.bottom = CGFloat(truncating: bottomInset)
        mapView.viewportPadding = padding
    }

    // Swap the location puck for the host-app-supplied image (used as the
    // bearing image so it rotates to the travel course). nil leaves the SDK's
    // default puck untouched.
    private func applyVehiclePuck() {
        guard let mapView = navViewController?.navigationMapView,
              let image = puckImage else { return }
        mapView.puckType = .puck2D(Puck2DConfiguration(bearingImage: image))
        mapView.puckBearing = .course
    }

    // Replace the SDK's default destination marker with the host-app-supplied
    // image (e.g. the app's donor pin) so the embedded nav matches the host's
    // other maps. No image supplied → keep the SDK default.
    public func navigationViewController(
        _ navigationViewController: NavigationViewController,
        didAdd finalDestinationAnnotation: PointAnnotation,
        pointAnnotationManager: PointAnnotationManager
    ) {
        guard let pin = destinationImage else { return }
        var annotation = finalDestinationAnnotation
        annotation.image = .init(image: pin, name: "rspl_destination_pin")
        pointAnnotationManager.annotations = [annotation]
    }

    @objc var onLocationChange: RCTDirectEventBlock?
    @objc var onRouteProgressChange: RCTDirectEventBlock?
    @objc var onError: RCTDirectEventBlock?
    @objc var onCancelNavigation: RCTDirectEventBlock?
    @objc var onArrive: RCTDirectEventBlock?
    // Truck routing constraints. Units match the Mapbox Directions API:
    // height/width in METERS, weight in METRIC TONS (1000 kg). When set, the
    // route is restricted to roads whose posted limit is >= the value (avoiding
    // low bridges / narrow / weight-restricted roads where Mapbox has the data).
    // Omitted (nil) = the API's car-sized defaults (1.6 m / 1.9 m / 2.5 t).
    @objc var vehicleMaxHeight: NSNumber?
    @objc var vehicleMaxWidth: NSNumber?
    @objc var vehicleMaxWeight: NSNumber?

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

        // Truck routing: forward vehicle dimensions to the typed RouteOptions
        // properties (serialized as max_height / max_width / max_weight). Only
        // set when provided so omitted dimensions keep the API defaults.
        if let vehicleMaxHeight {
            options.maximumHeight = Measurement(value: vehicleMaxHeight.doubleValue, unit: .meters)
        }
        if let vehicleMaxWidth {
            options.maximumWidth = Measurement(value: vehicleMaxWidth.doubleValue, unit: .meters)
        }
        if let vehicleMaxWeight {
            options.maximumWeight = Measurement(value: vehicleMaxWeight.doubleValue, unit: .metricTons)
        }

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

                    // The host app provides its own exit control, so by default
                    // suppress the SDK's redundant bottom-banner cancel (X) button
                    // while keeping the ETA / distance / arrival banner. Opt back
                    // in with `showCancelButton`. Subclassing the default banner is
                    // the timing-safe way to hide the button (it only exists after
                    // the banner's `viewDidLoad`); the SDK still wires the subclass
                    // for progress updates the same as the default banner.
                    let bottomBanner: BottomBannerViewController? =
                        strongSelf.showCancelButton ? nil : CancelButtonHiddenBottomBannerViewController()

                    // v3 NavigationOptions requires mapboxNavigation:, voiceController:, eventsManager:.
                    // styles: explicit day/night theme pins a single style; nil = SDK default.
                    let navigationOptions = NavigationOptions(
                        mapboxNavigation: mapboxNavigation,
                        voiceController: provider.routeVoiceController,
                        eventsManager: provider.eventsManager(),
                        styles: strongSelf.stylesForTheme(),
                        bottomBanner: bottomBanner
                    )

                    // v3 init takes the computed NavigationRoutes + NavigationOptions.
                    let vc = NavigationViewController(
                        navigationRoutes: routes,
                        navigationOptions: navigationOptions
                    )

                    vc.showsEndOfRouteFeedback = strongSelf.showsEndOfRouteFeedback
                    // Caller-controlled: hiding this leaves the overview, recenter
                    // and mute buttons in place.
                    vc.showsReportFeedback = strongSelf.showsReportFeedback
                    StatusView.appearance().isHidden = strongSelf.hideStatusView
                    if strongSelf.theme != "auto" {
                        // Pin the explicit style — don't let time-of-day flip it back.
                        vc.automaticallyAdjustsStyleForTimeOfDay = false
                    }

                    vc.delegate = strongSelf

                    parentVC.addChild(vc)
                    strongSelf.addSubview(vc.view)
                    vc.view.frame = strongSelf.bounds
                    vc.didMove(toParent: parentVC)
                    strongSelf.navViewController = vc

                    // Apply the app's bottom camera inset + vehicle puck now that
                    // the map exists.
                    strongSelf.applyViewportPadding()
                    strongSelf.applyVehiclePuck()

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

// MARK: - Cancel-button-free bottom banner

/// The SDK's default bottom banner (ETA / distance / arrival time) with the
/// cancel (X) button hidden. The host app exposes its own back/exit control, so
/// the SDK's cancel button is redundant — `showCancelButton` (default `false`)
/// suppresses it. Hiding via a subclass is timing-safe: `cancelButton` and
/// `verticalDividerView` are implicitly-unwrapped optionals that only become
/// non-nil after `viewDidLoad`.
final class CancelButtonHiddenBottomBannerViewController: BottomBannerViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Hide the cancel (X) button and the vertical divider that separated it
        // from the trip labels. The cancel button is sized by its intrinsic
        // content (no width constraint), so hiding alone leaves its empty slot.
        cancelButton?.isHidden = true
        verticalDividerView?.isHidden = true

        // Re-pin the arrival-time label to the trailing edge so it fills the
        // space the cancel button vacated (the SDK pins it left of the divider,
        // leaving it stranded mid-banner once the divider/button are hidden).
        // Deactivate its existing horizontal constraints first so the new
        // trailing pin doesn't conflict; vertical (centerY) constraints are left
        // intact. Defensive — if the label/constraints aren't found this no-ops
        // and the button/divider simply stay hidden.
        guard let arrivalTimeLabel, let container = arrivalTimeLabel.superview else { return }
        let horizontalAttributes: Set<NSLayoutConstraint.Attribute> = [
            .leading, .trailing, .leadingMargin, .trailingMargin, .centerX, .left, .right,
        ]
        container.constraints
            .filter { constraint in
                let touchesLabel = (constraint.firstItem as? UIView) === arrivalTimeLabel
                    || (constraint.secondItem as? UIView) === arrivalTimeLabel
                return touchesLabel && horizontalAttributes.contains(constraint.firstAttribute)
            }
            .forEach { $0.isActive = false }
        arrivalTimeLabel.trailingAnchor
            .constraint(equalTo: container.trailingAnchor, constant: -16)
            .isActive = true
    }
}
