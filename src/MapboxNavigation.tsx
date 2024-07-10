import * as React from 'react';

import type { Permission, TextStyle, ViewStyle } from 'react-native';
import {
  PermissionsAndroid,
  Platform,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import type { MapboxNavigationProps } from './types';
import MapboxNavigationView from './MapboxNavigationViewNativeComponent';

// import MapboxNavigationNativeComponent, {
//   Commands,
// } from './MapboxNavigationViewNativeComponent';

const permissions: Array<Permission> =
  Platform.OS === 'android' && Platform.Version >= 33
    ? [
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.POST_NOTIFICATIONS',
      ]
    : ['android.permission.ACCESS_FINE_LOCATION'];

type MapboxNavigationState = {
  prepared: boolean;
  error?: string;
};

class MapboxNavigation extends React.Component<
  MapboxNavigationProps,
  MapboxNavigationState
> {
  constructor(props: MapboxNavigationProps) {
    super(props);
    this.createState();
  }

  createState() {
    this.state = { prepared: false };
  }

  componentDidMount(): void {
    if (Platform.OS === 'android') {
      this.requestPermission();
    } else {
      this.setState({ prepared: true });
    }
  }

  async requestPermission() {
    try {
      let result = await PermissionsAndroid.requestMultiple(permissions);
      type ResultKey = keyof typeof result;
      if (
        result[permissions[0] as ResultKey] ===
        PermissionsAndroid.RESULTS.GRANTED
      ) {
        this.setState({ prepared: true });
      } else {
        const errorMessage = 'Permission is not granted.';
        this.setState({ error: errorMessage });
      }
      if (
        permissions.length > 1 &&
        result[permissions[1] as ResultKey] !==
          PermissionsAndroid.RESULTS.GRANTED
      ) {
        const errorMessage = 'Notification permission is not granted.';
        console.warn(errorMessage);

        this.props.onError?.({
          nativeEvent: { message: errorMessage },
        });
      }
    } catch (e) {
      const error = e as Error;
      this.setState({ error: error.message });
      console.warn('[Mapbox Navigation] ' + error.message);
      this.props.onError?.({
        nativeEvent: { message: error.message },
      });
    }
  }

  _ref?: React.ElementRef<typeof MapboxNavigationView>;

  _captureRef(ref: React.ElementRef<typeof MapboxNavigationView>) {
    this._ref = ref;
  }

  start(): Promise<void> {
    if (this._ref != null) {
      // return Commands.start(this._ref);
    }
    return Promise.resolve();
  }

  stop(): Promise<void> {
    if (this._ref != null) {
      // return Commands.stop(this._ref);
    }
    return Promise.resolve();
  }

  render() {
    if (!this.state.prepared) {
      const overiteViewStyle: ViewStyle = {
        justifyContent: 'center',
        alignItems: 'center',
      };
      const overiteTextStyle: TextStyle = this.state.error
        ? { color: 'red' }
        : {};
      return (
        <View style={[this.props.style, overiteViewStyle]}>
          <Text style={[styles.message, overiteTextStyle]}>Loading...</Text>
        </View>
      );
    }
    const { origin, destination, style, ...rest } = this.props;
    return (
      <View style={style}>
        <MapboxNavigationView
          ref={this._captureRef}
          style={styles.mapbox}
          origin={[origin.longitude, origin.latitude]}
          destination={[destination.longitude, destination.latitude]}
          {...rest}
        />
      </View>
    );
  }
}

const styles = StyleSheet.create({
  mapbox: {
    flex: 1,
  },
  message: {
    textAlign: 'center',
    fontSize: 16,
  },
});

export default MapboxNavigation;
