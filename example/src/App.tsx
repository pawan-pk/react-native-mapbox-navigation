import MapboxNavigation from '@pawan-pk/react-native-mapbox-navigation';
import { StyleSheet } from 'react-native';

export default function App() {
  return (
    <MapboxNavigation
      origin={{ latitude: 30.699239, longitude: 76.6905161 }}
      destination={{ latitude: 30.6590196, longitude: 76.8185852 }}
      style={styles.container}
      shouldSimulateRoute={false}
    />
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
