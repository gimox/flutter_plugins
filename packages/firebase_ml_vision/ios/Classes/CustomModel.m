#import "FirebaseMlVisionPlugin.h"

@implementation CustomModel

+ (void)registerCloudModelSource:(NSDictionary *)options {
  NSLog(@"registerCloudModelSource called");

  if (options == (NSDictionary *)[NSNull null]) {
    NSLog(@"customModel options are empty!");
    return;
  }

  NSString *modelName = options[@"modelName"];
  BOOL enableModelUpdates = options[@"enableModelUpdates"];

  FIRModelDownloadConditions *initialDownloadConditions =
      [[FIRModelDownloadConditions alloc] initWithIsWiFiRequired:YES canDownloadInBackground:YES];
  FIRModelDownloadConditions *updatesDownloadConditions =
      [[FIRModelDownloadConditions alloc] initWithIsWiFiRequired:YES canDownloadInBackground:YES];

  if (options[@"initialDownloadConditions"] != [NSNull null]) {
    BOOL requireWifi = options[@"initialDownloadConditions"][@"requireWifi"];
    BOOL requireDeviceIdle = options[@"initialDownloadConditions"][@"requireDeviceIdle"];
    initialDownloadConditions =
        [[FIRModelDownloadConditions alloc] initWithIsWiFiRequired:requireWifi
                                           canDownloadInBackground:requireDeviceIdle];
  }
  if (options[@"updatesDownloadConditions"] != [NSNull null]) {
    BOOL requireWifi = options[@"initialDownloadConditions"][@"requireWifi"];
    BOOL requireDeviceIdle = options[@"initialDownloadConditions"][@"requireDeviceIdle"];
    initialDownloadConditions = updatesDownloadConditions =
        [[FIRModelDownloadConditions alloc] initWithIsWiFiRequired:requireWifi
                                           canDownloadInBackground:requireDeviceIdle];
  }

  FIRCloudModelSource *cloudModelSource =
      [[FIRCloudModelSource alloc] initWithModelName:modelName
                                  enableModelUpdates:enableModelUpdates
                                   initialConditions:initialDownloadConditions
                                    updateConditions:updatesDownloadConditions];
  BOOL registrationSuccess =
      [[FIRModelManager modelManager] registerCloudModelSource:cloudModelSource];
}

+ (void)run:(NSString *)cloudModelName
       options:(NSDictionary *)options
    inputBytes:(FlutterStandardTypedData *)inputBytes
        result:(FlutterResult)result {
  // TODO local model
  FIRModelOptions *optionsInOut = [[FIRModelOptions alloc] initWithCloudModelName:cloudModelName
                                                                   localModelName:nil];
  FIRModelInterpreter *interpreter = [FIRModelInterpreter modelInterpreterWithOptions:optionsInOut];

  FIRModelInputOutputOptions *ioOptions = [[FIRModelInputOutputOptions alloc] init];
  NSError *error;
  NSNumber *inputIndex = options[@"inputIndex"];
  NSNumber *inputDataType = options[@"inputDataType"];
  FIRModelElementType inputType = (FIRModelElementType)[inputDataType intValue];
  NSArray<NSNumber *> *inputDims = options[@"inputDims"];
  [ioOptions setInputFormatForIndex:[inputIndex unsignedIntegerValue]
                               type:inputType
                         dimensions:inputDims
                              error:&error];

  if (error != nil) {
    NSLog(@"Failed setInputFormatForIndex with error: %@", error.localizedDescription);
    return;
  }

  NSNumber *outputIndex = options[@"outputIndex"];
  NSNumber *outputDataType = options[@"outputDataType"];
  FIRModelElementType outputType = (FIRModelElementType)[outputDataType intValue];
  NSArray<NSNumber *> *outputDims = options[@"outputDims"];
  [ioOptions setOutputFormatForIndex:[outputIndex unsignedIntegerValue]
                                type:outputType
                          dimensions:outputDims
                               error:&error];

  NSLog(@"*******4");
  if (error != nil) {
    NSLog(@"Failed setOutputFormatForIndex with error: %@", error.localizedDescription);
    return;
  }

  FIRModelInputs *inputs = [[FIRModelInputs alloc] init];

  // ...
  [inputs addInput:inputBytes.data error:&error];  // Repeat as necessary.
  if (error != nil) {
    NSLog(@"Failed addInput with error: %@", error);
    return;
  }

  [interpreter
      runWithInputs:inputs
            options:ioOptions
         completion:^(FIRModelOutputs *_Nullable outputs, NSError *_Nullable error) {
           if (error != nil || outputs == nil) {
             NSLog(@"Failed runWithInputs with error: %@", error.localizedDescription);
             return;
           }

           NSArray<NSArray<NSNumber *> *> *outputArrayOfArrays = [outputs outputAtIndex:0
                                                                                  error:&error];
           if (error) {
             NSLog(@"Failed to process detection outputs with error: %@",
                   error.localizedDescription);
             return;
           }

           // Get the first output from the array of output arrays.
           if (!outputArrayOfArrays || !outputArrayOfArrays.firstObject ||
               ![outputArrayOfArrays.firstObject isKindOfClass:[NSArray class]] ||
               !outputArrayOfArrays.firstObject.firstObject ||
               ![outputArrayOfArrays.firstObject.firstObject isKindOfClass:[NSNumber class]]) {
             NSLog(@"Failed to get the results array from output.");
             return;
           }

           NSArray<NSNumber *> *ret = outputArrayOfArrays.firstObject;
           result(ret);
           return;
         }];
}

@end
