package com.mapboxnavigation

import android.annotation.SuppressLint
import android.content.res.Configuration
import android.content.res.Resources
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import com.facebook.common.executors.CallerThreadExecutor
import com.facebook.common.references.CloseableReference
import com.facebook.datasource.DataSource
import com.facebook.drawee.backends.pipeline.Fresco
import com.facebook.imagepipeline.datasource.BaseBitmapDataSubscriber
import com.facebook.imagepipeline.image.CloseableImage
import com.facebook.imagepipeline.request.ImageRequestBuilder
import com.facebook.react.bridge.Arguments
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.events.RCTEventEmitter
import com.facebook.react.views.imagehelper.ImageSource
import com.mapbox.maps.plugin.annotation.annotations
import com.mapbox.maps.plugin.annotation.generated.PointAnnotationManager
import com.mapbox.maps.plugin.annotation.generated.PointAnnotationOptions
import com.mapbox.maps.plugin.annotation.generated.createPointAnnotationManager
import com.mapbox.api.directions.v5.DirectionsCriteria
import com.mapbox.api.directions.v5.models.DirectionsWaypoint
import com.mapbox.api.directions.v5.models.RouteOptions
import com.mapbox.bindgen.Expected
import com.mapbox.common.location.Location
import com.mapbox.geojson.Point
import com.mapbox.maps.CameraOptions
import com.mapbox.maps.EdgeInsets
import com.mapbox.maps.ImageHolder
import com.mapbox.maps.plugin.LocationPuck2D
import com.mapbox.maps.plugin.animation.camera
import com.mapbox.maps.plugin.locationcomponent.location
import com.mapbox.navigation.base.TimeFormat
import com.mapbox.navigation.base.extensions.applyDefaultNavigationOptions
import com.mapbox.navigation.base.extensions.applyLanguageAndVoiceUnitOptions
import com.mapbox.navigation.base.formatter.DistanceFormatterOptions
import com.mapbox.navigation.base.formatter.UnitType
import com.mapbox.navigation.base.options.NavigationOptions
import com.mapbox.navigation.base.route.NavigationRoute
import com.mapbox.navigation.base.route.NavigationRouterCallback
import com.mapbox.navigation.base.route.RouterFailure
import com.mapbox.navigation.base.route.RouterOrigin
import com.mapbox.navigation.base.trip.model.RouteLegProgress
import com.mapbox.navigation.base.trip.model.RouteProgress
import com.mapbox.navigation.core.MapboxNavigation
import com.mapbox.navigation.core.MapboxNavigationProvider
import com.mapbox.navigation.core.arrival.ArrivalObserver
import com.mapbox.navigation.core.directions.session.RoutesObserver
import com.mapbox.navigation.core.formatter.MapboxDistanceFormatter
import com.mapbox.navigation.core.trip.session.LocationMatcherResult
import com.mapbox.navigation.core.trip.session.LocationObserver
import com.mapbox.navigation.core.trip.session.RouteProgressObserver
import com.mapbox.navigation.core.trip.session.VoiceInstructionsObserver
import com.mapbox.navigation.tripdata.maneuver.api.MapboxManeuverApi
import com.mapbox.navigation.tripdata.progress.api.MapboxTripProgressApi
import com.mapbox.navigation.tripdata.progress.model.DistanceRemainingFormatter
import com.mapbox.navigation.tripdata.progress.model.EstimatedTimeToArrivalFormatter
import com.mapbox.navigation.tripdata.progress.model.PercentDistanceTraveledFormatter
import com.mapbox.navigation.tripdata.progress.model.TimeRemainingFormatter
import com.mapbox.navigation.tripdata.progress.model.TripProgressUpdateFormatter
import com.mapbox.navigation.ui.base.util.MapboxNavigationConsumer
import com.mapbox.navigation.ui.components.maneuver.model.ManeuverPrimaryOptions
import com.mapbox.navigation.ui.components.maneuver.model.ManeuverSecondaryOptions
import com.mapbox.navigation.ui.components.maneuver.model.ManeuverSubOptions
import com.mapbox.navigation.ui.components.maneuver.model.ManeuverViewOptions
import com.mapbox.navigation.ui.components.maneuver.view.MapboxManeuverView
import com.mapbox.navigation.ui.components.tripprogress.view.MapboxTripProgressView
import com.mapbox.navigation.ui.maps.NavigationStyles
import com.mapbox.navigation.ui.maps.camera.NavigationCamera
import com.mapbox.navigation.ui.maps.camera.data.MapboxNavigationViewportDataSource
import com.mapbox.navigation.ui.maps.camera.lifecycle.NavigationBasicGesturesHandler
import com.mapbox.navigation.ui.maps.camera.state.NavigationCameraState
import com.mapbox.navigation.ui.maps.camera.transition.NavigationCameraTransitionOptions
import com.mapbox.navigation.ui.maps.location.NavigationLocationProvider
import com.mapbox.navigation.ui.maps.route.RouteLayerConstants.TOP_LEVEL_ROUTE_LINE_LAYER_ID
import com.mapbox.navigation.ui.maps.route.arrow.api.MapboxRouteArrowApi
import com.mapbox.navigation.ui.maps.route.arrow.api.MapboxRouteArrowView
import com.mapbox.navigation.ui.maps.route.arrow.model.RouteArrowOptions
import com.mapbox.navigation.ui.maps.route.line.api.MapboxRouteLineApi
import com.mapbox.navigation.ui.maps.route.line.api.MapboxRouteLineView
import com.mapbox.navigation.ui.maps.route.line.model.MapboxRouteLineApiOptions
import com.mapbox.navigation.ui.maps.route.line.model.MapboxRouteLineViewOptions
import com.mapbox.navigation.ui.maps.route.line.model.RouteLineColorResources
import com.mapbox.navigation.voice.api.MapboxSpeechApi
import com.mapbox.navigation.voice.api.MapboxVoiceInstructionsPlayer
import com.mapbox.navigation.voice.model.SpeechAnnouncement
import com.mapbox.navigation.voice.model.SpeechError
import com.mapbox.navigation.voice.model.SpeechValue
import com.mapbox.navigation.voice.model.SpeechVolume
import com.mapboxnavigation.databinding.NavigationViewBinding
import java.util.Locale

