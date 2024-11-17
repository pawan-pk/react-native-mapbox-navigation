const mapboxStyles = {
  'standard': 'mapbox://styles/mapbox/standard',
  'mapbox-streets': 'mapbox://styles/mapbox/streets-v12',
  'outdoors': 'mapbox://styles/mapbox/outdoors-v12',
  'light': 'mapbox://styles/mapbox/light-v11',
  'dark': 'mapbox://styles/mapbox/dark-v11',
  'satellite': 'mapbox://styles/mapbox/satellite-v9',
  'satellite-streets': 'mapbox://styles/mapbox/satellite-streets-v12',
  'traffic-day': 'mapbox://styles/mapbox/traffic-day-v2',
  'traffic-night': 'mapbox://styles/mapbox/traffic-night-v2',
  'navigation-day': 'mapbox://styles/mapbox/navigation-day-v1',
  'navigation-night': 'mapbox://styles/mapbox/navigation-night-v1',
};

export type MapboxMapStyle = keyof typeof mapboxStyles;

export const getMapStyle = (style?: MapboxMapStyle) => {
  if (style === undefined) {
    return undefined;
  }
  if (style in mapboxStyles) {
    return mapboxStyles[style];
  } else {
    // Return the custom style string (such as a URL or json string)
    return style;
  }
};
