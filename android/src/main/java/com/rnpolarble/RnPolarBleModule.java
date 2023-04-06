package com.rnpolarble;

import android.util.Log;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.polar.sdk.api.PolarBleApi;
import com.polar.sdk.api.PolarBleApiCallback;
import com.polar.sdk.api.PolarBleApiDefaultImpl;
import com.polar.sdk.api.PolarH10OfflineExerciseApi;
import com.polar.sdk.api.model.PolarAccelerometerData;
import com.polar.sdk.api.model.PolarDeviceInfo;
import com.polar.sdk.api.model.PolarEcgData;
import com.polar.sdk.api.model.PolarExerciseData;
import com.polar.sdk.api.model.PolarExerciseEntry;
import com.polar.sdk.api.model.PolarHrData;
import com.polar.sdk.api.model.PolarSensorSetting;

import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import androidx.annotation.Nullable;
import androidx.core.util.Pair;

import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers;
import io.reactivex.rxjava3.disposables.Disposable;
import io.reactivex.rxjava3.functions.Action;
import io.reactivex.rxjava3.functions.Consumer;
import io.reactivex.rxjava3.functions.Function;
import org.reactivestreams.Publisher;
import org.reactivestreams.Subscriber;

enum PolarEvent {
    DEVICE_FOUND,
    DEVICE_CONNECTING,
    DEVICE_CONNECTED,
    DEVICE_DISCONNECTED,
    BATTERY_LEVEL_RECEIVED,
    DIS_INFORMATION_RECEIVED,
    BLE_POWER_ON,
    BLE_POWER_OFF,
    ECG_FEATURE_READY,
    HR_FEATURE_READY,
    FTP_FEATURE_READY,
    ACC_FEATURE_READY,
    STREAMING_FEATURES_READY,
    OHR_PPG_FEATURE_READY,
    OHR_PPI_FEATURE_READY,
    HR_VALUE_RECEIVED,
    HR_DATA,
    ECG_DATA,
    ACC_DATA,
    PPG_DATA,
    PPI_DATA,
    RECORD_STATUS,
    EXERCISE_ENTRY,
    READ_EXERCISE
}

public class RnPolarBleModule extends ReactContextBaseJavaModule implements LifecycleEventListener {
  public static final String NAME = "RnPolarBle";
  public static final String TAG = "RnPolarBle";

  private final ReactApplicationContext reactContext;
  private ReactApplicationContext ctx;
  public PolarBleApi api;

  private Disposable searchDisposable = null;
  private Disposable hrDisposable = null;
  private Disposable ecgDisposable = null;
  private Disposable accDisposable = null;
  private Disposable ppgDisposable = null;
  private Disposable ppiDisposable = null;
  private Disposable recordingStatusReadDisposable = null;
  private Disposable recordingStartStopDisposable = null;
  private Disposable fetchExerciseDisposable = null;
  private Disposable removeExerciseDisposable = null;
  private Disposable listExercisesDisposable = null;
  private List<PolarExerciseEntry> exerciseEntries = new ArrayList<>();

  private Boolean hrReady = false;
  private Boolean ecgReady = false;
  private Boolean accReady = false;
  private Boolean ppgReady = false;
  private Boolean ppiReady = false;

  public RnPolarBleModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.reactContext = reactContext;
        ctx = reactContext;

        api = PolarBleApiDefaultImpl.defaultImplementation(reactContext,
                EnumSet.of(PolarBleApi.PolarBleSdkFeature.FEATURE_HR ,
                        PolarBleApi.PolarBleSdkFeature.FEATURE_POLAR_SDK_MODE ,
                        PolarBleApi.PolarBleSdkFeature.FEATURE_BATTERY_INFO ,
                        PolarBleApi.PolarBleSdkFeature.FEATURE_POLAR_H10_EXERCISE_RECORDING ,
                        PolarBleApi.PolarBleSdkFeature.FEATURE_POLAR_OFFLINE_RECORDING ,
                        PolarBleApi.PolarBleSdkFeature.FEATURE_POLAR_ONLINE_STREAMING ,
                        PolarBleApi.PolarBleSdkFeature.FEATURE_POLAR_DEVICE_TIME_SETUP ,
                        PolarBleApi.PolarBleSdkFeature.FEATURE_DEVICE_INFO));

