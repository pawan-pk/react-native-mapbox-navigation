# @abhinavvv13/react-native-mapbox-navigation

A modified fork of [pawan-pk/react-native-mapbox-navigation](https://github.com/pawan-pk/react-native-mapbox-navigation) with all original features **plus**:

- 🛰️ Customer live location updates  
- 🔄 Automatic reroute when **destination** or **waypoints** change  
- 🌐 Dynamic language switching mid-navigation  
- 🚴 Dynamic travel-mode switching (driving, traffic-aware, walking, cycling)
- traffic lights display

---

## Installation

### 1. Download package

```sh
# yarn
yarn add @abhinavvv13/react-native-mapbox-navigation

# npm
npm install @abhinavvv13/react-native-mapbox-navigation
```

## iOS Specific Instructions

1. Place your secret token in a .netrc file in your OS root directory.

   ```
   machine api.mapbox.com
   login mapbox
   password <INSERT SECRET TOKEN>
   ```

2. Install pods

   ```
   cd ios && pod install
   ```

3. Place your public token in your Xcode project's `Info.plist` and add a `MBXAccessToken` key whose value is your public access token.

4. Add the `UIBackgroundModes` key to `Info.plist` with `audio` and `location` if it is not already present. This will allow your app to deliver audible instructions while it is in the background or the device is locked.

   ```
   <key>UIBackgroundModes</key>
   <array>
     <string>audio</string>
     <string>location</string>
   </array>
   ```

## Android Specific Instructions

1. Place your secret token in your android app's top level `gradle.properties` or `«USER_HOME»/.gradle/gradle.properties` file

   ```
   MAPBOX_DOWNLOADS_TOKEN=<YOUR_MAPBOX_DOWNLOADS_TOKEN>
   ```

2. Open up your _project-level_ `build.gradle` file. Declare the Mapbox Downloads API's `releases/maven` endpoint in the _allprojects_ `repositories` block.

   ```gradle
   allprojects {
       repositories {
           maven {
                 url 'https://api.mapbox.com/downloads/v2/releases/maven'
                 authentication {
                     basic(BasicAuthentication)
                 }
                 credentials {
                   // Do not change the username below.
                   // This should always be `mapbox` (not your username).
                     username = "mapbox"
                     // Use the secret token you stored in gradle.properties as the password
                     password = project.properties['MAPBOX_DOWNLOADS_TOKEN'] ?: ""
                 }
             }
       }
   }
   ```

3. Add Resources<br/>
   To do so create a new string resource file in your app module `(e.g. app/src/main/res/values/mapbox_access_token.xml)` with your public Mapbox API token:

   ```xml
   <?xml version="1.0" encoding="utf-8"?>
    <resources xmlns:tools="http://schemas.android.com/tools">
        <string name="mapbox_access_token" translatable="false" tools:ignore="UnusedResources">YOUR_MAPBOX_ACCESS_TOKEN</string>
    </resources>
   ```

   For more details installation you can read the [Official docs of Mapbox](https://docs.mapbox.com/android/navigation/guides/installation).

## Usage

```js
import React, { useState, useEffect } from 'react';
import { Button, StyleSheet, Text, View } from 'react-native';
import MapboxNavigation from '@abhinavvv13/react-native-mapbox-navigation';

export default function App(): React.JSX.Element {
  const [navigating, setNavigating] = useState(false);

  const [waypoints, setWaypoints] = useState([
    { latitude: 47.541228, longitude: -52.724106 },
    { latitude: 47.653096, longitude: -52.72541 },
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

  useEffect(() => {
    if (!navigating) return;
    const wpTimer = setTimeout(() => {
      setWaypoints([
        { latitude: 47.531664, longitude: -52.806148 },
        { latitude: 47.653096, longitude: -52.72541 },                         
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
```

## `MapboxNavigation` Props

- `startOrigin(Required)` (object): The starting point of the navigation. Should contain latitude and longitude keys.

- `destination(Required)` (object): The destination point of the navigation. Should contain latitude and longitude keys. **`Now supports change of coordinates dynamically`**

- `waypoints` (array): The waypoints for navigation points between startOrigin and destination. Should contains array of latitude and longitude keys.
- `customerLocation` (object): Current customer coordinate to show on the map.

- `style` (StyleObject): Custom styles for the navigation mapview.

- `shouldSimulateRoute` (boolean): [iOS Only] If true, simulates the route for testing purposes. Defaults to `false`.

- `showCancelButton` (boolean): [Android Only] If true, shows a cancel button on the navigation screen. Defaults to `false`.

- `language` (string): The language for the navigation instructions. Defaults to `en`.

- `distanceUnit` ('metric' | 'imperial'): Unit of direction and voice instructions (default is 'imperial')

- `customerLocation` draws a customer annonation at given coordinates. Coordinates can be changed dynamically in JS.

- `onLocationChange`: Function that is called frequently during route navigation. It receives `latitude`, `longitude`, `heading` and `accuracy` as parameters that represent the current location during navigation.

- `onRouteProgressChange`: Function that is called frequently during route navigation. It receives `distanceTraveled`, `durationRemaining`, `fractionTraveled`, and `distanceRemaining` as parameters.

- `onError`: Function that is called whenever an error occurs. It receives a `message` parameter that describes the error that occurred.

- `onCancelNavigation`: Function that is called whenever a user cancels navigation.

- `onArrive`: Function that is called when you arrive at the provided destination.

- `travelMode` ('driving' | 'driving-traffic' | 'walking' | 'cycling'): Specifies the mode of travel to be used for navigation (default is 'driving-traffic'):
  - 'driving': Standard automobile navigation that does not take live traffic conditions into account.
  - 'driving-traffic': Automobile navigation that considers current traffic conditions to avoid congestion.
  - 'walking': Navigation for pedestrians.
  - 'cycling': Navigation optimized for cyclists.

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
