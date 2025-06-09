import { Button, StyleSheet, Text, View } from 'react-native';

import MapboxNavigation from '@pawan-pk/react-native-mapbox-navigation';
import { useState, useEffect } from 'react';

export default function App() {
  const [navigating, setNavigating] = useState(false);
  const [customerLocation, setCustomerLocation] = useState({
    latitude: 30.701982,
    longitude: 76.693183,
  });

  useEffect(() => {
    const coords: { latitude: number; longitude: number }[] = [
      { latitude: 30.701982, longitude: 76.693183 },
      { latitude: 30.704476, longitude: 76.690653 },
    ];
    let index = 0;
    const id = setInterval(() => {
      index = (index + 1) % coords.length;
      setCustomerLocation(coords[index]!);
    }, 10000);
    return () => clearInterval(id);
  }, []);

  if (!navigating) {
    return (
      <View style={styles.container}>
        <View style={styles.main}>
          <Text style={styles.heading}>
            Hit below button to start navigating
          </Text>
          <Button
            onPress={() => setNavigating(true)}
            title="Start Navigation"
          />
        </View>
      </View>
    );
  }

  return (
    <MapboxNavigation
      startOrigin={{ latitude: 30.699239, longitude: 76.6905161 }}
      // destination={{ latitude: 30.6590196, longitude: 76.8185852 }}
      destination={{
        latitude: 30.709241,
        longitude: 76.695669,
        title: 'Pickup',
      }}
      travelMode="driving-traffic"
      style={styles.container}
      shouldSimulateRoute={true}
      showCancelButton={true}
      // waypoints={[
      //   { latitude: 30.726848, longitude: 76.733758 },
      //   { latitude: 30.738819, longitude: 76.757902 },
      // ]}
      waypoints={[
        {
          latitude: 30.701982,
          longitude: 76.693183,
          name: 'Waypoint 1',
          separatesLegs: true,
        },
        {
          latitude: 30.704476,
          longitude: 76.690653,
          name: 'Waypoint 2',
          separatesLegs: false,
        },
      ]}
      customerLocation={customerLocation}
      language="en"
      distanceUnit="metric"
      onCancelNavigation={() => {
        setNavigating(false);
      }}
      onArrive={(point) => {
        console.log('onArrive', point);
      }}
      onError={(error) => {
        console.log('onError', error);
      }}
    />
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  main: {
    marginTop: 100,
  },
  heading: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
    textAlign: 'center',
  },
});