        api.setApiCallback(new PolarBleApiCallback() {
            @Override
            public void batteryLevelReceived(@NonNull String identifier, int level) {
                super.batteryLevelReceived(identifier, level);
                WritableMap params = Arguments.createMap();
                params.putString("id", identifier);
                params.putInt("value", level);

                sendEvent(ctx, PolarEvent.BATTERY_LEVEL_RECEIVED.name(), params);
            }

            @Override
            public void blePowerStateChanged(boolean powered) {
                super.blePowerStateChanged(powered);
                if (powered) {
                    sendEvent(ctx, PolarEvent.BLE_POWER_ON.name());
                } else {
                    sendEvent(ctx, PolarEvent.BLE_POWER_OFF.name());
                }
            }

            @Override
            public void bleSdkFeatureReady(@NonNull String identifier, @NonNull PolarBleApi.PolarBleSdkFeature feature) {
                super.bleSdkFeatureReady(identifier, feature);
                Log.d(TAG, "bleSdkFeatureReady: " + feature);
                switch (feature) {
                    case FEATURE_HR:
                        hrReady = true;
                        sendEvent(ctx, PolarEvent.HR_FEATURE_READY.name(), identifier);
                        break;
                    case  FEATURE_BATTERY_INFO:
                        break;
                    case FEATURE_DEVICE_INFO:
                        break;
                    case FEATURE_POLAR_H10_EXERCISE_RECORDING:
                        break;
                    case FEATURE_POLAR_OFFLINE_RECORDING:
                        break;
                    case FEATURE_POLAR_DEVICE_TIME_SETUP:
                        break;
                    case FEATURE_POLAR_SDK_MODE:
                        break;
                    case FEATURE_POLAR_ONLINE_STREAMING:
                        api.getAvailableOnlineStreamDataTypes(identifier)
                                .observeOn(AndroidSchedulers.mainThread())
                                .subscribe(new Consumer<Set<PolarBleApi.PolarDeviceDataType>>() {
                                    @Override
                                    public void accept(Set<PolarBleApi.PolarDeviceDataType> polarDeviceDataTypes) throws Throwable {
                                        Log.e(TAG, "Available online streaming data types:" + polarDeviceDataTypes);
                                        for (PolarBleApi.PolarDeviceDataType dataType : polarDeviceDataTypes) {
                                            switch (dataType) {
                                                case ECG:
                                                    sendEvent(ctx, PolarEvent.ECG_FEATURE_READY.name(), identifier);
                                                    ecgReady = true;
                                                    break;
                                                case HR:
                                                    sendEvent(ctx, PolarEvent.HR_FEATURE_READY.name(), identifier);
                                                    hrReady = true;
                                                    break;
                                                case ACC:
                                                    sendEvent(ctx, PolarEvent.ACC_FEATURE_READY.name(), identifier);
                                                    accReady = true;
                                                    break;
                                                case PPI:
                                                    sendEvent(ctx, PolarEvent.OHR_PPI_FEATURE_READY.name(), identifier);
                                                    ppiReady = true;
                                                    break;
                                                case PPG:
                                                    sendEvent(ctx, PolarEvent.OHR_PPG_FEATURE_READY.name(), identifier);
                                                    ppgReady = true;
                                                    break;
                                                default:
                                                    break;
                                            }
                                        }
                                    }
                                });
                        break;
                }
            }

            @Override
            public void deviceConnected(@NonNull PolarDeviceInfo polarDeviceInfo) {
                super.deviceConnected(polarDeviceInfo);
                sendEvent(ctx, PolarEvent.DEVICE_CONNECTED.name(), toJsDictionary(polarDeviceInfo));
            }

            @Override
            public void deviceConnecting(@NonNull PolarDeviceInfo polarDeviceInfo) {
                super.deviceConnecting(polarDeviceInfo);
                sendEvent(ctx, PolarEvent.DEVICE_CONNECTING.name(), toJsDictionary(polarDeviceInfo));
            }

            @Override
            public void deviceDisconnected(@NonNull PolarDeviceInfo polarDeviceInfo) {
                super.deviceDisconnected(polarDeviceInfo);
                sendEvent(ctx, PolarEvent.DEVICE_DISCONNECTED.name(), toJsDictionary(polarDeviceInfo));
            }

            @Override
            public void disInformationReceived(@NonNull String identifier, @NonNull UUID uuid, @NonNull String value) {
                super.disInformationReceived(identifier, uuid, value);
                WritableMap params = Arguments.createMap();
                params.putString("identifier", identifier);
                params.putString("uuid", uuid.toString());
                params.putString("value", value);
                sendEvent(ctx, PolarEvent.DIS_INFORMATION_RECEIVED.name(), params);
            }

        });
  }

  @Override
  @NonNull
  public String getName() {
    return NAME;
  }

  @Override
  public void onHostResume() {
      api.foregroundEntered();
  }

  @Override
  public void onHostPause() {
  }

  @Override
  public void onHostDestroy() {
      api.shutDown();
  }

  private WritableMap toJsDictionary(PolarDeviceInfo polarDeviceInfo) {
      WritableMap rawMap = new WritableNativeMap();
      rawMap.putString("deviceId", polarDeviceInfo.getDeviceId());
      rawMap.putString("address", polarDeviceInfo.getAddress());
      rawMap.putInt("rssi", polarDeviceInfo.getRssi());
      rawMap.putString("name", polarDeviceInfo.getName());
      rawMap.putBoolean("isConnectable", polarDeviceInfo.isConnectable());
      return rawMap;
  }

  private void sendEvent(ReactContext reactContext, String eventName, @Nullable WritableMap params) {
        if(!reactContext.hasActiveReactInstance()) {
            return;
        }
        reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit(eventName, params);
    }

    private void sendEvent(ReactContext reactContext, String eventName, String params) {
        if(!reactContext.hasActiveReactInstance()) {
            return;
        }
        reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit(eventName, params);
    }

    private void sendEvent(ReactContext reactContext, String eventName) {
        if(!reactContext.hasActiveReactInstance()) {
            return;
        }
        reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit(eventName, null);
    }



  @ReactMethod
  public void searchForDevice() {
      Log.e(TAG, "searchForDevice");
      if (searchDisposable != null) {
          searchDisposable.dispose();
      }
      searchDisposable = api.searchForDevice().subscribe( data -> {
          Log.e(TAG, "found result" + data.toString());
          sendEvent(ctx, PolarEvent.DEVICE_FOUND.name(), toJsDictionary(data));},
          throwable -> {
              Log.e(TAG,"" + throwable.getLocalizedMessage());
          });
  }

  @ReactMethod
  public void connectToDevice(String id) {
      try {
          api.connectToDevice(id);
      } catch (Exception e) {
          Log.e(TAG,"" + e.getLocalizedMessage());
      }
  }

  @ReactMethod
  public void disconnectFromDevice(String id) {
      try {
          api.disconnectFromDevice(id);
      } catch (Exception e) {
          Log.e(TAG,"" + e.getLocalizedMessage());
      }
  }

  @ReactMethod
  public void startAutoConnectToDevice(Integer rrsi) {

  }

  @ReactMethod
  public void startHrStreaming(String id) {
      if (hrReady && hrDisposable == null) {
          hrDisposable = api.startHrStreaming(id)
                  .observeOn(AndroidSchedulers.mainThread())
                  .subscribe(new Consumer<PolarHrData>() {
                      @Override
                      public void accept(PolarHrData polarHrData) throws Throwable {
                          WritableMap params = Arguments.createMap();
                          params.putString("id", id);
                          params.putInt("hr", polarHrData.getSamples().get(0).getHr());
                          WritableArray rrsMSList = Arguments.createArray();
                          for (Integer s : polarHrData.getSamples().get(0).getRrsMs()) {
                              rrsMSList.pushInt(s);
                          }
                          params.putArray("rrsMs", rrsMSList);
                          params.putBoolean("rrAvailable", polarHrData.getSamples().get(0).getRrAvailable());
                          params.putBoolean("contactStatus", polarHrData.getSamples().get(0).getContactStatus());
                          params.putBoolean("contactStatusSupported", polarHrData.getSamples().get(0).getContactStatusSupported());
                          sendEvent(ctx, PolarEvent.HR_DATA.name(), params);
                      }
                  });
      }
  }

  @ReactMethod
  public void stopHrStreaming(String id) {
      if (hrDisposable != null) {
          hrDisposable.dispose();
          hrDisposable = null;
      }
  }

  @ReactMethod
  public void startEcgStreaming(String id) {
      if (ecgReady && ecgDisposable == null) {
          ecgDisposable = api.requestStreamSettings(id, PolarBleApi.PolarDeviceDataType.ECG).toFlowable().flatMap(
                  new Function<PolarSensorSetting, Publisher<PolarEcgData>>() {
                      @Override
                      public Publisher<PolarEcgData> apply(PolarSensorSetting polarSensorSetting) throws Throwable {
                          return api.startEcgStreaming(id, polarSensorSetting.maxSettings());
                      }
                  }
          )
          .observeOn(AndroidSchedulers.mainThread()).subscribe(
                          new Consumer<PolarEcgData>() {
                              @Override
                              public void accept(PolarEcgData polarEcgData) throws Throwable {
                                  WritableMap params = Arguments.createMap();
                                  WritableArray samples = Arguments.createArray();
                                  for (PolarEcgData.PolarEcgDataSample s : polarEcgData.getSamples()) {
                                      WritableMap params1 = Arguments.createMap();
                                      params1.putDouble("timeStamp", s.getTimeStamp());
                                      params1.putInt("voltage", s.getVoltage());
                                      samples.pushMap(params1);
                                  }
                                  params.putString("id", id);
                                  params.putArray("samples", samples);
                                  sendEvent(ctx, PolarEvent.ECG_DATA.name(), params);
                              }
                          }
                  );
      }
  }

  @ReactMethod
  public void stopEcgStreaming(String id) {
      if (ecgDisposable != null) {
          ecgDisposable.dispose();
          ecgDisposable = null;
      }
  }

  @ReactMethod
  public void startAccStreaming(String id) {
      if (accReady && accDisposable == null) {
          accDisposable = api.requestStreamSettings(id, PolarBleApi.PolarDeviceDataType.ACC).toFlowable().flatMap(
                  new Function<PolarSensorSetting, Publisher<PolarAccelerometerData>>() {
                      @Override
                      public Publisher<PolarAccelerometerData> apply(PolarSensorSetting polarSensorSetting) throws Throwable {
                          return api.startAccStreaming(id, polarSensorSetting.maxSettings());
                      }
                  }
          )
                  .observeOn(AndroidSchedulers.mainThread())
                  .subscribe(new Consumer<PolarAccelerometerData>() {
                      @Override
                      public void accept(PolarAccelerometerData polarAccelerometerData) throws Throwable {
                          WritableMap params = Arguments.createMap();
                          WritableArray samples = Arguments.createArray();
                          for (PolarAccelerometerData.PolarAccelerometerDataSample s : polarAccelerometerData.getSamples()) {
                              WritableMap params1 = Arguments.createMap();
                              params1.putDouble("timeStamp", s.getTimeStamp());
                              params1.putInt("x", s.getX());
                              params1.putInt("y", s.getY());
                              params1.putInt("y", s.getZ());
                              samples.pushMap(params1);
                          }
                          params.putString("id", id);
                          params.putArray("samples", samples);
                          sendEvent(ctx, PolarEvent.ACC_DATA.name(), params);
                      }
                  });
      }
  }

  @ReactMethod
  public void stopAccStreaming(String id) {
      if (accDisposable != null) {
          accDisposable.dispose();
          accDisposable = null;
      }
  }

  @ReactMethod
  public void startPpgStreaming(String id) {

  }

  @ReactMethod
  public void stopPpgStreaming(String id) {

  }

  @ReactMethod
  public void startPpiStreaming(String id) {

  }

  @ReactMethod
  public void stopPpiStreaming(String id) {

  }

  @ReactMethod
  public void getH10RecordingStatus(String id) {
      recordingStatusReadDisposable = api.requestRecordingStatus(id)
              .observeOn(AndroidSchedulers.mainThread())
              .subscribe(new Consumer<Pair<Boolean, String>>() {
                  @Override
                  public void accept(Pair<Boolean, String> booleanStringPair) throws Throwable {
                      WritableMap params = Arguments.createMap();
                      params.putBoolean("ongoing", booleanStringPair.first);
                      params.putString("entryId", booleanStringPair.second);
                      sendEvent(ctx, PolarEvent.RECORD_STATUS.name(), params);
                  }
              });
  }

  @ReactMethod
  public void startH10Recording(String id, String exerciseId, String sampleType) {
      PolarH10OfflineExerciseApi.SampleType sample;
      if (sampleType.equals("hr")) {
        sample = PolarH10OfflineExerciseApi.SampleType.HR;
      } else {
        sample = PolarH10OfflineExerciseApi.SampleType.RR;
      }
      recordingStartStopDisposable = api.startRecording(id, exerciseId, PolarH10OfflineExerciseApi.RecordingInterval.INTERVAL_1S, sample)
              .observeOn(AndroidSchedulers.mainThread())
              .subscribe(() -> {}, error -> {
                  Log.e(TAG, "startH10Recording error");
              });
  }

  @ReactMethod
  public void stopH10Recording(String id) {
      recordingStartStopDisposable = api.stopRecording(id)
              .observeOn(AndroidSchedulers.mainThread())
              .subscribe(() -> {}, error -> {
                  Log.e(TAG, "stopH10Recording error");
              });
  }

  @ReactMethod
  public void listExercises(String id) {
      exerciseEntries.clear();
      listExercisesDisposable = api.listExercises(id)
              .observeOn(AndroidSchedulers.mainThread())
              .subscribe(
                      new Consumer<PolarExerciseEntry>() {
                          @Override
                          public void accept(PolarExerciseEntry polarExerciseEntry) throws Throwable {
                              exerciseEntries.add(polarExerciseEntry);
                              WritableMap params = Arguments.createMap();
                              params.putString("id", polarExerciseEntry.getIdentifier());
                              params.putString("path", polarExerciseEntry.getPath());
                              params.putString("date", polarExerciseEntry.getDate().toString());
                              sendEvent(ctx, PolarEvent.EXERCISE_ENTRY.name(), params);
                          }
                      }
              );

  }

  @ReactMethod
  public void readExercise(String id) {
      if (!exerciseEntries.isEmpty()) {
          fetchExerciseDisposable = api.fetchExercise(id, exerciseEntries.get(0))
                  .observeOn(AndroidSchedulers.mainThread())
                  .subscribe(new Consumer<PolarExerciseData>() {
                      @Override
                      public void accept(PolarExerciseData polarExerciseData) throws Throwable {
                          WritableMap params = Arguments.createMap();
                          WritableArray samples = Arguments.createArray();
                          params.putInt("interval", polarExerciseData.getRecordingInterval());
                          for (Integer s : polarExerciseData.getHrSamples()) {
                              samples.pushInt(s);
                          }
                          params.putArray("samples", samples);
                          sendEvent(ctx, PolarEvent.READ_EXERCISE.name(), params);
                      }
                  });
      }
  }

  @ReactMethod
  public void removeExercise(String id) {
      if (exerciseEntries.isEmpty()) {
          Log.d(TAG, "No exercise to read, please list the exercises first");
          return;
      }

      removeExerciseDisposable = api.removeExercise(id, exerciseEntries.get(0))
              .observeOn(AndroidSchedulers.mainThread())
              .subscribe(new Action() {
                  @Override
                  public void run() throws Throwable {
                      exerciseEntries.remove(exerciseEntries.get(0));
                  }
              });
  }



}
