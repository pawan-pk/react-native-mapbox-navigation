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
      startOrigin={{ latitude: 30.699239, longitude: 76.6905161 }}
      // destination={{ latitude: 30.6590196, longitude: 76.8185852 }}
      destination={{
        latitude: 30.709241,
        longitude: 76.695669,
        title: 'Pickup',
      }}
      style={styles.container}
      shouldSimulateRoute={true}
      showCancelButton={false}
      // waypoints={[
      //   { latitude: 30.726848, longitude: 76.733758 },
      //   { latitude: 30.738819, longitude: 76.757902 },
      // ]}
      waypoints={[
        { latitude: 30.701982, longitude: 76.693183 },
        { latitude: 30.704476, longitude: 76.690653 },
      ]}
      language="en"
      distanceUnit="metric"
      onCancelNavigation={() => setNavigating(false)}
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
