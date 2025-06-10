import React, { useState, useEffect } from 'react';
import { Button, StyleSheet, Text, View } from 'react-native';
import MapboxNavigation from '@pawan-pk/react-native-mapbox-navigation';

export default function App() {
  const [navigating, setNavigating] = useState(false);

  // initial customer location
  const [customerLocation, setCustomerLocation] = useState({
    latitude: 47.5712712600387,
    longitude: -52.73387876645573,
  });

  // every 5s, nudge the customer location by a tiny random delta
  useEffect(() => {
    if (!navigating) return;
    const id = setInterval(() => {
      setCustomerLocation((prev) => ({
        latitude: prev.latitude + (Math.random() - 0.5) * 0.0001,
        longitude: prev.longitude + (Math.random() - 0.5) * 0.0001,
      }));
    }, 5_000);
    return () => clearInterval(id);
  }, [navigating]);

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
    <View style={styles.container}>
      <MapboxNavigation
        startOrigin={{
          latitude: 47.56433471443351,
          longitude: -52.72276842173629,
        }}
        destination={{
          latitude: 47.57193546875105,
          longitude: -52.73493943371997,
          title: 'Pickup',
        }}
        customerLocation={customerLocation}
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
      {/* overlay the live coords for testing */}
      <View style={styles.coordsOverlay}>
        <Text>Cust lat: {customerLocation.latitude.toFixed(6)}</Text>
        <Text>Cust lng: {customerLocation.longitude.toFixed(6)}</Text>
      </View>
    </View>
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
  coordsOverlay: {
    position: 'absolute',
    top: 40,
    left: 20,
    backgroundColor: 'rgba(255,255,255,0.8)',
    padding: 8,
    borderRadius: 4,
  },
});
