import MapboxDirections
import MapboxNavigationCore
import MapboxNavigationUIKit
import MapboxMaps
import CoreLocation
import AVFoundation
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

// MARK: - Steps-list delegate forwarder

/// Intercepts the top banner's delegate purely to learn when the steps list
/// (tap/swipe on the maneuver banner) opens/closes, so the host app can hide
/// the overlays it draws above the SDK view (the list renders beneath them
/// otherwise). Every callback is forwarded to the original delegate (the
/// NavigationViewController) so SDK behavior is preserved.
private final class StepsListDelegateForwarder: NSObject, TopBannerViewControllerDelegate {
    weak var original: (any TopBannerViewControllerDelegate)?
    var onToggle: ((Bool) -> Void)?

    func topBanner(_ banner: TopBannerViewController, didSwipeInDirection direction: UISwipeGestureRecognizer.Direction) {
        original?.topBanner(banner, didSwipeInDirection: direction)
    }

    func topBanner(_ banner: TopBannerViewController, didSelect legIndex: Int, stepIndex: Int, cell: StepTableViewCell) {
        original?.topBanner(banner, didSelect: legIndex, stepIndex: stepIndex, cell: cell)
    }

    func topBanner(_ banner: TopBannerViewController, willDisplayStepsController: StepsViewController) {
        onToggle?(true)
        original?.topBanner(banner, willDisplayStepsController: willDisplayStepsController)
    }

    func topBanner(_ banner: TopBannerViewController, didDisplayStepsController: StepsViewController) {
        original?.topBanner(banner, didDisplayStepsController: didDisplayStepsController)
    }

    func topBanner(_ banner: TopBannerViewController, willDismissStepsController: StepsViewController) {
        original?.topBanner(banner, willDismissStepsController: willDismissStepsController)
    }

    func topBanner(_ banner: TopBannerViewController, didDismissStepsController: StepsViewController) {
        onToggle?(false)
        original?.topBanner(banner, didDismissStepsController: didDismissStepsController)
    }

    func label(_ label: InstructionLabel, willPresent instruction: VisualInstruction, as presented: NSAttributedString) -> NSAttributedString? {
        return original?.label(label, willPresent: instruction, as: presented)
    }
}

public class MapboxNavigationView: UIView, NavigationViewControllerDelegate {
    public weak var navViewController: NavigationViewController?

    // v3: the computed route set (replaces v2's `IndexedRouteResponse`).
    public var navigationRoutes: NavigationRoutes?

    // Must hold a STRONG ref to the provider for the whole navigation session — it owns the routing
    // provider, voice controller and events manager. If it deallocs, routing + voice stop working.
    private var navigationProvider: MapboxNavigationProvider?

    // Cache the SDK's default floating buttons once so hideFloatingButtons is
    // REVERSIBLE — assigning `floatingButtons = []` is destructive and the SDK
    // never rebuilds the default array on read.
    private var defaultFloatingButtons: [UIButton]?
    private var didCacheFloatingButtons = false
    // Track whether we swapped in a custom viewport data source (followingZoom
    // cap) so we can restore the default when the cap is cleared.
    private var didInstallCustomViewportDataSource = false
    // Emits steps-list open/close to JS; forwards everything else to the VC.
    private let stepsListForwarder = StepsListDelegateForwarder()
    // True while the child VC runs on window-derived seed insets (first mount
    // before the host's safe area propagated) — cleared on the real insets.
    private var seededSafeAreaInsets = false
    // AVAudioSession notification observers (interruption / media reset).
    private var audioSessionObservers: [NSObjectProtocol] = []

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
    // When true, the posted-speed-limit sign stays visible even where Mapbox has
    // no limit data (SpeedLimitView.shouldShowUnknownSpeedLimit). The app forces
    // this on outside production so the sign is visible during testing, and
    // leaves it off in production to avoid blank signs on sparse rural roads.
    @objc var alwaysShowSpeedLimit: Bool = false
    // Whether the bottom-banner cancel (X) button is shown. Defaults to `false`
    // — the host app provides its own exit control, so the SDK's cancel button
    // is suppressed via a cancel-button-free bottom banner (the ETA / distance /
    // arrival banner is kept). Set `true` to restore the SDK's default banner.
    @objc var showCancelButton: Bool = false
    @objc var hideStatusView: Bool = false
    // Live-applied so an app-owned mute toggle (drawn over the nav view) works
    // after the session starts — the provider's synthesizer exists once embed()
    // has run; before that the didSet no-ops.
    @objc var mute: Bool = false {
        didSet { navigationProvider?.routeVoiceController.speechSynthesizer.muted = mute }
    }
    // App-owned chrome (full Google-parity): when the host draws its own nav
    // controls over the view, hide the SDK's built-ins so they don't collide.
    // `hideFloatingButtons` removes the SDK overview/recenter/mute stack;
    // `hideTripProgress` hides the bottom trip/ETA banner (host draws its own
    // ETA card); `routeOverview` drives the camera the app-owned overview toggle
    // would otherwise reach through an SDK button. All default to prior behavior
    // (buttons + banner shown, following camera) so nothing changes unless set.
    @objc var hideFloatingButtons: Bool = false {
        didSet { applyChromeVisibility() }
    }
    @objc var hideTripProgress: Bool = false {
        didSet { applyChromeVisibility() }
    }
    @objc var routeOverview: Bool = false {
        didSet { applyRouteOverview() }
    }
    // Optional cap on the following-camera zoom (Mapbox zoom level). The default
    // follow camera can frame too tight; when set (> 0) the fork installs a
    // viewport data source that clamps the following zoom's upper bound to this
    // value, leaving overview framing untouched. nil/0 = SDK default (no custom
    // data source installed). Tunable via OTA once the build ships the prop.
    @objc var followingZoom: NSNumber? {
        didSet {
            // Skip redundant re-sends — reinstalling the data source on every
            // no-op prop application would glitch the live camera.
            guard followingZoom?.doubleValue != oldValue?.doubleValue else { return }
            applyCameraFollowZoom()
        }
    }
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

