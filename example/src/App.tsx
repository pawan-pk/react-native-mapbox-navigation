import MapboxNavigation from '@pawan-pk/react-native-mapbox-navigation';
import { StyleSheet } from 'react-native';

export default function App() {
  // return <></>;
  return (
    <MapboxNavigation
      startOrigin={{ latitude: 30.699239, longitude: 76.6905161 }}
      // destination={{ latitude: 30.6590196, longitude: 76.8185852 }}
      destination={{ latitude: 30.709241, longitude: 76.695669 }}
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
    />
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