@SuppressLint("ViewConstructor")
class MapboxNavigationView(private val context: ThemedReactContext): FrameLayout(context.baseContext) {
  private companion object {
    private const val BUTTON_ANIMATION_DURATION = 1500L
  }

  private var origin: Point? = null
  private var destination: Point? = null
  private var destinationTitle: String = "Destination"
  private var waypoints: List<Point> = listOf()
  private var waypointLegs: List<WaypointLegs> = listOf()
  private var distanceUnit: String = DirectionsCriteria.IMPERIAL
  private var locale = Locale.getDefault()
  private var travelMode: String = DirectionsCriteria.PROFILE_DRIVING

  // Truck routing constraints, in Mapbox Directions API units: height/width in
  // METERS, weight in METRIC TONS (1000 kg). 0.0 = not set (the API applies its
  // car-sized defaults of 1.6 m / 1.9 m / 2.5 t). When > 0 the route is limited
  // to roads whose posted limit is >= the value, where Mapbox has the data.
  private var vehicleMaxHeight: Double = 0.0
  private var vehicleMaxWidth: Double = 0.0
  private var vehicleMaxWeight: Double = 0.0

  // True once initNavigation() has run — initIfReady() starts navigation
  // exactly once per view instance, and onDestroy() uses it to know whether
  // the nav APIs were ever initialized.
  private var navigationInitialized = false

  // 'day' | 'night' | 'auto' — 'night' loads the navigation night style;
  // everything else uses the day style (no time-of-day switching here).
  private var theme: String = "auto"

  // App Mapbox style URI (e.g. "mapbox://styles/mapbox/light-v11"). When set it
  // overrides the SDK navigation style so the nav map matches the app's other
  // maps. The app passes the light/dark URI matching the current color scheme.
  private var styleUrl: String = ""

  // Extra bottom camera inset (dp) so the route/puck stay framed above the
  // app's bottom sheet drawn over the lower part of the nav view.
  private var bottomInset: Double = 0.0

  // Host-app-supplied icon URIs (e.g. resolveAssetSource(require('…')).uri). The
  // app owns the art; we load each URI to a Bitmap ourselves (Fresco handles
  // Metro-dev http + release res:// / file://) and apply it to the location puck
  // / destination marker. Empty = the SDK default.
  private var puckImageUri: String = ""
  private var destinationImageUri: String = ""
  private var destinationAnnotationManager: PointAnnotationManager? = null
  private val mainHandler = Handler(Looper.getMainLooper())

  private fun styleForTheme(): String =
    if (styleUrl.isNotEmpty()) styleUrl
    else if (theme == "night") NavigationStyles.NAVIGATION_NIGHT_STYLE
    else NavigationStyles.NAVIGATION_DAY_STYLE

  private val isLandscape: Boolean
    get() = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

  // Base camera padding plus the app-supplied bottom inset (dp → px).
  private fun currentOverviewPadding(): EdgeInsets {
    val base = if (isLandscape) landscapeOverviewPadding else overviewPadding
    return EdgeInsets(base.top, base.left, base.bottom + bottomInset * pixelDensity, base.right)
  }

  private fun currentFollowingPadding(): EdgeInsets {
    val base = if (isLandscape) landscapeFollowingPadding else followingPadding
    return EdgeInsets(base.top, base.left, base.bottom + bottomInset * pixelDensity, base.right)
  }

  /**
   * Bindings to the example layout.
   */
  private var binding: NavigationViewBinding = NavigationViewBinding.inflate(LayoutInflater.from(context), this, true)

  /**
   * Produces the camera frames based on the location and routing data for the [navigationCamera] to execute.
   */
  private var viewportDataSource = MapboxNavigationViewportDataSource(binding.mapView.mapboxMap)

  /**
   * Used to execute camera transitions based on the data generated by the [viewportDataSource].
   * This includes transitions from route overview to route following and continuously updating the camera as the location changes.
   */
  private var navigationCamera = NavigationCamera(
    binding.mapView.mapboxMap,
    binding.mapView.camera,
    viewportDataSource
  )