    // Hide the SDK's built-in chrome so the host app can draw its own. Setting
    // `floatingButtons = []` removes the SDK's overview/recenter/mute stack;
    // hiding `bottomBannerContainerView` removes the trip/ETA banner. No-op
    // until the VC exists; re-applied on prop change and once in embed().
    private func applyChromeVisibility() {
        guard let vc = navViewController else { return }
        // Cache the SDK default array once so the hide is reversible.
        if !didCacheFloatingButtons {
            defaultFloatingButtons = vc.floatingButtons
            didCacheFloatingButtons = true
        }
        vc.floatingButtons = hideFloatingButtons ? [] : defaultFloatingButtons
        vc.navigationView.bottomBannerContainerView.isHidden = hideTripProgress
    }

    // Drive the follow/overview camera from the app-owned overview toggle (in
    // lieu of the hidden SDK overview button). No-op until the map exists.
    private func applyRouteOverview() {
        guard let camera = navViewController?.navigationMapView?.navigationCamera else { return }
        camera.update(cameraState: routeOverview ? .overview : .following)
    }

    // Clamp the following camera's zoom upper bound so it doesn't frame too
    // tight. Installs a MobileViewportDataSource only when a positive cap is
    // supplied; otherwise the SDK's default data source / zoom is left intact.
    private func applyCameraFollowZoom() {
        guard let mapView = navViewController?.navigationMapView else { return }
        if let followingZoom, followingZoom.doubleValue > 0 {
            let cap = followingZoom.doubleValue
            let dataSource = MobileViewportDataSource(mapView.mapView)
            var options = dataSource.options
            options.followingCameraOptions.zoomRange = Swift.min(2.0, cap)...cap
            dataSource.options = options
            mapView.navigationCamera.viewportDataSource = dataSource
            didInstallCustomViewportDataSource = true
            // A fresh data source can reset camera framing — re-assert padding.
            applyViewportPadding()
        } else if didInstallCustomViewportDataSource {
            // Cap cleared (→ 0) — restore an uncapped default data source so the
            // SDK's default follow framing returns.
            mapView.navigationCamera.viewportDataSource = MobileViewportDataSource(mapView.mapView)
            didInstallCustomViewportDataSource = false
            applyViewportPadding()
        }
    }

    // Keep the SDK ornaments clear of the host app's chrome: the attribution ⓘ
    // defaults to bottom-trailing (under the host's Arrived control) — move it
    // top-trailing below the maneuver banner; pin the logo explicitly to the
    // safe-area bottom-leading corner so it can't drift up into the host's
    // control column. Margins are relative to the MapView's safe area, and
    // ornaments do NOT follow the camera's viewportPadding, so this is
    // deterministic. No-op until the map exists.
    private func applyOrnamentPositions() {
        guard let map = navViewController?.navigationMapView?.mapView else { return }
        var options = map.ornaments.options
        options.attributionButton.position = .topTrailing
        options.attributionButton.margins = CGPoint(x: 8, y: 120)
        options.logo.position = .bottomLeading
        options.logo.margins = CGPoint(x: 8, y: 8)
        map.ornaments.options = options
    }

