import Foundation
import PolarBleSdk
import RxSwift
import CoreBluetooth

enum PolarEvent: String, CaseIterable {
    case DEVICE_FOUND
    case DEVICE_CONNECTING
    case DEVICE_CONNECTED
    case DEVICE_DISCONNECTED
    case BATTERY_LEVEL_RECEIVED
    case DIS_INFORMATION_RECEIVED
    case BLE_POWER_ON
    case BLE_POWER_OFF
    case ECG_FEATURE_READY
    case HR_FEATURE_READY
    case FTP_FEATURE_READY
    case ACC_FEATURE_READY
    case STREAMING_FEATURES_READY
    case OHR_PPG_FEATURE_READY
    case OHR_PPI_FEATURE_READY
    case HR_VALUE_RECEIVED
    case HR_DATA
    case ECG_DATA
    case ACC_DATA
    case PPG_DATA
    case PPI_DATA
    case RECORD_STATUS
    case EXERCISE_ENTRY
    case READ_EXERCISE
}

enum PolarBleError: Error {
    case unconfigured
}

@objc(RnPolarBle)
class RnPolarBle: RCTEventEmitter,
                         PolarBleApiObserver,
                         PolarBleApiPowerStateObserver,
                         PolarBleApiDeviceInfoObserver,
                         PolarBleApiDeviceFeaturesObserver,
                         PolarBleApiLogger {
 
  
  public static var emitter : RCTEventEmitter!
  private var api: PolarBleApi = PolarBleApiDefaultImpl.polarImplementation(
      DispatchQueue.main,
      features: [PolarBleSdkFeature.feature_hr,
                           PolarBleSdkFeature.feature_polar_sdk_mode,
                           PolarBleSdkFeature.feature_battery_info,
                           PolarBleSdkFeature.feature_device_info,
                           PolarBleSdkFeature.feature_polar_online_streaming,
                           PolarBleSdkFeature.feature_polar_offline_recording,
                           PolarBleSdkFeature.feature_polar_device_time_setup,
                           PolarBleSdkFeature.feature_polar_h10_exercise_recording]
    );
  private var searchDisposable: Disposable?
  private var autoConnectDisposable: Disposable?
  private var hrDisposable: Disposable?
  private var ecgDisposable: Disposable?
  private var accDisposable: Disposable?
  private var ppgDisposable: Disposable?
  private var ppiDisposable: Disposable?
  private let disposeBag = DisposeBag()
  private var hrReady: Bool = false
  private var ecgReady: Bool = false
  private var accReady: Bool = false
  private var ppgReady: Bool = false
  private var ppiReady: Bool = false
  
  private(set) var isH10RecordingSupported: Bool = false
  private(set) var isExerciseFetchInProgress: Bool = false
  private var exerciseEntry: PolarExerciseEntry?
  
  override init() {
      super.init()
      RnPolarBle.emitter = self
    
      api.polarFilter(true)
      api.observer = self
      api.powerStateObserver = self
      api.deviceInfoObserver = self
      api.deviceFeaturesObserver = self
      api.logger = self
  }
  
  private func toJsDictionary(from deviceInfo: PolarDeviceInfo) -> [String: Any] {
      return [
          "deviceId": deviceInfo.deviceId,
          "address": deviceInfo.address.uuidString,
          "rssi": deviceInfo.rssi,
          "name": deviceInfo.name,
          "connectable": deviceInfo.connectable,
      ]
  }
  
  @objc override func supportedEvents() -> [String]! {
       return PolarEvent.allCases.map { $0.rawValue }
  }
  
  @objc override func sendEvent(withName name: String!, body: Any!) {
      super.sendEvent(withName: name, body: body)
  }
    
  @objc override static func requiresMainQueueSetup() -> Bool {
    return false
  }
  
  @objc func searchForDevice() -> Void {
    searchDisposable?.dispose()
    searchDisposable = api.searchForDevice()
      .subscribe{ e in
        switch e {
          case .completed:
            NSLog("search completed")
          case .error(let err):
            NSLog("search error: \(err)")
          case .next(let deviceInfo):
            NSLog("polar device found: \(deviceInfo.name) connectable: \(deviceInfo.connectable) address: \(deviceInfo.address.uuidString)")
          self.sendEvent(withName: PolarEvent.DEVICE_FOUND.rawValue, body: self.toJsDictionary(from: deviceInfo))
        }
      }
  }
  
  @objc func connectToDevice(_ id: String) -> Void {
    do {
      try self.api.connectToDevice(id)
    } catch let err {
      NSLog("Failed to connect to \(id). Reason \(err)")
    }
  }

  @objc func disconnectFromDevice(_ id: String) -> Void {
    do {
      try self.api.disconnectFromDevice(id)
    } catch let err {
      NSLog("Failed to disconnect from \(id). Reason \(err)")
    }
  }

  @objc func startAutoConnectToDevice(_ rssi: Int) -> Void {
      autoConnectDisposable?.dispose()
    autoConnectDisposable = api.startAutoConnectToDevice(rssi, service: nil, polarDeviceType: "H10")
        .subscribe { e in
          switch e {
            case .completed:
              NSLog("auto connect search complete")
            case .error(let err):
              NSLog("auto connect failed: \(err)")
          }
        }
  }
  
  @objc func startHrStreaming(_ id: String) -> Void {
    if hrReady && hrDisposable == nil {
      hrDisposable = api.startHrStreaming(id)
        .observe(on: MainScheduler.instance).subscribe{ e in
        switch e {
        case .next(let data):
          let result: NSMutableDictionary = [:]
          result["id"] = id
          result["hr"] = data[0].hr
          result["rrsMs"] = data[0].rrsMs
          result["rrAvailable"] = data[0].rrAvailable
          result["contactStatus"] = data[0].contactStatus
          result["contactStatusSupported"] = data[0].contactStatusSupported
          self.sendEvent(withName: PolarEvent.HR_DATA.rawValue, body: result)
        case .error(let err):
          NSLog("Hr stream failed: \(err)")
          self.ecgDisposable = nil
        case .completed:
          NSLog("Hr stream completed")
        }
      }
    }
  }

  @objc func stopHrStreaming(_ id: String) -> Void {
    if (hrReady && hrDisposable != nil) {
      hrDisposable?.dispose()
      hrDisposable = nil
    }
  }

  @objc func startEcgStreaming(_ id: String) -> Void {
    if ecgReady && ecgDisposable == nil {
      ecgDisposable = api.requestStreamSettings(id, feature: .ecg).asObservable().flatMap({
        (settings) -> Observable<PolarEcgData> in
        return self.api.startEcgStreaming(id, settings: settings.maxSettings())
      }).observe(on: MainScheduler.instance).subscribe{ e in
        switch e {
        case .next(let data):
          let result: NSMutableDictionary = [:]
          result["id"] = id
          let samples: NSMutableArray = []
          for item in data.samples {
            let vec: NSMutableDictionary = [:]
            vec["voltage"] = item.voltage
            vec["timeStamp"] = item.timeStamp
            samples.add(vec)
          }
          result["samples"] = samples
          self.sendEvent(withName: PolarEvent.ECG_DATA.rawValue, body: result)
        case .error(let err):
          NSLog("ECG stream failed: \(err)")
          self.ecgDisposable = nil
        case .completed:
          NSLog("ECG stream completed")
        }
      }
    }
  }

  @objc func stopEcgStreaming(_ id: String) -> Void {
    if (ecgReady && ecgDisposable != nil) {
      ecgDisposable?.dispose()
      ecgDisposable = nil
    }
  }

  @objc func startAccStreaming(_ id: String) -> Void {
    if accReady && accDisposable == nil {
      accDisposable = api.requestStreamSettings(id, feature: .acc).asObservable().flatMap({
        (settings) -> Observable<PolarAccData> in
        return self.api.startAccStreaming(id, settings: settings.maxSettings())
      }).observe(on: MainScheduler.instance).subscribe{ e in
        switch e {
        case .next(let data):
          let result: NSMutableDictionary = [:]
          result["id"] = id
          let samples: NSMutableArray = []
          for item in data.samples {
            let vec: NSMutableDictionary = [:]
            vec["x"] = item.x
            vec["y"] = item.y
            vec["z"] = item.z
            vec["timeStamp"] = item.timeStamp
            samples.add(vec)
          }
          result["samples"] = samples
          self.sendEvent(withName: PolarEvent.ACC_DATA.rawValue, body: result)
        case .error(let err):
          NSLog("ACC stream failed: \(err)")
          self.accDisposable = nil
        case .completed:
          NSLog("ACC stream completed")
        }
      }
    }
  }

  @objc func stopAccStreaming(_ id: String) -> Void {
    if (accReady && accDisposable != nil) {
      accDisposable?.dispose()
      accDisposable = nil
    }
  }

  @objc func startPpgStreaming(_ id: String) -> Void {
    if ppgReady && ppgDisposable == nil {
      ppgDisposable = api.requestStreamSettings(id, feature: .ppg).asObservable().flatMap({
        (settings) -> Observable<PolarPpgData> in
        return self.api.startPpgStreaming(id, settings: settings.maxSettings())
      }).observe(on: MainScheduler.instance).subscribe{ e in
        switch e {
        case .next(let data):
          let result: NSMutableDictionary = [:]
          result["id"] = id
          let samples: NSMutableArray = []
          for item in data.samples {
            let ppg: NSMutableDictionary = [:]
            ppg["ppg0"] = item.channelSamples[0]
            ppg["ppg1"] = item.channelSamples[1]
            ppg["ppg2"] = item.channelSamples[2]
            ppg["ambient"] = item.channelSamples[3]
            samples.add(ppg)
          }
          result["samples"] = samples
          self.sendEvent(withName: PolarEvent.PPG_DATA.rawValue, body: result)
        case .error(let err):
          NSLog("PPG stream failed: \(err)")
          self.ppgDisposable = nil
        case .completed:
          NSLog("PPG stream completed")
        }
      }
    }
  }

  @objc func stopPpgStreaming(_ id: String) -> Void {
    if (ppgReady && ppgDisposable != nil) {
      ppgDisposable?.dispose()
      ppgDisposable = nil
    }
  }

  @objc func startPpiStreaming(_ id: String) -> Void {
    if ppiReady && ppiDisposable == nil {
      ppiDisposable = api.startPpiStreaming(id).observe(on: MainScheduler.instance).subscribe{ e in
        switch e {
        case .next(let data):
          let result: NSMutableDictionary = [:]
          result["id"] = id
          result["timeStamp"] = data.timeStamp
          let samples: NSMutableArray = []
          for item in data.samples {
            samples.add(item)
          }
          result["samples"] = samples
          self.sendEvent(withName: PolarEvent.PPI_DATA.rawValue, body: result)
        case .error(let err):
          NSLog("PPI stream failed: \(err)")
          self.ppiDisposable = nil
        case .completed:
          NSLog("PPI stream completed")
        }
      }
    }
  }

  @objc func stopPpiStreaming(_ id: String) -> Void {
    if (ppiReady && ppiDisposable != nil) {
      ppiDisposable?.dispose()
      ppiDisposable = nil
    }
  }
  
  @objc func getH10RecordingStatus(_ id: String) -> Void {
    api.requestRecordingStatus(id)
      .observe(on: MainScheduler.instance)
      .subscribe{ e in
        switch e {
        case .failure(let err):
          NSLog("recordingStatus failure: \(err)")
        case .success(let pair):
          var recordingStatus = "Recording on: \(pair)."
          NSLog(recordingStatus)
          let result: NSMutableDictionary = [:]
          result["ongoing"] = pair.ongoing
          result["entryId"] = pair.entryId
          self.sendEvent(withName: PolarEvent.RECORD_STATUS.rawValue, body: result)
        }
      }.disposed(by: disposeBag)
  }
  
    @objc func startH10Recording(_ id: String, exerciseId: String, sampleType: String) -> Void {
        var sample = SampleType.rr
        if (sampleType == "hr") {
            sample = SampleType.hr
        }
        api.startRecording(id, exerciseId: exerciseId, interval: .interval_1s, sampleType: sample)
          .observe(on: MainScheduler.instance)
          .subscribe { e in
            switch e {
            case .completed:
              NSLog("recording started")
            case .error(let err):
              NSLog("recording start fail: \(err)")
            }
          }.disposed(by: disposeBag)
  }
  
  @objc func stopH10Recording(_ id: String) -> Void {
    api.stopRecording(id)
        .observe(on: MainScheduler.instance)
        .subscribe{ e in
            switch e {
            case .completed:
                NSLog("recording stopped")
            case .error(let err):
              NSLog("recording stop fail: \(err)")
            }
        }.disposed(by: disposeBag)
  }
  
  @objc func listExercises(_ id: String) -> Void {
    exerciseEntry = nil
    api.fetchStoredExerciseList(id)
        .observe(on: MainScheduler.instance)
        .subscribe{ e in
            switch e {
            case .completed:
                NSLog("list exercises completed")
            case .error(let err):
                NSLog("failed to list exercises: \(err)")
            case .next(let polarExerciseEntry):
                NSLog("entry: \(polarExerciseEntry.date.description) path: \(polarExerciseEntry.path) id: \(polarExerciseEntry.entryId)");
                let result: NSMutableDictionary = [:]
                result["id"] = polarExerciseEntry.entryId
                result["date"] = polarExerciseEntry.date.description
                result["path"] = polarExerciseEntry.path
                self.exerciseEntry = polarExerciseEntry
                self.sendEvent(withName: PolarEvent.EXERCISE_ENTRY.rawValue, body: result)
            }
        }.disposed(by: disposeBag)
  }
  
  @objc func readExercise(_ id: String) -> Void {
    guard let e = exerciseEntry else {
        NSLog("No exercise to read, please list the exercises first")
        return
    }
    if(!isExerciseFetchInProgress) {
      isExerciseFetchInProgress = true
      api.fetchExercise(id, entry: e)
          .observe(on: MainScheduler.instance)
          .do(onDispose: { self.isExerciseFetchInProgress = false})
          .subscribe{ e in
              switch e {
              case .failure(let err):
                  NSLog("failed to read exercises: \(err)")
              case .success(let data):
                NSLog("test: \(data)")
                  NSLog("exercise data count: \(data.samples.count) samples: \(data.samples)")
                  let result: NSMutableDictionary = [:]
                  result["interval"] = data.interval
                  result["samples"] = data.samples
                  self.sendEvent(withName: PolarEvent.READ_EXERCISE.rawValue, body: result)
              }
          }.disposed(by: disposeBag)
    }
  }
  
  @objc func removeExercise(_ id: String) -> Void {
    guard let entry = exerciseEntry else {
      NSLog("No exercise to read, please list the exercises first")
        return
    }
    api.removeExercise(id, entry: entry)
        .observe(on: MainScheduler.instance)
        .subscribe{ e in
            switch e {
            case .completed:
                self.exerciseEntry = nil
                NSLog("remove completed")
            case .error(let err):
                NSLog("failed to remove exercise: \(err)")
            }
        }.disposed(by: disposeBag)
  }
  
  // OVERRIDDEN CALLBACK METHODS FROM VARIOUS PARENT CLASSES

  // MARK: - PolarBleApiObserver
  func deviceConnecting(_ polarDeviceInfo: PolarDeviceInfo) {
    sendEvent(withName: PolarEvent.DEVICE_CONNECTING.rawValue, body: toJsDictionary(from: polarDeviceInfo))
  }
  
  func deviceConnected(_ polarDeviceInfo: PolarDeviceInfo) {
    sendEvent(withName: PolarEvent.DEVICE_CONNECTED.rawValue, body: toJsDictionary(from: polarDeviceInfo))
    if(polarDeviceInfo.name.contains("H10")){
      self.isH10RecordingSupported = true
      getH10RecordingStatus(polarDeviceInfo.deviceId)
    }
  }
  
  func deviceDisconnected(_ polarDeviceInfo: PolarDeviceInfo) {
    sendEvent(withName: PolarEvent.DEVICE_DISCONNECTED.rawValue, body: toJsDictionary(from: polarDeviceInfo))
    self.isH10RecordingSupported = false
  }
  
  // MARK: - PolarBleApiDeviceInfoObserver
  func batteryLevelReceived(_ id: String, batteryLevel: UInt) {
    sendEvent(withName: PolarEvent.BATTERY_LEVEL_RECEIVED.rawValue,
                body: ["identifier": id, "batteryLevel": Int(batteryLevel)])
  }
  
  func disInformationReceived(_ id: String, uuid: CBUUID, value: String) {
    sendEvent(withName: PolarEvent.DIS_INFORMATION_RECEIVED.rawValue,
                body: ["identifier": id, "uuid": uuid.uuidString, "value": value])
  }
  
  // MARK: - PolarBleApiDeviceFeaturesObserver
  func bleSdkFeatureReady(_ identifier: String, feature: PolarBleSdk.PolarBleSdkFeature) {
    NSLog("Feature is ready: \(feature)")
    switch(feature) {
        
    case .feature_hr:
        sendEvent(withName: PolarEvent.HR_FEATURE_READY.rawValue, body: identifier)
        break
        
    case .feature_battery_info:
        
        break
        
    case .feature_device_info:
        
        break
        
    case .feature_polar_h10_exercise_recording:
       
        break
        
    case .feature_polar_device_time_setup:
       
        break
        
    case  .feature_polar_sdk_mode:
        
        break
        
    case .feature_polar_online_streaming:
      api.getAvailableOnlineStreamDataTypes(identifier)
          .observe(on: MainScheduler.instance)
          .subscribe{ e in
              switch e {
              case .success(let availableOnlineDataTypes):
                NSLog("Available online streaming data types: \(availableOnlineDataTypes)")
               // self.sendEvent(withName: PolarEvent.STREAMING_FEATURES_READY.rawValue,
               //             body: ["identifier": identifier, "streamingFeatures": availableOnlineDataTypes])
                for dataType in availableOnlineDataTypes {
                  switch (dataType) {
                    case .ecg:
                      self.sendEvent(withName: PolarEvent.ECG_FEATURE_READY.rawValue, body: identifier)
                      self.ecgReady = true
                      break
                    case .hr:
                      self.sendEvent(withName: PolarEvent.HR_FEATURE_READY.rawValue, body: identifier)
                      self.hrReady = true
                      break
                    case .acc:
                      self.sendEvent(withName: PolarEvent.ACC_FEATURE_READY.rawValue, body: identifier)
                      self.accReady = true
                      break
                    case .ppi:
                      self.sendEvent(withName: PolarEvent.OHR_PPI_FEATURE_READY.rawValue, body: identifier)
                      self.ppiReady = true
                      break
                    case .gyro:
                      break
                    case .ppg:
                      self.sendEvent(withName: PolarEvent.OHR_PPG_FEATURE_READY.rawValue, body: identifier)
                      self.ppgReady = true
                      break
                    case .magnetometer:
                      break
                    }
                  }
              case .failure(let err):
                  NSLog("Failed to get available online streaming data types: \(err)")
              }
          }.disposed(by: disposeBag)
        break
        
    case .feature_polar_offline_recording:
       
        break
    }
  }
  // deprecated
  func hrFeatureReady(_ id: String) {
  //  sendEvent(withName: PolarEvent.HR_FEATURE_READY.rawValue, body: id)
  }
  // deprecated
  func ftpFeatureReady(_ identifier: String) {
  //  sendEvent(withName: PolarEvent.FTP_FEATURE_READY.rawValue, body: identifier)
  }
  // deprecated
  func streamingFeaturesReady(_ identifier: String, streamingFeatures: Set<PolarDeviceDataType>) {
        sendEvent(withName: PolarEvent.STREAMING_FEATURES_READY.rawValue,
                    body: ["identifier": identifier, "streamingFeatures": streamingFeatures])
  }

  
  // MARK: - PolarBleApiPowerStateObserver
  func blePowerOn() {
    // sendEvent(withName: PolarEvent.blePowerOn.rawValue, body: nil)
  }
  
  func blePowerOff() {
    // sendEvent(withName: PolarEvent.blePowerOff.rawValue, body: nil)
  }

  
  // MARK: - PolarBleApiLogger
  func message(_ str: String) {
  }
 
}