  /**
   * Mapbox Navigation entry point. There should only be one instance of this object for the app.
   * You can use [MapboxNavigationProvider] to help create and obtain that instance.
   */
  private var mapboxNavigation: MapboxNavigation? = null

  /*
   * Below are generated camera padding values to ensure that the route fits well on screen while
   * other elements are overlaid on top of the map (including instruction view, buttons, etc.)
   */
  private val pixelDensity = Resources.getSystem().displayMetrics.density
  private val overviewPadding: EdgeInsets by lazy {
    EdgeInsets(
      140.0 * pixelDensity,
      40.0 * pixelDensity,
      120.0 * pixelDensity,
      40.0 * pixelDensity
    )
  }
  private val landscapeOverviewPadding: EdgeInsets by lazy {
    EdgeInsets(
      30.0 * pixelDensity,
      380.0 * pixelDensity,
      110.0 * pixelDensity,
      20.0 * pixelDensity
    )
  }
  private val followingPadding: EdgeInsets by lazy {
    EdgeInsets(
      180.0 * pixelDensity,
      40.0 * pixelDensity,
      150.0 * pixelDensity,
      40.0 * pixelDensity
    )
  }
  private val landscapeFollowingPadding: EdgeInsets by lazy {
    EdgeInsets(
      30.0 * pixelDensity,
      380.0 * pixelDensity,
      110.0 * pixelDensity,
      40.0 * pixelDensity
    )
  }

  /**
   * Generates updates for the [MapboxManeuverView] to display the upcoming maneuver instructions
   * and remaining distance to the maneuver point.
   */
  private lateinit var maneuverApi: MapboxManeuverApi

  /**
   * Generates updates for the [MapboxTripProgressView] that include remaining time and distance to the destination.
   */
  private lateinit var tripProgressApi: MapboxTripProgressApi

  /**
   * Stores and updates the state of whether the voice instructions should be played as they come or muted.
   */
  private var isVoiceInstructionsMuted = false
    set(value) {
      field = value
      if (value) {
        binding.soundButton.muteAndExtend(BUTTON_ANIMATION_DURATION)
        voiceInstructionsPlayer?.volume(SpeechVolume(0f))
      } else {
        binding.soundButton.unmuteAndExtend(BUTTON_ANIMATION_DURATION)
        voiceInstructionsPlayer?.volume(SpeechVolume(1f))
      }
    }

  /**
   * Extracts message that should be communicated to the driver about the upcoming maneuver.
   * When possible, downloads a synthesized audio file that can be played back to the driver.
   */
  private lateinit var speechApi: MapboxSpeechApi

  /**
   * Plays the synthesized audio files with upcoming maneuver instructions
   * or uses an on-device Text-To-Speech engine to communicate the message to the driver.
   * NOTE: do not use lazy initialization for this class since it takes some time to initialize
   * the system services required for on-device speech synthesis. With lazy initialization
   * there is a high risk that said services will not be available when the first instruction
   * has to be played. [MapboxVoiceInstructionsPlayer] should be instantiated in
   * `Activity#onCreate`.
   */
  private var voiceInstructionsPlayer: MapboxVoiceInstructionsPlayer? = null

  /**
   * Observes when a new voice instruction should be played.
   */
  private val voiceInstructionsObserver = VoiceInstructionsObserver { voiceInstructions ->
    speechApi.generate(voiceInstructions, speechCallback)
  }

  /**
   * Based on whether the synthesized audio file is available, the callback plays the file
   * or uses the fall back which is played back using the on-device Text-To-Speech engine.
   */
  private val speechCallback =
    MapboxNavigationConsumer<Expected<SpeechError, SpeechValue>> { expected ->
      expected.fold(
        { error ->
          // play the instruction via fallback text-to-speech engine
          voiceInstructionsPlayer?.play(
            error.fallback,
            voiceInstructionsPlayerCallback
          )
        },
        { value ->
          // play the sound file from the external generator
          voiceInstructionsPlayer?.play(
            value.announcement,
            voiceInstructionsPlayerCallback
          )
        }
      )
    }

  /**
   * When a synthesized audio file was downloaded, this callback cleans up the disk after it was played.
   */
  private val voiceInstructionsPlayerCallback =
    MapboxNavigationConsumer<SpeechAnnouncement> { value ->
      // remove already consumed file to free-up space
      speechApi.clean(value)
    }

  /**
   * [NavigationLocationProvider] is a utility class that helps to provide location updates generated by the Navigation SDK
   * to the Maps SDK in order to update the user location indicator on the map.
   */
  private val navigationLocationProvider = NavigationLocationProvider()

  /**
   * RouteLine: Additional route line options are available through the
   * [MapboxRouteLineViewOptions] and [MapboxRouteLineApiOptions].
   * Notice here the [MapboxRouteLineViewOptions.routeLineBelowLayerId] option. The map is made up of layers. In this
   * case the route line will be placed below the "road-label" layer which is a good default
   * for the most common Mapbox navigation related maps. You should consider if this should be
   * changed for your use case especially if you are using a custom map style.
   */
  private val routeLineViewOptions: MapboxRouteLineViewOptions by lazy {
    MapboxRouteLineViewOptions.Builder(context)
      /**
       * Route line related colors can be customized via the [RouteLineColorResources]. If using the
       * default colors the [RouteLineColorResources] does not need to be set as seen here, the
       * defaults will be used internally by the builder.
       */
      .routeLineColorResources(RouteLineColorResources.Builder().build())
      .routeLineBelowLayerId("road-label-navigation")
      .build()
  }

