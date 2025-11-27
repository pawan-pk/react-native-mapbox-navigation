import React, { useEffect, useState } from 'react';
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

const permissions: Array<Permission> =
  Platform.OS === 'android' && Platform.Version >= 33
    ? [
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.POST_NOTIFICATIONS',
      ]
    : ['android.permission.ACCESS_FINE_LOCATION'];

const MapboxNavigation: React.FC<MapboxNavigationProps> = (props) => {
  const [prepared, setPrepared] = useState(false);
  const [error, setError] = useState<string | undefined>();

  useEffect(() => {
    if (Platform.OS === 'android') {
      requestPermission();
    } else {
      setPrepared(true);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const requestPermission = async () => {
    try {
      const result = await PermissionsAndroid.requestMultiple(permissions);
      type ResultKey = keyof typeof result;

      if (
        result[permissions[0] as ResultKey] ===
        PermissionsAndroid.RESULTS.GRANTED
      ) {
        setPrepared(true);
      } else {
        const errorMessage = 'Permission is not granted.';
        setError(errorMessage);
      }

      if (
        permissions.length > 1 &&
        result[permissions[1] as ResultKey] !==
          PermissionsAndroid.RESULTS.GRANTED
      ) {
        const errorMessage = 'Notification permission is not granted.';
        console.warn(errorMessage);
        props.onError?.({ message: errorMessage });
      }
    } catch (e) {
      const err = e as Error;
      setError(err.message);
      console.warn('[Mapbox Navigation] ' + err.message);
      props.onError?.({ message: err.message });
    }
  };

  if (!prepared) {
    const overiteViewStyle: ViewStyle = {
      justifyContent: 'center',
      alignItems: 'center',
    };
    const overiteTextStyle: TextStyle = error ? { color: 'red' } : {};
    return (
      <View style={[props.style, overiteViewStyle]}>
        <Text style={[styles.message, overiteTextStyle]}>Loading...</Text>
      </View>
    );
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
  } = props;

  return (
    <View style={style}>
      <MapboxNavigationView
        style={styles.mapbox}
        distanceUnit={distanceUnit}
        startOrigin={[startOrigin.longitude, startOrigin.latitude]}
        destinationTitle={destination.title}
        destination={[destination.longitude, destination.latitude]}
        onLocationChange={(event) => onLocationChange?.(event.nativeEvent)}
        onRouteProgressChange={(event) =>
          onRouteProgressChange?.(event.nativeEvent)
        }
        onError={(event) => onError?.(event.nativeEvent)}
        onArrive={(event) => onArrive?.(event.nativeEvent)}
        onCancelNavigation={(event) => onCancelNavigation?.(event.nativeEvent)}
        travelMode={travelMode}
        {...rest}
      />
    </View>
  );
};

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
