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
    var brandedBannerColor: UIColor?
    override func apply() {
        super.apply()
        if let url = customMapStyleURL { mapStyleURL = url }
        if let family = customFontFamily, family.isEmpty == false { fontFamily = family }
        if let brand = brandedBannerColor { applyBrandedTopBannerAppearance(brand) }
    }
}

private final class ResupplyNightStyle: NightStyle {
    var customMapStyleURL: URL?
    var customFontFamily: String?
    var brandedBannerColor: UIColor?
    override func apply() {
        super.apply()
        if let url = customMapStyleURL { mapStyleURL = url }
        if let family = customFontFamily, family.isEmpty == false { fontFamily = family }
        if let brand = brandedBannerColor { applyBrandedTopBannerAppearance(brand) }
    }
}

// Fixed top-banner branding (the `topBannerBackgroundColor` prop): pin the
// maneuver banner, its lane-guidance / "then" strips and the steps list to ONE
// background with white text/icons, identically in the day AND night styles —
// so the SDK's style switching (solar time-of-day, tunnels) never changes the
// chrome, only the map tiles. This runs from BOTH Resupply styles' `apply()`
// AFTER `super.apply()`, re-registering the exact same UIAppearance keys
// (class + containment + trait collection) that DayStyle/NightStyle set — for
// the same key, the later registration wins, so every SDK color the banner
// uses is deterministically replaced. Registrations survive because `apply()`
// re-runs on every style application (including the appearance refresh that
// re-attaches all views).
//
// Known gaps (SDK limitation, cosmetic): road-shield / exit-sign sprites in
// instruction text and server-rendered junction images keep their own colors
// (they are road-sign imagery — same on Google); StepsTableHeaderView (the
// steps-list summary row) is not public in the binary, so it keeps the SDK's
// day/night styling; tap-highlight colors on steps rows (the *Highlighted
// appearance variants) also stay SDK-styled — visible only for the duration
// of a row tap.
private func applyBrandedTopBannerAppearance(_ brand: UIColor) {
    // Slightly darker companion for the secondary strips (lanes / "then" /
    // steps list) so they read as one branded surface with depth.
    let dark = darkenedColor(brand, by: 0.18)
    let white = UIColor.white
    let softWhite = UIColor.white.withAlphaComponent(0.85)
    let mutedWhite = UIColor.white.withAlphaComponent(0.7)

    // DayStyle registers per-idiom (phone + pad separately); mirror it so our
    // keys match (and therefore replace) the SDK's registrations exactly.
    for idiom in [UIUserInterfaceIdiom.phone, .pad] {
        let traits = UITraitCollection(userInterfaceIdiom: idiom)

        // Full-width banner strip (covers the safe-area top too) + instruction row.
        TopBannerView.appearance(for: traits).backgroundColor = brand
        InstructionsBannerView.appearance(for: traits).backgroundColor = brand
        PrimaryLabel.appearance(for: traits, whenContainedInInstancesOf: [InstructionsBannerView.self])
            .normalTextColor = white
        SecondaryLabel.appearance(for: traits, whenContainedInInstancesOf: [InstructionsBannerView.self])
            .normalTextColor = softWhite
        DistanceLabel.appearance(for: traits, whenContainedInInstancesOf: [InstructionsBannerView.self])
            .valueTextColor = white
        DistanceLabel.appearance(for: traits, whenContainedInInstancesOf: [InstructionsBannerView.self])
            .unitTextColor = mutedWhite
        ManeuverView.appearance(for: traits, whenContainedInInstancesOf: [InstructionsBannerView.self])
            .primaryColor = white
        ManeuverView.appearance(for: traits, whenContainedInInstancesOf: [InstructionsBannerView.self])
            .secondaryColor = mutedWhite

        // "Then" strip + lane-guidance row that extend below the banner.
        NextBannerView.appearance(for: traits).backgroundColor = dark
        NextInstructionLabel.appearance(for: traits, whenContainedInInstancesOf: [NextBannerView.self])
            .normalTextColor = white
        ManeuverView.appearance(for: traits, whenContainedInInstancesOf: [NextBannerView.self])
            .primaryColor = white
        ManeuverView.appearance(for: traits, whenContainedInInstancesOf: [NextBannerView.self])
            .secondaryColor = mutedWhite
        LanesView.appearance(for: traits).backgroundColor = dark
        LaneView.appearance(for: traits).primaryColor = white
        LaneView.appearance(for: traits).secondaryColor = UIColor.white.withAlphaComponent(0.4)
        LaneView.appearance(for: traits).primaryColorHighlighted = white
        LaneView.appearance(for: traits).secondaryColorHighlighted = UIColor.white.withAlphaComponent(0.4)

        // Steps list (tap/swipe on the banner) — same branded surface.
        StepsBackgroundView.appearance(for: traits).backgroundColor = dark
        StepInstructionsView.appearance(for: traits).backgroundColor = dark
        StepTableViewCell.appearance(for: traits).backgroundColor = dark
        UITableView.appearance(for: traits, whenContainedInInstancesOf: [StepsViewController.self])
            .backgroundColor = dark
        StepListIndicatorView.appearance(for: traits).gradientColors = [softWhite, mutedWhite, softWhite]
        PrimaryLabel.appearance(for: traits, whenContainedInInstancesOf: [StepInstructionsView.self])
            .normalTextColor = white
        SecondaryLabel.appearance(for: traits, whenContainedInInstancesOf: [StepInstructionsView.self])
            .normalTextColor = softWhite
        DistanceLabel.appearance(for: traits, whenContainedInInstancesOf: [StepInstructionsView.self])
            .valueTextColor = white
        DistanceLabel.appearance(for: traits, whenContainedInInstancesOf: [StepInstructionsView.self])
            .unitTextColor = mutedWhite
        ManeuverView.appearance(for: traits, whenContainedInInstancesOf: [StepInstructionsView.self])
            .primaryColor = white
        ManeuverView.appearance(for: traits, whenContainedInInstancesOf: [StepInstructionsView.self])
            .secondaryColor = mutedWhite

        // Row/section separators inside the banner + steps list.
        SeparatorView.appearance(for: traits).backgroundColor = UIColor.white.withAlphaComponent(0.25)
    }
}