  private val routeLineApiOptions: MapboxRouteLineApiOptions by lazy {
    MapboxRouteLineApiOptions.Builder()
      .build()
  }

  /**
   * RouteLine: This class is responsible for rendering route line related mutations generated
   * by the [routeLineApi]
   */
  private val routeLineView by lazy {
    MapboxRouteLineView(routeLineViewOptions)
  }


  /**
   * RouteLine: This class is responsible for generating route line related data which must be
   * rendered by the [routeLineView] in order to visualize the route line on the map.
   */
  private val routeLineApi: MapboxRouteLineApi by lazy {
    MapboxRouteLineApi(routeLineApiOptions)
  }

  /**
   * RouteArrow: This class is responsible for generating data related to maneuver arrows. The
   * data generated must be rendered by the [routeArrowView] in order to apply mutations to
   * the map.
   */
  private val routeArrowApi: MapboxRouteArrowApi by lazy {
    MapboxRouteArrowApi()
  }

  /**
   * RouteArrow: Customization of the maneuver arrow(s) can be done using the
   * [RouteArrowOptions]. Here the above layer ID is used to determine where in the map layer
   * stack the arrows appear. Above the layer of the route traffic line is being used here. Your
   * use case may necessitate adjusting this to a different layer position.
   */
  private val routeArrowOptions by lazy {
    RouteArrowOptions.Builder(context)
      .withAboveLayerId(TOP_LEVEL_ROUTE_LINE_LAYER_ID)
      .build()
  }

  /**
   * RouteArrow: This class is responsible for rendering the arrow related mutations generated
   * by the [routeArrowApi]
   */
  private val routeArrowView: MapboxRouteArrowView by lazy {
    MapboxRouteArrowView(routeArrowOptions)
  }

  /**
   * Gets notified with location updates.
   *
   * Exposes raw updates coming directly from the location services
   * and the updates enhanced by the Navigation SDK (cleaned up and matched to the road).
   */
  private val locationObserver = object : LocationObserver {
    var firstLocationUpdateReceived = false

    override fun onNewRawLocation(rawLocation: Location) {
      // not handled
    }

    override fun onNewLocationMatcherResult(locationMatcherResult: LocationMatcherResult) {
      val enhancedLocation = locationMatcherResult.enhancedLocation
      // update location puck's position on the map
      navigationLocationProvider.changePosition(
        location = enhancedLocation,
        keyPoints = locationMatcherResult.keyPoints,
      )

      // update camera position to account for new location
      viewportDataSource.onLocationChanged(enhancedLocation)
      viewportDataSource.evaluate()

      // if this is the first location update the activity has received,
      // it's best to immediately move the camera to the current user location
      if (!firstLocationUpdateReceived) {
        firstLocationUpdateReceived = true
        navigationCamera.requestNavigationCameraToOverview(
          stateTransitionOptions = NavigationCameraTransitionOptions.Builder()
            .maxDuration(0) // instant transition
            .build()
        )
      }

      val event = Arguments.createMap()
      event.putDouble("longitude", enhancedLocation.longitude)
      event.putDouble("latitude", enhancedLocation.latitude)
      event.putDouble("heading", enhancedLocation.bearing ?: 0.0)
      event.putDouble("accuracy", enhancedLocation.horizontalAccuracy ?: 0.0)
      context
        .getJSModule(RCTEventEmitter::class.java)
        .receiveEvent(id, "onLocationChange", event)
    }
  }

  /**
   * Gets notified with progress along the currently active route.
   */
  private val routeProgressObserver = RouteProgressObserver { routeProgress ->
    // update the camera position to account for the progressed fragment of the route
    if (routeProgress.fractionTraveled.toDouble() != 0.0) {
      viewportDataSource.onRouteProgressChanged(routeProgress)
    }
    viewportDataSource.evaluate()

    // draw the upcoming maneuver arrow on the map
    val style = binding.mapView.mapboxMap.style
    if (style != null) {
      val maneuverArrowResult = routeArrowApi.addUpcomingManeuverArrow(routeProgress)
      routeArrowView.renderManeuverUpdate(style, maneuverArrowResult)
    }

    // update top banner with maneuver instructions
    val maneuvers = maneuverApi.getManeuvers(routeProgress)
    maneuvers.fold(
      { error ->
        Log.w("Maneuvers error:", error.throwable)
      },
      {
        val maneuverViewOptions = ManeuverViewOptions.Builder()
          .primaryManeuverOptions(
            ManeuverPrimaryOptions.Builder()
              .textAppearance(R.style.PrimaryManeuverTextAppearance)
              .build()
          )
          .secondaryManeuverOptions(
            ManeuverSecondaryOptions.Builder()
              .textAppearance(R.style.ManeuverTextAppearance)
              .build()
          )
          .subManeuverOptions(
            ManeuverSubOptions.Builder()
              .textAppearance(R.style.ManeuverTextAppearance)
              .build()
          )
          .stepDistanceTextAppearance(R.style.StepDistanceRemainingAppearance)
          .build()

        binding.maneuverView.visibility = View.VISIBLE
        binding.maneuverView.updateManeuverViewOptions(maneuverViewOptions)
        binding.maneuverView.renderManeuvers(maneuvers)
      }
    )

    // update bottom trip progress summary
    binding.tripProgressView.render(
      tripProgressApi.getTripProgress(routeProgress)
    )

    val event = Arguments.createMap()
    event.putDouble("distanceTraveled", routeProgress.distanceTraveled.toDouble())
    event.putDouble("durationRemaining", routeProgress.durationRemaining)
    event.putDouble("fractionTraveled", routeProgress.fractionTraveled.toDouble())
    event.putDouble("distanceRemaining", routeProgress.distanceRemaining.toDouble())
    context
      .getJSModule(RCTEventEmitter::class.java)
      .receiveEvent(id, "onRouteProgressChange", event)
  }