    // First-mount fix: embed() runs from an async route-calc callback and can
    // attach the child while the host's safe area is still zero (not yet
    // propagated), so the SDK banner laid out under the status bar until an
    // app restart. When the real insets arrive, drop the temporary seed (see
    // embed()) and force the child to re-resolve its safeAreaLayoutGuide.
    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        guard let vc = navViewController else { return }
        if seededSafeAreaInsets {
            vc.additionalSafeAreaInsets = .zero
            seededSafeAreaInsets = false
        }
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()
    }

    // v3 owns the AVAudioSession per-utterance by default: it deactivates the
    // session between prompts, which clips the rapid final instructions near the
    // route end ("voice fades at the end"). Take ownership instead — keep one
    // playback/voicePrompt session active for the whole trip and only tear it
    // down with the view. Paired with `speechSynthesizer.managesAudioSession =
    // false` (set in embed()).
    private func configureVoiceAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .mixWithOthers])
            try session.setActive(true)
        } catch {
            // Non-fatal: if we can't own the session, prompts still play under
            // the SDK's own (default) audio handling.
        }
        installAudioSessionObservers()
    }

    // Because we own the session (managesAudioSession = false), NOTHING
    // re-activates it after an interruption (Siri, a phone call, another app
    // taking audio) — voice guidance would stay silent for the rest of the
    // trip ("sound disappears"). Re-activate when the interruption ends, and
    // rebuild the whole session if media services reset.
    private func installAudioSessionObservers() {
        removeAudioSessionObservers()
        let center = NotificationCenter.default
        audioSessionObservers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard typeValue == AVAudioSession.InterruptionType.ended.rawValue else { return }
            try? AVAudioSession.sharedInstance().setActive(true)
        })
        audioSessionObservers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.configureVoiceAudioSession()
        })
    }

    private func removeAudioSessionObservers() {
        audioSessionObservers.forEach(NotificationCenter.default.removeObserver)
        audioSessionObservers = []
    }

    private func deactivateVoiceAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {}
    }

    @objc var onLocationChange: RCTDirectEventBlock?
    @objc var onRouteProgressChange: RCTDirectEventBlock?
    @objc var onError: RCTDirectEventBlock?
    @objc var onCancelNavigation: RCTDirectEventBlock?
    @objc var onArrive: RCTDirectEventBlock?
    // Fires {visible: Bool} when the SDK steps list (tap/swipe on the maneuver
    // banner) opens/closes, so the host can hide overlays drawn above the view.
    @objc var onStepsListToggle: RCTDirectEventBlock?
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

        // The embedded VC's view is pinned with Auto Layout constraints (see
        // embed()), so it tracks our bounds automatically — no manual frame set.
        if navViewController == nil && !embedding && !embedded {
            embed()
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
        // We took ownership of the audio session (managesAudioSession = false) —
        // release it so other audio resumes when nav ends.
        removeAudioSessionObservers()
        deactivateVoiceAudioSession()
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
        // properties (serialized as max_height / max_width / max_weight). Treat
        // 0 (and nil) as "unset" so omitted dimensions keep the API defaults —
        // matching the Android view's `> 0` convention. (The codegen prop is
        // WithDefault<Double, 0>, so an omitted prop can arrive as 0 rather than
        // nil; applying maximumHeight = 0 m would otherwise reject every road.)
        if let vehicleMaxHeight, vehicleMaxHeight.doubleValue > 0 {
            options.maximumHeight = Measurement(value: vehicleMaxHeight.doubleValue, unit: .meters)
        }
        if let vehicleMaxWidth, vehicleMaxWidth.doubleValue > 0 {
            options.maximumWidth = Measurement(value: vehicleMaxWidth.doubleValue, unit: .meters)
        }
        if let vehicleMaxWeight, vehicleMaxWeight.doubleValue > 0 {
            options.maximumWeight = Measurement(value: vehicleMaxWeight.doubleValue, unit: .metricTons)
        }

        // v3: the provider replaces v2's Directions.shared + NavigationSettings.shared.
        // Simulation is expressed via CoreConfig.locationSource (was NavigationOptions(simulationMode:)).
        //
        // Use the SHARED single provider — iOS allows only one active navigation
        // core, and the offline module (MapboxNavigationOffline) needs the same
        // one. Its config carries the offline-reroute settings (.hybrid +
        // tilestoreConfig .default). Holding navigationProvider keeps a ref for the
        // session; removeFromSuperview niling it just drops the view's ref — the
        // singleton retains the core. See SharedNavigationProvider.
        let provider = SharedNavigationProvider.shared.get(simulated: shouldSimulateRoute)
        self.navigationProvider = provider
        let mapboxNavigation = provider.mapboxNavigation

        // v3: apply mute via the provider's voice controller before the first instruction fires.
        provider.routeVoiceController.speechSynthesizer.muted = self.mute
        // Own the audio session for the whole trip (fixes end-of-route voice
        // clipping caused by the SDK deactivating it between prompts).
        provider.routeVoiceController.speechSynthesizer.managesAudioSession = false
        configureVoiceAudioSession()

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

                    // Hide the SDK status view (reroute / simulating banner)
                    // BEFORE the VC instantiates its views — the appearance proxy
                    // is read when the StatusView instances are created, so setting
                    // it after init is too late. One nav VC runs at a time, so the
                    // global appearance set is safe. (No public per-instance toggle
                    // exists — StatusView lives on the private TopBannerViewController.)
                    StatusView.appearance().isHidden = strongSelf.hideStatusView

                    // v3 init takes the computed NavigationRoutes + NavigationOptions.
                    let vc = NavigationViewController(
                        navigationRoutes: routes,
                        navigationOptions: navigationOptions
                    )

                    vc.showsEndOfRouteFeedback = strongSelf.showsEndOfRouteFeedback
                    // Caller-controlled: hiding this leaves the overview, recenter
                    // and mute buttons in place.
                    vc.showsReportFeedback = strongSelf.showsReportFeedback
                    if strongSelf.theme != "auto" {
                        // Pin the explicit style — don't let time-of-day flip it back.
                        vc.automaticallyAdjustsStyleForTimeOfDay = false
                    }

                    vc.delegate = strongSelf

                    parentVC.addChild(vc)
                    // Pin the child VC's view with Auto Layout instead of a static
                    // frame. A one-shot `frame = bounds` set during this async
                    // callback doesn't let the safe area re-resolve when the view
                    // enters the window, so the maneuver banner drew under the
                    // notch on first mount until an app restart. Constraints
                    // re-resolve the safe area on the first real layout pass. Pin
                    // to the RAW edges — the SDK's NavigationView self-insets.
                    vc.view.translatesAutoresizingMaskIntoConstraints = false
                    strongSelf.addSubview(vc.view)
                    NSLayoutConstraint.activate([
                        vc.view.leadingAnchor.constraint(equalTo: strongSelf.leadingAnchor),
                        vc.view.trailingAnchor.constraint(equalTo: strongSelf.trailingAnchor),
                        vc.view.topAnchor.constraint(equalTo: strongSelf.topAnchor),
                        vc.view.bottomAnchor.constraint(equalTo: strongSelf.bottomAnchor),
                    ])
                    vc.didMove(toParent: parentVC)
                    strongSelf.navViewController = vc

                    // First-mount safe-area seed: if this async callback attached
                    // the child before the host's safe area propagated, hand it
                    // the window's insets so the banner doesn't lay out under the
                    // status bar; cleared in safeAreaInsetsDidChange when the real
                    // insets arrive.
                    if strongSelf.safeAreaInsets == .zero,
                       let windowInsets = strongSelf.window?.safeAreaInsets,
                       windowInsets != .zero {
                        vc.additionalSafeAreaInsets = windowInsets
                        strongSelf.seededSafeAreaInsets = true
                    }

                    // Surface steps-list open/close (tap/swipe on the banner) so
                    // the host can hide the overlays it draws above this view.
                    // The forwarder passes every callback through to the VC.
                    if let topBanner = vc.children.compactMap({ $0 as? TopBannerViewController }).first {
                        strongSelf.stepsListForwarder.original = topBanner.delegate
                        strongSelf.stepsListForwarder.onToggle = { [weak self] visible in
                            self?.onStepsListToggle?(["visible": visible])
                        }
                        topBanner.delegate = strongSelf.stepsListForwarder
                    }

                    // Posted speed-limit sign + current-speed overspeed warning
                    // (parity with the Android speed-info badge). showsSpeedLimits
                    // is on by default; set it explicitly. shouldShowUnknownSpeedLimit
                    // keeps the sign visible where Mapbox has no posted-limit data
                    // (driven by the alwaysShowSpeedLimit prop). Accessed after the
                    // view is loaded (addSubview above) so speedLimitView exists.
                    vc.showsSpeedLimits = true
                    // speedLimitView lives on the VC's root NavigationView, not
                    // the VC itself.
                    vc.navigationView.speedLimitView.shouldShowUnknownSpeedLimit = strongSelf.alwaysShowSpeedLimit

                    // Apply the app's bottom camera inset now that the map exists.
                    strongSelf.applyViewportPadding()
                    // Apply app-owned chrome + camera config now the VC/map exist.
                    strongSelf.applyChromeVisibility()
                    strongSelf.applyCameraFollowZoom()
                    if strongSelf.routeOverview { strongSelf.applyRouteOverview() }
                    // Keep the SDK logo/attribution ornaments clear of app chrome.
                    strongSelf.applyOrnamentPositions()

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
