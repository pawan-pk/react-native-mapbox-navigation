import MapboxNavigation from '@pawan-pk/react-native-mapbox-navigation';
import { StyleSheet } from 'react-native';

export default function App() {
  return (
    <MapboxNavigation
      startOrigin={{ latitude: 30.699239, longitude: 76.6905161 }}
      destination={{ latitude: 30.6590196, longitude: 76.8185852 }}
      style={styles.container}
      shouldSimulateRoute={false}
      showCancelButton={false}
      waypoints={[
        { latitude: 30.726848, longitude: 76.733758 },
        { latitude: 30.7327889, longitude: 76.7609872 },
      ]}
      language="en"
    />
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