  /**
   * Gets notified whenever the tracked routes change.
   *
   * A change can mean:
   * - routes get changed with [MapboxNavigation.setNavigationRoutes]
   * - routes annotations get refreshed (for example, congestion annotation that indicate the live traffic along the route)
   * - driver got off route and a reroute was executed
   */
  private val routesObserver = RoutesObserver { routeUpdateResult ->
    if (routeUpdateResult.navigationRoutes.isNotEmpty()) {
      // generate route geometries asynchronously and render them
      routeLineApi.setNavigationRoutes(
        routeUpdateResult.navigationRoutes
      ) { value ->
        binding.mapView.mapboxMap.style?.apply {
          routeLineView.renderRouteDrawData(this, value)
        }
      }

      // update the camera position to account for the new route
      viewportDataSource.onRouteChanged(routeUpdateResult.navigationRoutes.first())
      viewportDataSource.evaluate()
    } else {
      // remove the route line and route arrow from the map
      val style = binding.mapView.mapboxMap.style
      if (style != null) {
        routeLineApi.clearRouteLine { value ->
          routeLineView.renderClearRouteLineValue(
            style,
            value
          )
        }
        routeArrowView.render(style, routeArrowApi.clearArrows())
      }

      // remove the route reference from camera position evaluations
      viewportDataSource.clearRouteData()
      viewportDataSource.evaluate()
    }
  }

  init {
    onCreate()
  }

  private fun onCreate() {
    // initialize Mapbox Navigation
    mapboxNavigation = if (MapboxNavigationProvider.isCreated()) {
      MapboxNavigationProvider.retrieve()
    } else {
      MapboxNavigationProvider.create(
        NavigationOptions.Builder(context)
          .build()
      )
    }
  }

  @SuppressLint("MissingPermission")
  private fun initNavigation() {
    if (origin == null || destination == null) {
      sendErrorToReact("origin and destination are required")
      return
    }

    // Recenter Camera
    val initialCameraOptions = CameraOptions.Builder()
      .zoom(14.0)
      .center(origin)
      .build()
    binding.mapView.mapboxMap.setCamera(initialCameraOptions)

    // Start Navigation
    startNavigation()

    // set the animations lifecycle listener to ensure the NavigationCamera stops
    // automatically following the user location when the map is interacted with
    binding.mapView.camera.addCameraAnimationsLifecycleListener(
      NavigationBasicGesturesHandler(navigationCamera)
    )
    navigationCamera.registerNavigationCameraStateChangeObserver { navigationCameraState ->
      // shows/hide the recenter button depending on the camera state
      when (navigationCameraState) {
        NavigationCameraState.TRANSITION_TO_FOLLOWING,
        NavigationCameraState.FOLLOWING -> binding.recenter.visibility = View.INVISIBLE

        NavigationCameraState.TRANSITION_TO_OVERVIEW,
        NavigationCameraState.OVERVIEW,
        NavigationCameraState.IDLE -> binding.recenter.visibility = View.VISIBLE
      }
    }
    // set the padding values depending on screen orientation, visible view
    // layout, and the app-supplied bottom inset (the donation sheet overlay).
    viewportDataSource.overviewPadding = currentOverviewPadding()
    viewportDataSource.followingPadding = currentFollowingPadding()

    // make sure to use the same DistanceFormatterOptions across different features
    val unitType = if (distanceUnit == "imperial") UnitType.IMPERIAL else UnitType.METRIC
    val distanceFormatterOptions = DistanceFormatterOptions.Builder(context)
      .unitType(unitType)
      .build()

    // initialize maneuver api that feeds the data to the top banner maneuver view
    maneuverApi = MapboxManeuverApi(
      MapboxDistanceFormatter(distanceFormatterOptions)
    )

    // initialize bottom progress view
    tripProgressApi = MapboxTripProgressApi(
      TripProgressUpdateFormatter.Builder(context)
        .distanceRemainingFormatter(
          DistanceRemainingFormatter(distanceFormatterOptions)
        )
        .timeRemainingFormatter(
          TimeRemainingFormatter(context)
        )
        .percentRouteTraveledFormatter(
          PercentDistanceTraveledFormatter()
        )
        .estimatedTimeToArrivalFormatter(
          EstimatedTimeToArrivalFormatter(context, TimeFormat.NONE_SPECIFIED)
        )
        .build()
    )
    // initialize voice instructions api and the voice instruction player
    speechApi = MapboxSpeechApi(
      context,
      locale.language
    )
    voiceInstructionsPlayer = MapboxVoiceInstructionsPlayer(
      context,
      locale.language
    )

    // load map style (themed: day or night per the `theme` prop)
    binding.mapView.mapboxMap.loadStyle(styleForTheme()) {
      // Ensure that the route line related layers are present before the route arrow
      routeLineView.initializeLayers(it)
      // Style is loaded — safe to add the donor destination marker.
      applyDestinationMarker()
    }

    // initialize view interactions
    binding.stop.setOnClickListener {
      val event = Arguments.createMap()
      event.putString("message", "Navigation Cancel")
      context
        .getJSModule(RCTEventEmitter::class.java)
        .receiveEvent(id, "onCancelNavigation", event)
    }

    binding.recenter.setOnClickListener {
      navigationCamera.requestNavigationCameraToFollowing()
      binding.routeOverview.showTextAndExtend(BUTTON_ANIMATION_DURATION)
    }
    binding.routeOverview.setOnClickListener {
      navigationCamera.requestNavigationCameraToOverview()
      binding.recenter.showTextAndExtend(BUTTON_ANIMATION_DURATION)
    }
    binding.soundButton.setOnClickListener {
      // mute/unmute voice instructions
      isVoiceInstructionsMuted = !isVoiceInstructionsMuted
    }

    // Check initial muted or not
    if (this.isVoiceInstructionsMuted) {
      binding.soundButton.mute()
      voiceInstructionsPlayer?.volume(SpeechVolume(0f))
    } else {
      binding.soundButton.unmute()
      voiceInstructionsPlayer?.volume(SpeechVolume(1f))
    }
  }

