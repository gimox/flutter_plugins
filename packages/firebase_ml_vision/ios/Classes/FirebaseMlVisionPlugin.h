#import <Flutter/Flutter.h>

#import "Firebase/Firebase.h"

@interface FLTFirebaseMlVisionPlugin : NSObject <FlutterPlugin>
+ (void)handleError:(NSError *)error result:(FlutterResult)result;
@end

@protocol Detector
@required
+ (void)handleDetection:(FIRVisionImage *)image
                options:(NSDictionary *)options
                 result:(FlutterResult)result;
@optional
@end

@protocol CustomModel
@required
+ (void)registerCloudModelSource:(NSDictionary *)options;
+ (void)run:(NSString *)cloudModelName
       options:(NSDictionary *)options
    inputBytes:(FlutterStandardTypedData *)inputBytes
        result:(FlutterResult)result;
@optional
@end

@interface BarcodeDetector : NSObject <Detector>
@end

@interface FaceDetector : NSObject <Detector>
@end

@interface LabelDetector : NSObject <Detector>
@end

@interface CloudLabelDetector : NSObject <Detector>
@end

@interface TextRecognizer : NSObject <Detector>
@end

@interface CustomModel : NSObject <CustomModel>
@end
