"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;
var React = _interopRequireWildcard(require("react"));
var _reactNative = require("react-native");
var _MapboxNavigationViewNativeComponent = _interopRequireDefault(require("./MapboxNavigationViewNativeComponent.cjs"));
var _jsxRuntime = require("react/jsx-runtime");
function _interopRequireDefault(e) { return e && e.__esModule ? e : { default: e }; }
function _getRequireWildcardCache(e) { if ("function" != typeof WeakMap) return null; var r = new WeakMap(), t = new WeakMap(); return (_getRequireWildcardCache = function (e) { return e ? t : r; })(e); }
function _interopRequireWildcard(e, r) { if (!r && e && e.__esModule) return e; if (null === e || "object" != typeof e && "function" != typeof e) return { default: e }; var t = _getRequireWildcardCache(r); if (t && t.has(e)) return t.get(e); var n = { __proto__: null }, a = Object.defineProperty && Object.getOwnPropertyDescriptor; for (var u in e) if ("default" !== u && {}.hasOwnProperty.call(e, u)) { var i = a ? Object.getOwnPropertyDescriptor(e, u) : null; i && (i.get || i.set) ? Object.defineProperty(n, u, i) : n[u] = e[u]; } return n.default = e, t && t.set(e, n), n; }
// import MapboxNavigationNativeComponent, {
//   Commands,
// } from './MapboxNavigationViewNativeComponent';
const permissions = _reactNative.Platform.OS === 'android' && _reactNative.Platform.Version >= 33 ? ['android.permission.ACCESS_FINE_LOCATION', 'android.permission.POST_NOTIFICATIONS'] : ['android.permission.ACCESS_FINE_LOCATION'];
class MapboxNavigation extends React.Component {
  constructor(props) {
    super(props);
    this.createState();
  }
  createState() {
    this.state = {
      prepared: false
    };
  }
  componentDidMount() {
    if (_reactNative.Platform.OS === 'android') {
      this.requestPermission();
    } else {
      this.setState({
        prepared: true
      });
    }
  }
  async requestPermission() {
    try {
      let result = await _reactNative.PermissionsAndroid.requestMultiple(permissions);
      if (result[permissions[0]] === _reactNative.PermissionsAndroid.RESULTS.GRANTED) {
        this.setState({
          prepared: true
        });
      } else {
        const errorMessage = 'Permission is not granted.';
        this.setState({
          error: errorMessage
        });
      }
      if (permissions.length > 1 && result[permissions[1]] !== _reactNative.PermissionsAndroid.RESULTS.GRANTED) {
        const errorMessage = 'Notification permission is not granted.';
        console.warn(errorMessage);
        this.props.onError?.({
          message: errorMessage
        });
      }
    } catch (e) {
      const error = e;
      this.setState({
        error: error.message
      });
      console.warn('[Mapbox Navigation] ' + error.message);
      this.props.onError?.({
        message: error.message
      });
    }
  }
  render() {
    if (!this.state.prepared) {
      const overiteViewStyle = {
        justifyContent: 'center',
        alignItems: 'center'
      };
      const overiteTextStyle = this.state.error ? {
        color: 'red'
      } : {};
      return /*#__PURE__*/(0, _jsxRuntime.jsx)(_reactNative.View, {
        style: [this.props.style, overiteViewStyle],
        children: /*#__PURE__*/(0, _jsxRuntime.jsx)(_reactNative.Text, {
          style: [styles.message, overiteTextStyle],
          children: "Loading..."
        })
      });
    }
    const {
      startOrigin,
      destination,
      style,
      distanceUnit = 'imperial',
      onArrive,
      onLocationChange,
      onRouteProgressChange,
      onCancelNavigation,
      onError,
      travelMode,
      ...rest
    } = this.props;
    return /*#__PURE__*/(0, _jsxRuntime.jsx)(_reactNative.View, {
      style: style,
      children: /*#__PURE__*/(0, _jsxRuntime.jsx)(_MapboxNavigationViewNativeComponent.default, {
        style: styles.mapbox,
        distanceUnit: distanceUnit,
        startOrigin: [startOrigin.longitude, startOrigin.latitude],
        destinationTitle: destination.title,
        destination: [destination.longitude, destination.latitude],
        onLocationChange: event => onLocationChange?.(event.nativeEvent),
        onRouteProgressChange: event => onRouteProgressChange?.(event.nativeEvent),
        onError: event => onError?.(event.nativeEvent),
        onArrive: event => onArrive?.(event.nativeEvent),
        onCancelNavigation: event => onCancelNavigation?.(event.nativeEvent),
        travelMode: travelMode,
        ...rest
      })
    });
  }
}
const styles = _reactNative.StyleSheet.create({
  mapbox: {
    flex: 1
  },
  message: {
    textAlign: 'center',
    fontSize: 16
  }
});
var _default = exports.default = MapboxNavigation;
//# sourceMappingURL=MapboxNavigation.cjs.map