  private fun onDestroy() {
    // The view can be dropped before initNavigation() ever ran (e.g. an early
    // error made JS unmount it) — the nav APIs are lateinit / session-bound,
    // so only tear down what was actually initialized.
    if (::maneuverApi.isInitialized) maneuverApi.cancel()
    if (navigationInitialized) {
      routeLineApi.cancel()
      routeLineView.cancel()
    }
    if (::speechApi.isInitialized) speechApi.cancel()
    voiceInstructionsPlayer?.shutdown()
    mapboxNavigation?.stopTripSession()
  }

  private fun startNavigation() {
    // initialize location puck (default; swapped for the app's vehicle icon
    // asynchronously once its bitmap loads)
    binding.mapView.location.apply {
      setLocationProvider(navigationLocationProvider)
      this.locationPuck = LocationPuck2D(
        bearingImage = ImageHolder.Companion.from(
          com.mapbox.navigation.ui.maps.R.drawable.mapbox_navigation_puck_icon
        )
      )
      puckBearingEnabled = true
      enabled = true
    }
    applyCustomPuck()

    startRoute()
  }

  // Load an image URI to a Bitmap via Fresco (RN's pipeline) — handles Metro-dev
  // http, release res:// / file://. Callback always runs on the main thread.
  private fun loadBitmap(uri: String, onBitmap: (Bitmap?) -> Unit) {
    if (uri.isEmpty()) {
      onBitmap(null)
      return
    }
    val imageSource = ImageSource(context, uri)
    val request = ImageRequestBuilder.newBuilderWithSource(imageSource.uri).build()
    val dataSource = Fresco.getImagePipeline().fetchDecodedImage(request, context)
    dataSource.subscribe(object : BaseBitmapDataSubscriber() {
      override fun onNewResultImpl(bitmap: Bitmap?) {
        // Fresco may recycle the bitmap after this callback — copy it.
        val copy = bitmap?.copy(Bitmap.Config.ARGB_8888, false)
        mainHandler.post { onBitmap(copy) }
      }

      override fun onFailureImpl(dataSource: DataSource<CloseableReference<CloseableImage>>) {
        mainHandler.post { onBitmap(null) }
      }
    }, CallerThreadExecutor.getInstance())
  }

  // Swap the location puck for the app-supplied vehicle icon (bearing image, so
  // it rotates to the travel course). No URI / failed load keeps the default.
  private fun applyCustomPuck() {
    if (puckImageUri.isEmpty() || !navigationInitialized) return
    loadBitmap(puckImageUri) { bitmap ->
      if (bitmap != null) {
        binding.mapView.location.locationPuck = LocationPuck2D(
          bearingImage = ImageHolder.from(bitmap)
        )
      }
    }
  }

