import * as React from 'react';

import { PermissionsAndroid, StyleSheet, Text, View } from 'react-native';
import type { TextStyle, ViewStyle } from 'react-native';

import type { MapboxNavigationProps } from './types';
import MapboxNavigationView from './MapboxNavigationViewNativeComponent';

// import MapboxNavigationNativeComponent, {
//   Commands,
// } from './MapboxNavigationViewNativeComponent';

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
    this.requestPermission();
  }

  async requestPermission() {
    try {
      let result = await PermissionsAndroid.request(
        'android.permission.ACCESS_FINE_LOCATION'
      );
      if (result === PermissionsAndroid.RESULTS.GRANTED) {
        this.setState({ prepared: true });
      } else {
        const errorMessage = 'Permission is not granted.';
        this.setState({ error: errorMessage });
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
