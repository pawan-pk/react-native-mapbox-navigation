import { useState, useEffect } from 'react';
import { Button, StyleSheet, Text, View } from 'react-native';
import MapboxNavigation from '@abhinavvv13/react-native-mapbox-navigation';

export default function App() {
  const [navigating, setNavigating] = useState(false);

  // initial two waypoints
  const [waypoints, setWaypoints] = useState([
    { latitude: 47.541228, longitude: -52.724106 }, // WP1
    { latitude: 47.653096, longitude: -52.72541 }, // WP2
  ]);

  const [destination, setDestination] = useState({
    latitude: 47.544934773284886,
    longitude: -52.71227031729059,
    title: 'Pickup',
  });

  const [customerLocation, setCustomerLocation] = useState({
    latitude: 47.544934773284886,
    longitude: -52.71227031729059,
  });

  // nudge customer location every 5s
  useEffect(() => {
    if (!navigating) return;
    const id = setInterval(() => {
      setCustomerLocation((prev) => ({
        latitude: prev.latitude + (Math.random() - 0.5) * 0.0001,
        longitude: prev.longitude + (Math.random() - 0.5) * 0.0001,
      }));
    }, 5000);
    return () => clearInterval(id);
  }, [navigating]);

  // change destination after 20s
  useEffect(() => {
    if (!navigating) return;
    const destTimer = setTimeout(() => {
      setDestination({
        latitude: 47.575996906819206,
        longitude: -52.72219571162997,
        title: 'New Destination',
      });
    }, 20000);
    return () => clearTimeout(destTimer);
  }, [navigating]);

  // swap out the first waypoint after 30s
  useEffect(() => {
    if (!navigating) return;
    const wpTimer = setTimeout(() => {
      setWaypoints([
        { latitude: 47.531664, longitude: -52.806148 }, // new WP1
        { latitude: 47.653096, longitude: -52.72541 }, // WP2                                  // keep WP2
      ]);
    }, 30000);
    return () => clearTimeout(wpTimer);
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
        destination={destination}
        waypoints={waypoints}
        customerLocation={customerLocation}
        travelMode="driving-traffic"
        style={styles.container}
        shouldSimulateRoute={true}
        showCancelButton={true}
        language="en"
        distanceUnit="metric"
        onCancelNavigation={() => setNavigating(false)}
        onArrive={(pt) => console.log('onArrive', pt)}
        onError={(err) => console.log('onError', err)}
      />
      <View style={styles.coordsOverlay}>
        <Text>Cust lat: {customerLocation.latitude.toFixed(6)}</Text>
        <Text>Cust lng: {customerLocation.longitude.toFixed(6)}</Text>
        <Text>Dest lat: {destination.latitude.toFixed(6)}</Text>
        <Text>Dest lng: {destination.longitude.toFixed(6)}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  main: { marginTop: 100 },
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
