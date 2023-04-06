# rn-polar-ble

A React Native Wrapper for [Polar's BLE SDK](https://github.com/polarofficial/polar-ble-sdk)

This package use latest Polar Ble SDK and feel free to push issues if you found something.

## Installation

```sh
npm install rn-polar-ble
```

## Usage

```js
import { NativeModules, NativeEventEmitter } from 'react-native';
const { RnPolarBle } = NativeModules;

const polarEmitter = new NativeEventEmitter(RnPolarBle);

// Events

polarEmitter.addListener('DEVICE_FOUND', (body) => {})
polarEmitter.addListener('DEVICE_CONNECTING', (body) => {})
polarEmitter.addListener('DEVICE_CONNECTED', (body) => {})
polarEmitter.addListener('DEVICE_DISCONNECTED', (body) => {})
polarEmitter.addListener('HR_FEATURE_READY', (body) => {})
polarEmitter.addListener('ECG_FEATURE_READY', (body) => {})
polarEmitter.addListener('ACC_FEATURE_READY', (body) => {})
polarEmitter.addListener('FTP_FEATURE_READY', (body) => {})
polarEmitter.addListener('STREAMING_FEATURES_READY', (body) => {})
polarEmitter.addListener('HR_DATA', (body) => {})
polarEmitter.addListener('ECG_DATA', (body) => {})
polarEmitter.addListener('ACC_DATA', (body) => {})
polarEmitter.addListener('RECORD_STATUS', (body) => {})
polarEmitter.addListener('EXERCISE_ENTRY', (body) => {})
polarEmitter.addListener('READ_EXERCISE', (body) => {})

// Functions
RnPolarBle.searchForDevice();
RnPolarBle.startAutoConnectToDevice(-55);
RnPolarBle.connectToDevice("deviceId");
RnPolarBle.disconnectFromDevice("deviceId");

RnPolarBle.startHrStreaming("deviceId");
RnPolarBle.stopHrStreaming("deviceId");
RnPolarBle.startEcgStreaming("deviceId");
RnPolarBle.stopEcgStreaming("deviceId");
RnPolarBle.startAccStreaming("deviceId");
RnPolarBle.stopAccStreaming("deviceId");
RnPolarBle.getH10RecordingStatus("deviceId");

sampleType =  "hr" or "rr"
RnPolarBle.startH10Recording("deviceId", "exersiseId", sampleType);

RnPolarBle.stopH10Recording("deviceId");
RnPolarBle.listExercises("deviceId");
RnPolarBle.readExercise("deviceId");
RnPolarBle.removeExercise("deviceId");


```
## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