  // Place the app-supplied donor pin at the destination so the embedded nav
  // matches the app's other maps. Requires a loaded style (called from the
  // loadStyle callback) and a known destination.
  private fun applyDestinationMarker() {
    val dest = destination
    if (destinationImageUri.isEmpty() || dest == null) return
    loadBitmap(destinationImageUri) { bitmap ->
      if (bitmap == null) return@loadBitmap
      val manager = destinationAnnotationManager
        ?: binding.mapView.annotations.createPointAnnotationManager()
          .also { destinationAnnotationManager = it }
      manager.deleteAll()
      manager.create(
        PointAnnotationOptions().withPoint(dest).withIconImage(bitmap)
      )
    }
  }

  private val arrivalObserver = object : ArrivalObserver {

    override fun onWaypointArrival(routeProgress: RouteProgress) {
      onArrival(routeProgress)
    }

    override fun onNextRouteLegStart(routeLegProgress: RouteLegProgress) {
      // do something when the user starts a new leg
    }

    override fun onFinalDestinationArrival(routeProgress: RouteProgress) {
      onArrival(routeProgress)
    }
  }

  private fun onArrival(routeProgress: RouteProgress) {
    val leg = routeProgress.currentLegProgress
    if (leg != null) {
      val event = Arguments.createMap()
      event.putInt("index", leg.legIndex)
      event.putDouble("latitude", leg.legDestination?.location?.latitude() ?: 0.0)
      event.putDouble("longitude", leg.legDestination?.location?.longitude() ?: 0.0)
      context
        .getJSModule(RCTEventEmitter::class.java)
        .receiveEvent(id, "onArrive", event)
    }
  }

  override fun requestLayout() {
    super.requestLayout()
    post(measureAndLayout)
  }

