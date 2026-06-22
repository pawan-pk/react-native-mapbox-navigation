import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

// Imported (not locally declared) so RN codegen name-matches it to the reserved
// image-source primitive — see ./ImageSource for why.

// Event payloads must be declared INSIDE the codegen spec — under the New
// Architecture the Fabric view config (which event props exist at all) is
// generated from this interface. The previous shape declared the events only
// via an `as HostComponent<NativeProps & NativeEventsProps>` cast, so Fabric
// registered ZERO events and every callback (onCancelNavigation, onArrive,
// onError, ...) was silently dropped on New-Arch apps.

export default codegenNativeComponent('MapboxNavigationView');
//# sourceMappingURL=MapboxNavigationViewNativeComponent.mjs.map