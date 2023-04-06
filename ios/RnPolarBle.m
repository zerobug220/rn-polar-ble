#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(RnPolarBle, RCTEventEmitter)

RCT_EXTERN_METHOD(supportedEvents)
RCT_EXTERN_METHOD(searchForDevice)
RCT_EXTERN_METHOD(connectToDevice:(NSString *)deviceId)
RCT_EXTERN_METHOD(disconnectFromDevice:(NSString *)deviceId)
RCT_EXTERN_METHOD(startAutoConnectToDevice:(NSInteger)rrsi)
RCT_EXTERN_METHOD(startHrStreaming:(NSString *)deviceId)
RCT_EXTERN_METHOD(stopHrStreaming:(NSString *)deviceId)
RCT_EXTERN_METHOD(startEcgStreaming:(NSString *)deviceId)
RCT_EXTERN_METHOD(stopEcgStreaming:(NSString *)deviceId)
RCT_EXTERN_METHOD(startAccStreaming:(NSString *)deviceId)
RCT_EXTERN_METHOD(stopAccStreaming:(NSString *)deviceId)
RCT_EXTERN_METHOD(startPpgStreaming:(NSString *)deviceId)
RCT_EXTERN_METHOD(stopPpgStreaming:(NSString *)deviceId)
RCT_EXTERN_METHOD(startPpiStreaming:(NSString *)deviceId)
RCT_EXTERN_METHOD(stopPpiStreaming:(NSString *)deviceId)
RCT_EXTERN_METHOD(getH10RecordingStatus:(NSString *)deviceId)
RCT_EXTERN_METHOD(startH10Recording:(NSString *)deviceId exerciseId:(NSString *)exerciseId sampleType:(NSString *)sampleType)
RCT_EXTERN_METHOD(stopH10Recording:(NSString *)deviceId)
RCT_EXTERN_METHOD(listExercises:(NSString *)deviceId)
RCT_EXTERN_METHOD(readExercise:(NSString *)deviceId)
RCT_EXTERN_METHOD(removeExercise:(NSString *)deviceId)

@end