/// `#RRGGBB` (with leading `#`) → UIColor; anything else → nil (prop ignored).
private func colorFromHexString(_ hex: String) -> UIColor? {
    var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value.hasPrefix("#") else { return nil }
    value.removeFirst()
    // allSatisfy guard: UInt32(_:radix:) would tolerate a leading sign.
    guard value.count == 6, value.allSatisfy(\.isHexDigit),
          let rgb = UInt32(value, radix: 16) else { return nil }
    return UIColor(
        red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
        green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
        blue: CGFloat(rgb & 0xFF) / 255.0,
        alpha: 1.0
    )
}

private func darkenedColor(_ color: UIColor, by fraction: CGFloat) -> UIColor {
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return color }
    return UIColor(
        red: red * (1 - fraction),
        green: green * (1 - fraction),
        blue: blue * (1 - fraction),
        alpha: alpha
    )
}

// NavigationViewController with a layout-pass hook. The SDK re-derives chrome
// geometry (ornament margins, viewport padding, banner frames) from inside its
// own `viewDidLayoutSubviews`, so one-shot configuration from embed() cannot
// stick — the wrapper needs a callback on the SAME pass to keep its own
// adjustments converged (trip-bar collapse, camera inset, safe-area deficit).
private final class ResupplyNavigationViewController: NavigationViewController {
    var onViewDidLayout: (() -> Void)?
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        onViewDidLayout?()
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
    // One-shot: the trip bar's GEOMETRY has been collapsed (see
    // collapseTripProgressIfNeeded) — reset when hideTripProgress turns off.
    private var didCollapseTripProgress = false
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
    // Hide the SDK's current-road-name pill (WayNameView, bottom center). With
    // the trip bar hidden it floats over the map and can cover the user puck;
    // hosts drawing their own bottom chrome (Google parity: no road pill) turn
    // it off. The SDK only ever toggles the pill's INNER container, so hiding
    // the outer view is persistent across road-name updates + style changes.
    @objc var hideWayName: Bool = false {
        didSet { applyChromeVisibility() }
    }
    // Fixed top-banner branding: "#RRGGBB" pins the maneuver banner + lane/
    // "then" strips + steps list to that background with white text/icons in
    // BOTH day and night styles — the SDK's style switching (solar time,
    // tunnels) then changes only the map tiles, never the chrome. Assumes a
    // dark brand color (text is always white). Empty = SDK stock banner. On
    // Android the value acts as an on/off switch for the fork-baked brand
    // palette (the maneuver card colors are compile-time resources there).
    @objc var topBannerBackgroundColor: NSString = "" {
        didSet { applyTheme() }
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
        style.brandedBannerColor = brandedBannerColor
        return style
    }

