import { Button, StyleSheet, Text, View } from 'react-native';

import MapboxNavigation from '@pawan-pk/react-native-mapbox-navigation';
import { useState } from 'react';

export default function App() {
  const [navigating, setNavigating] = useState(false);

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
      startOrigin={{
        latitude: 47.56433471443351,
        longitude: -52.72276842173629,
      }}
      // destination={{ latitude: 30.6590196, longitude: 76.8185852 }}
      destination={{
        latitude: 47.57193546875105,
        longitude: -52.73493943371997,
        title: 'Pickup',
      }}
      customerLocation={{
        latitude: 47.5712712600387,
        longitude: -52.73387876645573,
      }}
      travelMode="driving-traffic"
      style={styles.container}
      shouldSimulateRoute={true}
      showCancelButton={true}
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
