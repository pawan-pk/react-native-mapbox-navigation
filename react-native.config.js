const { codegenConfig } = require('./package.json');

module.exports = {
  project: {
    ios: {},
    android: {},
  },
  dependencies: {},
  codegenConfig: {
    ...codegenConfig,
    android: {
      javaPackageName: 'com.mapboxnavigation',
    },
    ios: {
      podspecPath: 'react-native-mapbox-navigation.podspec',
    },
  },
};