    private func resupplyNightStyle() -> ResupplyNightStyle {
        let style = ResupplyNightStyle()
        style.customMapStyleURL = URL(string: styleUrl as String)
        style.customFontFamily = fontFamily as String
        style.brandedBannerColor = brandedBannerColor
        return style
    }

    // Parsed topBannerBackgroundColor ("" / malformed → nil = stock banner).
    private var brandedBannerColor: UIColor? {
        colorFromHexString(topBannerBackgroundColor as String)
    }

    // True when the caller supplied any custom styling (map style, font and/or
    // banner branding), in which case we route through the Resupply styles
    // instead of the SDK Standard styles.
    private var hasCustomStyle: Bool {
        (styleUrl as String).isEmpty == false
            || (fontFamily as String).isEmpty == false
            || brandedBannerColor != nil
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
        // With the floating stack emptied, floatingButtonsPosition only decides
        // which side the SDK pins the SPEED-LIMIT sign to (it takes the side
        // opposite the buttons). Route it trailing when the app owns the
        // chrome: on the leading side its Y slides with the banner-stack height
        // (1/2-line names, "Rerouting…" status, lane rows) under the host's
        // fixed-position back button. The setter rebuilds the SDK constraints,
        // so skip redundant writes.
        let buttonsPosition: MapOrnamentPosition = hideFloatingButtons ? .topLeading : .topTrailing
        if vc.floatingButtonsPosition != buttonsPosition {
            vc.floatingButtonsPosition = buttonsPosition
        }
        // Current-road pill (bottom center) — the SDK only toggles its inner
        // container, so the outer hide is persistent.
        vc.navigationView.wayNameView.isHidden = hideWayName
        // Trip bar: isHidden takes effect immediately (pre-layout); the
        // geometry collapse follows on the first laid-out pass (see
        // collapseTripProgressIfNeeded). Restoring must run show(animated:)
        // while the container is STILL hidden — show()'s `guard isHidden`
        // early-returns otherwise, leaving the slide-away constraint parked
        // offscreen forever — and it's show()'s zero-duration animation that
        // resets that constraint.
        let container = vc.navigationView.bottomBannerContainerView
        if !hideTripProgress, didCollapseTripProgress {
            didCollapseTripProgress = false
            container.alpha = 1
            // Deterministic guard-pass (also covers a still-deferred hide()
            // completion): force hidden, then show() re-enters the view.
            container.isHidden = true
            container.show(animated: true, duration: 0)
        } else {
            container.isHidden = hideTripProgress
        }
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

    // Collapse the hidden trip bar's GEOMETRY, not just its visibility. The SDK
    // recomputes the logo/attribution ornament margins on EVERY layout pass
    // from the bottom banner container's frame — an isHidden-but-still-114pt
    // container strands both ornaments ~90pt up the map (over host chrome, at
    // a Y that jitters with mid-animation frames). BannerContainerView.hide()
    // slides the container below the view (expansionConstraint = height), so
    // the SDK's own formula then parks the logo bottom-leading and the ⓘ
    // bottom-trailing ~10pt off the raw corners, stably, with no fork-vs-SDK
    // margin fight. Runs from the VC layout hook: the container's frame must
    // be laid out first (height 0 at embed time), and hide() early-returns on
    // an isHidden view — so un-hide invisibly (alpha 0) for the zero-duration
    // slide, its completion re-hides. Reversed in applyChromeVisibility.
    private func collapseTripProgressIfNeeded() {
        guard hideTripProgress, !didCollapseTripProgress,
              let container = navViewController?.navigationView.bottomBannerContainerView,
              container.frame.height > 0 else { return }
        didCollapseTripProgress = true
        container.alpha = 0
        container.isHidden = false
        container.hide(animated: true, duration: 0)
    }

    // Re-assert the caller's bottom camera inset if the SDK recomputed the
    // viewport padding from its own chrome geometry (it does so around
    // mount/appear — setupNavigationCamera + viewDidAppear both write
    // `viewportPadding = cameraPadding`, clobbering the prop). Guarded so the
    // per-layout-pass call is a no-op once converged.
    private func reassertViewportPaddingIfNeeded() {
        guard let mapView = navViewController?.navigationMapView else { return }
        let bottom = CGFloat(truncating: bottomInset)
        guard bottom > 0, mapView.viewportPadding.bottom != bottom else { return }
        applyViewportPadding()
    }

    // Safe-area convergence: mirror the WINDOW's insets into the child VC as a
    // per-edge deficit whenever the host's own resolved insets fall short.
    // Stateless on purpose — the previous one-shot seed/clear protocol died
    // mid-session: every day/night style application runs the SDK's global
    // appearance refresh, which detaches + re-attaches the app's root view
    // from the UIWindow, transiently zeroing safe areas; the first (possibly
    // partial-edge) inset change then cleared the seed with no recovery, and
    // the maneuver banner laid out under the status bar until restart. The
    // deficit formula converges in every event order: real insets → deficit
    // 0; transient zero (detach, embed race, staggered edges) → the window
    // keeps the child inset; detached (window nil) → deficit 0 while
    // offscreen, restored by the next attach's inset/layout pass. The child's
    // additionalSafeAreaInsets can't feed back into the host's own insets, so
    // there is no oscillation; the equality guard keeps redundant layout out.
    // Assumes the wrapper spans the full window (true for the full-screen nav
    // surfaces) — an edge deliberately inset from the window would be
    // double-inset by the deficit.
    private func reconcileChildSafeAreaInsets() {
        guard let vc = navViewController else { return }
        let windowInsets = window?.safeAreaInsets ?? .zero
        let deficit = UIEdgeInsets(
            top: max(0, windowInsets.top - safeAreaInsets.top),
            left: max(0, windowInsets.left - safeAreaInsets.left),
            bottom: max(0, windowInsets.bottom - safeAreaInsets.bottom),
            right: max(0, windowInsets.right - safeAreaInsets.right)
        )
        if vc.additionalSafeAreaInsets != deficit {
            vc.additionalSafeAreaInsets = deficit
            vc.view.setNeedsLayout()
            vc.view.layoutIfNeeded()
        }
    }

    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        reconcileChildSafeAreaInsets()
    }

