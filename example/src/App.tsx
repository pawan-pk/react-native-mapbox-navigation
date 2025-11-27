import { Button, NativeModules, StyleSheet, Text, View } from 'react-native';

import MapboxNavigation from '@pawan-pk/react-native-mapbox-navigation';
import { useEffect, useRef, useState } from 'react';
import useRandomUsers from './realTimeList';
const { ParticipantsManager } = NativeModules;
interface Coordinates {
  latitude: number;
  longitude: number;
}
export default function App() {
  const [navigating, setNavigating] = useState(false);
  const participants = useRandomUsers(); // This changes over time
  const startOrigin: Coordinates = { latitude: 28.4212, longitude: 70.2989 };
  const destination: Coordinates = { latitude: 31.5204, longitude: 74.3587 };
  const waypoints: Coordinates[] = [];
  const [delay, setDelay] = useState(false);
  // 🆕 keep track of last synced participants
  const lastParticipantsRef = useRef<string | null>(null);

  useEffect(() => {
    const timer = setTimeout(() => setDelay(true), 100);
    return () => clearTimeout(timer);
  }, []);
  useEffect(() => {
    if (!ParticipantsManager) {
      console.error('❌ ParticipantsManager not found');
      return;
    }
    const serialized = JSON.stringify(participants);
    if (serialized !== lastParticipantsRef.current) {
      lastParticipantsRef.current = serialized;
      ParticipantsManager.updateParticipants(participants);
      console.log('✅ Updated participants:', participants.length);
    } else {
      console.log('⚡ Skipped duplicate participants update');
    }
  }, [participants]);

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
      startOrigin={startOrigin}
      destination={destination}
      waypoints={waypoints}
      style={styles.map}
      shouldSimulateRoute={false}
      showCancelButton={false}
      language="en"
      distanceUnit={delay ? 'imperial' : 'metric'}
      mute={true}
      separateLegs={false}
      showsEndOfRouteFeedback={false}
      hideStatusView={false}
      onCancelNavigation={() => {
        setNavigating(false);
      }}
      onArrive={(point) => {
        console.log('onArrive', point);
      }}
      onError={(error) => {
        console.log('onError', error);
      }}
      onLocationChange={(location) => {
        console.log('onLocationChange', location);
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
  map: {
    backgroundColor: 'white',
    flex: 1,
  },
});
