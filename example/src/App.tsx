import React, {useEffect, useState} from 'react';
import { Text, StatusBar, View, StyleSheet,
  Platform, TouchableOpacity, NativeModules, NativeEventEmitter, Button, FlatList, ScrollView } from 'react-native';
import {PERMISSIONS, RESULTS, requestMultiple} from 'react-native-permissions';
const { RnPolarBle } = NativeModules;

const polarEmitter = new NativeEventEmitter(RnPolarBle);

const deviceName = "C1C6082D";

export default function App() {
  const [log, setLog] = useState("");
  const [hr, setHr] = useState("");
  const [recordStatus, setRecordStatus] = useState("")
  const [devices, setDevices] = useState<string[]>([]);

  useEffect(() => {
    checkPermissions();
  }, []);

  const checkPermissions = async() => {
    if (Platform.OS === 'android') {
      try {
        const permissions = [PERMISSIONS.ANDROID.BLUETOOTH_SCAN, PERMISSIONS.ANDROID.BLUETOOTH_CONNECT, PERMISSIONS.ANDROID.ACCESS_FINE_LOCATION]
        const statuses = await requestMultiple(permissions);
        return permissions.every((permission) => statuses[permission] === RESULTS.GRANTED)
      } catch (e) {
        console.log(`allowLocationPermission error ${e}`);
        return false;
      }
    }
  }

  useEffect(() => {
    polarEmitter.addListener('DEVICE_FOUND', (body) => {
      if (body.name) {
        setDevices(x => ([...x, JSON.stringify(body)]));
      } 
    });
    polarEmitter.addListener('DEVICE_CONNECTING', (body) => {
      console.log(`deviceConnecting - ${JSON.stringify(body)}`)
      setLog(`deviceConnecting - ${JSON.stringify(body)}`)
    });
    polarEmitter.addListener('DEVICE_CONNECTED', (body) => {
      console.log(`deviceConnected - ${JSON.stringify(body)}`)
      setLog(`deviceConnected - ${JSON.stringify(body)}`)
    });
    polarEmitter.addListener('DEVICE_DISCONNECTED', (body) => {
      console.log(`deviceDisconnected - ${JSON.stringify(body)}`)
      setLog(`deviceDisconnected - ${JSON.stringify(body)}`)
    });
    
    polarEmitter.addListener('HR_VALUE_RECEIVED', (body) => {
    //  console.log(`hrValueReceived - ${JSON.stringify(body)}`)
    //  setHr(body.data.hr)
    });

    polarEmitter.addListener('HR_DATA', (body) => {
     console.log(`hrData - ${JSON.stringify(body)}`)
     setLog(`HR_DATA - ${JSON.stringify(body)}`)
    });

    polarEmitter.addListener('ECG_DATA', (body) => {
     console.log(`ecgData - ${JSON.stringify(body)}`)
     setLog(`ecgData - ${JSON.stringify(body)}`)
    });

    polarEmitter.addListener('ACC_DATA', (body) => {
     console.log(`accData - ${JSON.stringify(body)}`)
     setLog(`acc - ${JSON.stringify(body)}`)
    });
    

    polarEmitter.addListener('ECG_FEATURE_READY', (body) => {
      console.log(`ecgFeatureReady - ${JSON.stringify(body)}`)
    //  setLog(`ecgFeatureReady - ${JSON.stringify(body)}`)
    });
    polarEmitter.addListener('HR_FEATURE_READY', (body) => {
      console.log(`hrFeatureReady - ${JSON.stringify(body)}`)
    //  setLog(`hrFeatureReady - ${JSON.stringify(body)}`)
    });
    polarEmitter.addListener('FTP_FEATURE_READY', (body) => {
      console.log(`ftpFeatureReady - ${JSON.stringify(body)}`)
    //  setLog(`ftpFeatureReady - ${JSON.stringify(body)}`)
    });
    polarEmitter.addListener('ACC_FEATURE_READY', (body) => {
      console.log(`accFeatureReady - ${JSON.stringify(body)}`)
    //  setLog(`accFeatureReady - ${JSON.stringify(body)}`)
    });
    polarEmitter.addListener('STREAMING_FEATURES_READY', (body) => {
      console.log(`streamingFeaturesReady - ${JSON.stringify(body)}`)
    //  setLog(`streamingFeaturesReady - ${JSON.stringify(body)}`)
    });

    polarEmitter.addListener('RECORD_STATUS', (body) => {
      console.log(`recordStatus - ${JSON.stringify(body)}`)
      setRecordStatus(body.ongoing)
    });

    polarEmitter.addListener('EXERCISE_ENTRY', (body) => {
      console.log(`exerciseEntry - ${JSON.stringify(body)}`)
      setLog(JSON.stringify(body))
    });

    polarEmitter.addListener('READ_EXERCISE', (body) => {
      console.log(`readExercise - ${JSON.stringify(body)}`)
      setLog(JSON.stringify(body))
    });

  }, []);

  const onPressSearch = () => {
    RnPolarBle.searchForDevice();
  }

  const onPressAutoConnect = () => {
    // RnPolarBle.startAutoConnectToDevice(-55);
  }
  
  const onPressConnect = () => {
    RnPolarBle.connectToDevice(deviceName);
  }

  const onPressDisconnect = () => {
    RnPolarBle.disconnectFromDevice(deviceName);
  }

  const onPressStartHr = () => {
    RnPolarBle.startHrStreaming(deviceName);
  }

  const onPressStopHr = () => {
    RnPolarBle.stopHrStreaming(deviceName);
  }

  const onPressStartECG = () => {
    RnPolarBle.startEcgStreaming(deviceName);
  }

  const onPressStopECG = () => {
    RnPolarBle.stopEcgStreaming(deviceName);
  }

  const onPressStartACC = () => {
    RnPolarBle.startAccStreaming(deviceName);
  }

  const onPressStopACC = () => {
    RnPolarBle.stopAccStreaming(deviceName);
  }

  const onPressGetRecordingStatus  =() => {
    RnPolarBle.getH10RecordingStatus(deviceName);
  }

  const onPressStartRecording = () => {
    RnPolarBle.startH10Recording(deviceName, "test", "hr")
  }

  const onPressStopRecording = () => {
    RnPolarBle.stopH10Recording(deviceName)
  }

  const onPressListExercises = () => {
    RnPolarBle.listExercises(deviceName)
  }

  const onPressReadExercise = () => {
    RnPolarBle.readExercise(deviceName)
  }

  const onPressRemoveExercise = () => {
    RnPolarBle.removeExercise(deviceName)
  }


  const Item = ({item}) => (
    <TouchableOpacity>
      <View style={styles.item}>
        <Text>{item}</Text>
      </View>
    </TouchableOpacity>
  )

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollview}>
        <StatusBar barStyle="dark-content" backgroundColor={'#e4e5ea'} />
        <Text style={styles.title}>Polar BLE Demo</Text>

        <Button
          onPress={onPressSearch}
          title="Search Device"
        />

        <Button
          onPress={onPressAutoConnect}
          title="AutoConnect"
        />

        <Button
          onPress={onPressConnect}
          title="Connect"
        />

        <Button
          onPress={onPressDisconnect}
          title="Disconnect"
        />

        <Button
          onPress={onPressStartHr}
          title="Start Hr"
        />
        <Button
          onPress={onPressStopHr}
          title="Stop Hr"
        />

        <Button
          onPress={onPressStartECG}
          title="Start ECG"
        />
        <Button
          onPress={onPressStopECG}
          title="Stop ECG"
        />

        <Button
          onPress={onPressStartACC}
          title="Start ACC"
        />
        <Button
          onPress={onPressStopACC}
          title="Stop ACC"
        />

        <Button
          onPress={onPressGetRecordingStatus}
          title="Get Recording Status"
        />

        <Button
          onPress={onPressStartRecording}
          title="Start Recording"
        />

        <Button
          onPress={onPressStopRecording}
          title="Stop Recording"
        />

        <Button
          onPress={onPressListExercises}
          title="List Exercises"
        />

        <Button
          onPress={onPressReadExercise}
          title="Read Exercise"
        />

        <Button
          onPress={onPressRemoveExercise}
          title="Remove Exercise"
        />

        <Text style={styles.hr}>
          {`Heart Rate: ${hr}`}
        </Text>

        <Text style={styles.hr}>
          {`Recording Status: ${recordStatus}`}
        </Text>

        <Text style={styles.log}>
          {log}
        </Text>

        <FlatList
          data={devices}
          renderItem={({item}) => <Item item={item} />}
          keyExtractor={item => item}
        />
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#e4e5ea',
    flex: 1,
    paddingTop: 50,
    
  },
  scrollview: {
    alignItems: 'center',
  },
  title: {
    fontSize: 20,
    color: '#000',
    marginVertical: 25,
  },
  hr: {
    width: '90%',
    fontSize: 20,
    color: 'red',
    fontWeight: 'bold'
  },
  log: {
    margin: 20,
    width: '90%',
    height: 200,
    borderColor: 'black',
    borderWidth: 1,
  },
  item: {
    backgroundColor: '#f9c2ff',
    padding: 10,
    marginVertical: 8,
    marginHorizontal: 8,
  },
});