    // Runs after EVERY layout pass of the embedded VC (see
    // ResupplyNavigationViewController) — each call is guarded/idempotent, so
    // this is cheap and converges the wrapper's adjustments against whatever
    // the SDK re-derived on the same pass.
    private func handleNavViewLayoutPass() {
        reconcileChildSafeAreaInsets()
        collapseTripProgressIfNeeded()
        reassertViewportPaddingIfNeeded()
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
        // Cover inset transitions that coalesce into a layout pass without
        // firing safeAreaInsetsDidChange (e.g. re-attach after the SDK's
        // appearance refresh detaches the root view).
        reconcileChildSafeAreaInsets()
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
                    // Resupply subclass = same VC + a viewDidLayoutSubviews hook
                    // (the SDK re-derives chrome geometry per layout pass, so the
                    // wrapper re-converges its adjustments on the same pass).
                    let vc = ResupplyNavigationViewController(
                        navigationRoutes: routes,
                        navigationOptions: navigationOptions
                    )
                    vc.onViewDidLayout = { [weak self] in
                        self?.handleNavViewLayoutPass()
                    }

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

                    // This async callback can attach the child before the host's
                    // safe area propagated — converge immediately so the banner
                    // never lays out under the status bar (the same reconcile
                    // keeps running on every inset change + layout pass).
                    strongSelf.reconcileChildSafeAreaInsets()

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
                    // (Ornaments need no override anymore: with the trip bar's
                    // geometry collapsed, the SDK's own per-pass margin formula
                    // parks the logo bottom-leading + attribution bottom-trailing
                    // in the raw corners — see collapseTripProgressIfNeeded.)
                    strongSelf.applyChromeVisibility()
                    strongSelf.applyCameraFollowZoom()
                    if strongSelf.routeOverview { strongSelf.applyRouteOverview() }

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
