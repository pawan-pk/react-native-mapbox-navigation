import {
  Button,
  SafeAreaView,
  StatusBar,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import json from '../../package.json';

import MapboxNavigation from '@pawan-pk/react-native-mapbox-navigation';
import { useState } from 'react';

export default function App() {
  const [navigating, setNavigating] = useState(false);

  if (!navigating) {
    return (
      <SafeAreaView style={styles.container}>
        <StatusBar barStyle="dark-content" />
        <View style={styles.main}>
          <Text style={styles.heading}>Welcome to {json.name}!</Text>
          <Text style={styles.description}>{json.description}</Text>
          <Text style={styles.label}>Author:</Text>
          <Text style={styles.description}>{json.author}</Text>
          <Button
            onPress={() => setNavigating(true)}
            title="Start Navigation"
          />
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <MapboxNavigation
        startOrigin={{ latitude: 30.699239, longitude: 76.6905161 }}
        destination={{
          latitude: 30.709241,
          longitude: 76.695669,
          title: 'Dropoff',
        }}
        style={styles.container}
        profile="driving-traffic"
        mapStyle="navigation-day"
        hideStatusView={false}
        shouldSimulateRoute={true}
        showCancelButton={true}
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
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  main: {
    margin: 20,
    marginTop: 100,
  },
  heading: {
    fontSize: 24,
    marginBottom: 20,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  label: {
    fontSize: 18,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  description: {
    fontSize: 16,
    marginBottom: 40,
    textAlign: 'center',
  },
});
