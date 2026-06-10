import * as React from 'react';
import { PermissionsAndroid, Platform, StyleSheet, Text, View } from 'react-native';
import MapboxNavigationView from "./MapboxNavigationViewNativeComponent.mjs";

// import MapboxNavigationNativeComponent, {
//   Commands,
// } from './MapboxNavigationViewNativeComponent';
import { jsx as _jsx } from "react/jsx-runtime";
const permissions = Platform.OS === 'android' && Platform.Version >= 33 ? ['android.permission.ACCESS_FINE_LOCATION', 'android.permission.POST_NOTIFICATIONS'] : ['android.permission.ACCESS_FINE_LOCATION'];
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
    if (Platform.OS === 'android') {
      this.requestPermission();
    } else {
      this.setState({
        prepared: true
      });
    }
  }
  async requestPermission() {
    try {
      let result = await PermissionsAndroid.requestMultiple(permissions);
      if (result[permissions[0]] === PermissionsAndroid.RESULTS.GRANTED) {
        this.setState({
          prepared: true
        });
      } else {
        const errorMessage = 'Permission is not granted.';
        this.setState({
          error: errorMessage
        });
      }
      if (permissions.length > 1 && result[permissions[1]] !== PermissionsAndroid.RESULTS.GRANTED) {
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
      return /*#__PURE__*/_jsx(View, {
        style: [this.props.style, overiteViewStyle],
        children: /*#__PURE__*/_jsx(Text, {
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
    return /*#__PURE__*/_jsx(View, {
      style: style,
      children: /*#__PURE__*/_jsx(MapboxNavigationView, {
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
const styles = StyleSheet.create({
  mapbox: {
    flex: 1
  },
  message: {
    textAlign: 'center',
    fontSize: 16
  }
});
export default MapboxNavigation;
//# sourceMappingURL=MapboxNavigation.mjs.map