  private val measureAndLayout = Runnable {
    measure(
      MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY)
    )
    layout(left, top, right, bottom)
  }

  private fun findRoute(coordinates: List<Point>) {
    // Separate legs work
    val indices = mutableListOf<Int>()
    val names = mutableListOf<String>()
    indices.add(0)
    names.add("origin")
    indices.addAll(waypointLegs.map { it.index })
    names.addAll(waypointLegs.map { it.name })
    indices.add(coordinates.count() - 1)
    names.add(destinationTitle)

    val routeOptionsBuilder = RouteOptions.builder()
      .applyDefaultNavigationOptions()
      .applyLanguageAndVoiceUnitOptions(context)
      .coordinatesList(coordinates)
      .waypointIndicesList(indices)
      .waypointNamesList(names)
      .language(locale.language)
      .steps(true)
      .voiceInstructions(true)
      .voiceUnits(distanceUnit)
      .profile(travelMode)

    // Truck routing: serialized as max_height / max_width / max_weight. Only
    // applied when set so omitted dimensions keep the API's car-sized defaults.
    if (vehicleMaxHeight > 0) routeOptionsBuilder.maxHeight(vehicleMaxHeight)
    if (vehicleMaxWidth > 0) routeOptionsBuilder.maxWidth(vehicleMaxWidth)
    if (vehicleMaxWeight > 0) routeOptionsBuilder.maxWeight(vehicleMaxWeight)

    mapboxNavigation?.requestRoutes(
      routeOptionsBuilder.build(),
      object : NavigationRouterCallback {
        override fun onCanceled(routeOptions: RouteOptions, @RouterOrigin routerOrigin: String) {
          // no implementation
        }

        override fun onFailure(reasons: List<RouterFailure>, routeOptions: RouteOptions) {
          sendErrorToReact("Error finding route $reasons")
        }

        override fun onRoutesReady(
          routes: List<NavigationRoute>,
          @RouterOrigin routerOrigin: String
        ) {
          setRouteAndStartNavigation(routes)
        }
      }
    )
  }

  @SuppressLint("MissingPermission")
  private fun setRouteAndStartNavigation(routes: List<NavigationRoute>) {
    // set routes, where the first route in the list is the primary route that
    // will be used for active guidance
    mapboxNavigation?.setNavigationRoutes(routes)

    // show UI elements
    binding.soundButton.visibility = View.VISIBLE
    binding.routeOverview.visibility = View.VISIBLE
    binding.tripProgressCard.visibility = View.VISIBLE

    // move the camera to overview when new route is available
//    navigationCamera.requestNavigationCameraToOverview()
    mapboxNavigation?.startTripSession(withForegroundService = true)
  }

  private fun startRoute() {
    // register event listeners
    mapboxNavigation?.registerRoutesObserver(routesObserver)
    mapboxNavigation?.registerArrivalObserver(arrivalObserver)
    mapboxNavigation?.registerRouteProgressObserver(routeProgressObserver)
    mapboxNavigation?.registerLocationObserver(locationObserver)
    mapboxNavigation?.registerVoiceInstructionsObserver(voiceInstructionsObserver)

    // Create a list of coordinates that includes origin, destination
    val coordinatesList = mutableListOf<Point>()
    this.origin?.let { coordinatesList.add(it) }
    this.waypoints.let { coordinatesList.addAll(waypoints) }
    this.destination?.let { coordinatesList.add(it) }

    findRoute(coordinatesList)
  }

  override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    mapboxNavigation?.unregisterRoutesObserver(routesObserver)
    mapboxNavigation?.unregisterArrivalObserver(arrivalObserver)
    mapboxNavigation?.unregisterLocationObserver(locationObserver)
    mapboxNavigation?.unregisterRouteProgressObserver(routeProgressObserver)
    mapboxNavigation?.unregisterVoiceInstructionsObserver(voiceInstructionsObserver)

    // Clear routs and end
    mapboxNavigation?.setNavigationRoutes(listOf())

    // hide UI elements
    binding.soundButton.visibility = View.INVISIBLE
    binding.maneuverView.visibility = View.INVISIBLE
    binding.routeOverview.visibility = View.INVISIBLE
    binding.tripProgressCard.visibility = View.INVISIBLE
  }

  private fun sendErrorToReact(error: String?) {
    val event = Arguments.createMap()
    event.putString("error", error)
    context
      .getJSModule(RCTEventEmitter::class.java)
      .receiveEvent(id, "onError", event)
  }

  fun onDropViewInstance() {
    this.onDestroy()
  }

  fun setStartOrigin(origin: Point?) {
    this.origin = origin
  }

  fun setDestination(destination: Point?) {
    this.destination = destination
  }

  fun setDestinationTitle(title: String) {
    this.destinationTitle = title
  }

  fun setWaypointLegs(legs: List<WaypointLegs>) {
    this.waypointLegs = legs
  }

  fun setWaypoints(waypoints: List<Point>) {
    this.waypoints = waypoints
  }

  fun setDirectionUnit(unit: String) {
    // Just store the unit. Navigation init is driven by initIfReady() (called
    // from the manager's onAfterUpdateTransaction, after ALL props of the
    // mount batch are applied). Initializing from this setter raced prop
    // application order — props apply alphabetically, so `distanceUnit` lands
    // before `startOrigin` and initNavigation() bailed with
    // "origin and destination are required" on every mount.
    this.distanceUnit = unit
  }

  /**
   * Idempotent init trigger — called after every prop transaction. Starts
   * navigation exactly once, as soon as both endpoints are available.
   */
  fun initIfReady() {
    if (navigationInitialized) return
    if (origin == null || destination == null) return
    navigationInitialized = true
    initNavigation()
  }

  fun setLocal(language: String) {
    val locals = language.split("-")
    when (locals.size) {
      1 -> locale = Locale(locals.first())
      2 -> locale = Locale(locals.first(), locals.last())
    }
  }

  fun setMute(mute: Boolean) {
    this.isVoiceInstructionsMuted = mute
  }

  fun setShowCancelButton(show: Boolean) {
    binding.stop.visibility = if (show) View.VISIBLE else View.INVISIBLE
  }

  fun setTravelMode(mode: String) {
    travelMode = when (mode.lowercase()) {
        "walking" -> DirectionsCriteria.PROFILE_WALKING
        "cycling" -> DirectionsCriteria.PROFILE_CYCLING
        "driving" -> DirectionsCriteria.PROFILE_DRIVING
        "driving-traffic" -> DirectionsCriteria.PROFILE_DRIVING_TRAFFIC
        else -> DirectionsCriteria.PROFILE_DRIVING_TRAFFIC
    }
  }

  fun setTheme(theme: String) {
    if (this.theme == theme) return
    this.theme = theme
    // Live re-style when navigation is already up; pre-init, initNavigation()'s
    // loadStyle picks the themed style itself.
    if (navigationInitialized) {
      binding.mapView.mapboxMap.loadStyle(styleForTheme()) {
        routeLineView.initializeLayers(it)
      }
    }
  }

  fun setStyleUrl(url: String) {
    if (this.styleUrl == url) return
    this.styleUrl = url
    // Live re-style when navigation is already up; pre-init, initNavigation()'s
    // loadStyle picks the styled URL itself.
    if (navigationInitialized) {
      binding.mapView.mapboxMap.loadStyle(styleForTheme()) {
        routeLineView.initializeLayers(it)
      }
    }
  }

  // Truck dimensions are read when the route is requested (initNavigation), so
  // these only need to land before nav starts — no live re-route on change.
  fun setVehicleMaxHeight(value: Double) {
    this.vehicleMaxHeight = value
  }

  fun setVehicleMaxWidth(value: Double) {
    this.vehicleMaxWidth = value
  }

  fun setVehicleMaxWeight(value: Double) {
    this.vehicleMaxWeight = value
  }

  fun setBottomInset(inset: Double) {
    if (this.bottomInset == inset) return
    this.bottomInset = inset
    // Re-push the camera padding live once navigation is up; pre-init,
    // initNavigation() applies it from currentOverview/FollowingPadding().
    if (navigationInitialized) {
      viewportDataSource.overviewPadding = currentOverviewPadding()
      viewportDataSource.followingPadding = currentFollowingPadding()
      viewportDataSource.evaluate()
    }
  }

  fun setPuckImageUri(uri: String) {
    if (this.puckImageUri == uri) return
    this.puckImageUri = uri
    // Re-apply live if navigation is already up; otherwise startNavigation()
    // picks it up.
    applyCustomPuck()
  }

  fun setDestinationImageUri(uri: String) {
    if (this.destinationImageUri == uri) return
    this.destinationImageUri = uri
    // Re-apply live if the style/destination are ready; otherwise the loadStyle
    // callback applies it.
    if (navigationInitialized) applyDestinationMarker()
  }
}
