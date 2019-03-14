// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of firebase_ml_vision;

class CustomModel {
  CustomModel._();

  Future<List<dynamic>> run(
      String cloudModelName,
      FirebaseModelInputOutputOptions options,
      dynamic image,
      int width,
      int height) async {
    try {
      final bool isFloat =
          options.inputDataType == FirebaseModelDataType.FLOAT32;

      //TODO image must be squared
      /// prepare image
      final FirebaseCustomModelPayload customModelPayload =
          await FirebaseCustomModelPayload(image, options.inputDims[1],
              isFloat: isFloat, width: width, height: height);
      final Uint8List imageBytes =
          ImageManipulationUtils().prepareAnalysis(customModelPayload);

      /// get results
      final dynamic results =
          await FirebaseVision.channel.invokeMethod<dynamic>(
        "CloudModel#run",
        <String, dynamic>{
          'cloudModelName': cloudModelName,
          'inputOutputOptions': options.asDictionary(),
          'inputBytes': imageBytes
        },
      );

      return results;
    } catch (e) {
      print("Error on FirebaseModelInterpreter#run : ${e.toString()}");
    }
    return null;
  }

  /// load model from FireBase cloud
  Future<void> registerCloudModelSource(
      FirebaseCloudModelSource cloudSource) async {
    try {
      await FirebaseVision.channel.invokeMethod<dynamic>(
          "CloudModel#registerCloudModelSource",
          <String, dynamic>{'options': cloudSource.asDictionary()});
    } catch (e) {
      print(
          "Error on FirebaseModelManager#registerCloudModelSource : ${e.toString()}");
    }
    return null;
  }

/*
  Future<void> registerLocalModelSource(String filepath) async {
    try {
      await FirebaseVision.channel.invokeMethod<dynamic>(
          "FirebaseModelManager#registerLocalModelSource", <String, dynamic>{
        'options': FirebaseLocalModelSource().asDictionary()
      });
    } catch (e) {
      print(
          "Error on FirebaseModelManager#registerLocalModelSource : ${e.toString()}");
    }
    return null;
  }
  */
}

// android
//   https://firebase.google.com/docs/reference/android/com/google/firebase/ml/custom/FirebaseModelInputOutputOptions.Builder
class FirebaseModelInputOutputOptions {
  const FirebaseModelInputOutputOptions(this.inputIndex, this.inputDataType,
      this.inputDims, this.outputIndex, this.outputDataType, this.outputDims);

  final int inputIndex;
  final FirebaseModelDataType inputDataType;
  final List<int> inputDims;
  final int outputIndex;
  final FirebaseModelDataType outputDataType;
  final List<int> outputDims;

  Map<String, dynamic> asDictionary() {
    return <String, dynamic>{
      "inputIndex": inputIndex,
      "inputDataType": inputDataType.value,
      "inputDims": inputDims,
      "outputIndex": outputIndex,
      "outputDataType": outputDataType.value,
      "outputDims": outputDims,
    };
  }
}

// android
//   https://firebase.google.com/docs/reference/android/com/google/firebase/ml/custom/FirebaseModelDataType.DataType
class FirebaseModelDataType {
  const FirebaseModelDataType._(this.value);

  final int value;

  static const FirebaseModelDataType FLOAT32 = FirebaseModelDataType._(1);
  static const FirebaseModelDataType INT32 = FirebaseModelDataType._(2);
  static const FirebaseModelDataType BYTE = FirebaseModelDataType._(3);
  static const FirebaseModelDataType LONG = FirebaseModelDataType._(4);
}

// android
//   https://firebase.google.com/docs/reference/android/com/google/firebase/ml/custom/model/FirebaseLocalModelSource
class FirebaseLocalModelSource {
  FirebaseLocalModelSource({
    this.modelName,
    this.filePath,
    this.assetFilePath,
  });

  final String modelName;
  final String filePath;
  final String assetFilePath;

  Map<String, dynamic> asDictionary() {
    return <String, dynamic>{
      "modelName": modelName,
      "filePath": filePath,
      "assetFilePath": assetFilePath
    };
  }
}

// android
//   https://firebase.google.com/docs/reference/android/com/google/firebase/ml/custom/model/FirebaseCloudModelSource
class FirebaseCloudModelSource {
  FirebaseCloudModelSource(
      {this.modelName,
      this.enableModelUpdates = false,
      this.initialDownloadConditions = _defaultCondition,
      this.updatesDownloadConditions = _defaultCondition});

  final String modelName;
  final bool enableModelUpdates;
  final FirebaseModelDownloadConditions initialDownloadConditions;
  final FirebaseModelDownloadConditions updatesDownloadConditions;

  static const FirebaseModelDownloadConditions _defaultCondition =
      FirebaseModelDownloadConditions();

  Map<String, dynamic> asDictionary() {
    return <String, dynamic>{
      "modelName": modelName,
      "enableModelUpdates": enableModelUpdates,
      "initialDownloadConditions": initialDownloadConditions.asDictionary(),
      "updatesDownloadConditions": updatesDownloadConditions.asDictionary(),
    };
  }
}

// android
//   https://firebase.google.com/docs/reference/android/com/google/firebase/ml/custom/model/FirebaseModelDownloadConditions
class FirebaseModelDownloadConditions {
  const FirebaseModelDownloadConditions(
      {this.requireCharging = false,
      this.requireDeviceIdle = false,
      this.requireWifi = false});

  final bool requireWifi;
  final bool requireDeviceIdle;
  final bool requireCharging;

  Map<String, dynamic> asDictionary() {
    return <String, dynamic>{
      "requireWifi": requireWifi,
      "requireDeviceIdle": requireDeviceIdle,
      "requireCharging": requireCharging
    };
  }
}

class FirebaseCustomModelPayload {
  FirebaseCustomModelPayload(this.image, this.desiredSize,
      {this.isFloat = false, this.width, this.height});

  final dynamic image;
  final int desiredSize; // square image (i.e. 224 stays for 224x224)
  final bool isFloat;
  final int width;
  final int height;
}

class ImageManipulationUtils {
  Future<Uint8List> prepareAnalysis(FirebaseCustomModelPayload payload) async {
    img.Image resized;

    // format conversion
    if (payload.image != null) {
      if (payload.image is img.Image) {
        resized = payload.image;
      } else if (payload.image is CameraImage) {
        if (payload.image.format.group == ImageFormatGroup.yuv420) {
          resized = await convertYUV420toImageColor(payload.image);
        } else if (payload.image.format.group == ImageFormatGroup.bgra8888) {
          resized = await convertBGRA8888toImageColor(payload.image);
        } else {
          print('Unknow camera format');
          throw Error();
        }
      }
    } else {
      throw Error();
    }

    if (resized.height != payload.desiredSize ||
        resized.width != payload.desiredSize)
      resized =
          img.copyResize(resized, payload.desiredSize, payload.desiredSize);

    return (payload.isFloat)
        ? imageToByteListFloat(resized, payload.desiredSize)
        : imageToByteList(resized, payload.desiredSize);
  }

  Future<img.Image> convertBGRA8888toImageColor(CameraImage cameraImage) async {
    try {
      debugPrint(
          "Processing image ABGR888 ${cameraImage.width} x ${cameraImage.height}...");

      var rawImgBytes = cameraImage.planes[0].bytes;
      debugPrint("Raw bytes length: ${rawImgBytes.length}");

      var convertedImg = img.Image(
          cameraImage.width, cameraImage.height); // Create Image buffer
      for (int x = 0; x < cameraImage.width; x++) {
        for (int y = 0; y < cameraImage.height; y++) {
          final int index = y * cameraImage.width + x;
          int b = ((rawImgBytes[index] >> 16) & 0xFF).clamp(0, 255);
          int g = ((rawImgBytes[index] >> 8) & 0xFF).clamp(0, 255);
          int r = (rawImgBytes[index] & 0xFF).clamp(0, 255);
          convertedImg.setPixelRGBA(x, y, r, g, b);
        }
      }
      debugPrint("Img format (RGB: 3, RGBA: 4): ${convertedImg.format}");
      return convertedImg;
    } catch (e) {
      print("ERROR:" + e.toString());
    }
    return null;
  }

  Future<img.Image> convertYUV420toImageColor(CameraImage cameraImage) async {
    try {
      final int uvRowStride = cameraImage.planes[1].bytesPerRow;
      final int uvPixelStride = cameraImage.planes[1].bytesPerPixel;
      debugPrint(
          "Processing image YUV420 ${cameraImage.width} x ${cameraImage.height}...");
      print("uvRowStride: " + uvRowStride.toString());
      print("uvPixelStride: " + uvPixelStride.toString());

      var convertedImg = img.Image(
          cameraImage.width, cameraImage.height); // Create Image buffer

      // Fill image buffer with plane[0] from YUV420_888
      for (int x = 0; x < cameraImage.width; x++) {
        for (int y = 0; y < cameraImage.height; y++) {
          final int uvIndex =
              uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
          final int index = y * cameraImage.width + x;

          final yp = cameraImage.planes[0].bytes[index];
          final up = cameraImage.planes[1].bytes[uvIndex];
          final vp = cameraImage.planes[2].bytes[uvIndex];
          // Calculate pixel color
          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
              .round()
              .clamp(0, 255);
          int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
          convertedImg.setPixelRGBA(x, y, r, g, b);
        }
      }
      return convertedImg;
    } catch (e) {
      print("ERROR:" + e.toString());
    }
    return null;
  }

  Uint8List imageToByteListFloat(img.Image image, int desideredSize) {
    const double MEAN = 127.5;
    const double STD = 127.5;

    final Float32List convertedBytes =
        Float32List(1 * desideredSize * desideredSize * 3);

    final Float32List buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (int i = 0; i < desideredSize; i++) {
      for (int j = 0; j < desideredSize; j++) {
        final int pixel = image.getPixel(i, j);

        final int red = (pixel) & 0xFF;
        buffer[pixelIndex] = (red - MEAN) / STD; //Blue
        pixelIndex += 1;

        final int green = (pixel >> 8) & 0xFF;
        buffer[pixelIndex] = (green - MEAN) / STD; //Green
        pixelIndex += 1;

        final int blue = (pixel >> 16) & 0xFF;
        buffer[pixelIndex] = ((blue) - MEAN) / STD; // Red
        pixelIndex += 1;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  Uint8List imageToByteList(img.Image image, int _inputSize) {
    final Uint8List convertedBytes = Uint8List(1 * _inputSize * _inputSize * 3);
    final ByteData buffer = ByteData.view(convertedBytes.buffer);

    int pixelIndex = 0;

    for (int i = 0; i < _inputSize; i++) {
      for (int j = 0; j < _inputSize; j++) {
        final int pixel = image.getPixel(i, j);
        buffer.setUint8(pixelIndex, (pixel >> 16) & 0xFF);
        pixelIndex++;
        buffer.setUint8(pixelIndex, (pixel >> 8) & 0xFF);
        pixelIndex++;
        buffer.setUint8(pixelIndex, (pixel) & 0xFF);
        pixelIndex++;
      }
    }
    return convertedBytes;
  }
}
