// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data' show ByteData, Int32List;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'message_codec.dart';
import 'platform_channel.dart';
import 'system_channels.dart';

class UnsupportedFeature extends Error implements UnsupportedError {
  UnsupportedFeature(this.message, [this.details]);

  final String message;

  final dynamic details;

  @override
  String toString() {
    return message != null
      ? '$runtimeType: $message'
      : '$runtimeType';
  }

  static const String kErrorCode = 'unsupported';
}

bool _convertToUnsupportedError(Object e) {
  final PlatformException error = e as PlatformException;
  throw UnsupportedFeature(error.message, error.details);
}

bool _ifUnsupported(Object e) {
  return e is PlatformException && e.code == UnsupportedFeature.kErrorCode;
}

/// Controls specific aspects of the mouse cursor subsystem.
///
/// This class is not typically used by widgets. To declare regions of mouse
/// cursor, see documentation of the [MouseCursor] class.
class MouseCursorController {
  // This class is not meant to be instatiated or extended; this constructor
  // prevents instantiation and extension.
  MouseCursorController._();

  static MethodChannel get _channel => SystemChannels.mouseCursor;

  /// Request the platform to change the cursor of `device` to the system mouse
  /// cursor specified by `shape`.
  ///
  /// All arguments are required, and must not be null.
  ///
  /// {@template flutter.mouseCursorController.unsupportedFeature}
  /// The returned future completes with an [UnsupportedFeature] if the platform
  /// supports mouse cursor, but doesn't support the feature requested in this
  /// call, thus requesting fallback. It might also completes with other
  /// platform errors if any occurs.
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///  * [SystemMouseCursor], which explains system mouse cursors and shapes.
  ///  * [StandardMouseCursorManager], which uses this method.
  static Future<void> activateShape({
    @required int device,
    @required int shape,
  }) {
    assert(device != null);
    assert(shape != null);
    return _channel.invokeMethod<void>(
      'activateShape',
      <String, dynamic>{
        'device': device,
        'shape': shape,
      },
    ).catchError(_convertToUnsupportedError, test: _ifUnsupported);
  }

  /// Send an image to the platform in exchange for an identifier for the image
  /// mouse cursor.
  ///
  /// All arguments are required, and must not be null.
  ///
  /// The returned future completes with the identifier if it succeeds, which
  /// can be used by [activateImage] and [unregisterImage].
  /// {@macro flutter.mouseCursorController.unsupportedFeature}
  ///
  /// See also:
  ///
  ///  * [ImageMouseCursor], which explains image mouse cursors.
  ///  * [PreparedImageMouseCursor], which uses the returned image ID.
  ///  * [MouseRegion], which uses this method.
  static Future<int> registerImage({
    @required ui.Image image,
    @required Offset hotSpot,
    @required double scale,
  }) async {
    assert(image != null);
    assert(scale != null);
    assert(hotSpot != null);
    final ByteData byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final Int32List imageColors = byteData.buffer.asInt32List();
    return _channel.invokeMethod<int>(
      'registerImage',
      <String, dynamic>{
        'colors': imageColors,
        'width': image.width,
        'height': image.height,
        'scale': scale,
        'hotSpotX': hotSpot.dx,
        'hotSpotY': hotSpot.dy,
      },
    ).catchError(_convertToUnsupportedError, test: _ifUnsupported);
  }

  /// Activate an image mouse cursor using the image ID returned by
  /// [registerImage].
  ///
  /// All arguments are required, and must not be null.
  ///
  /// {@macro flutter.mouseCursorController.unsupportedFeature}
  ///
  /// See also:
  ///
  ///  * [ImageMouseCursor], which explains image mouse cursors.
  ///  * [PreparedImageMouseCursor], which uses the image ID.
  ///  * [StandardMouseCursorManager], which uses this method.
  static Future<void> activateImage({
    @required int device,
    @required int imageId,
  }) {
    assert(device != null);
    assert(imageId != null);
    return _channel.invokeMethod<void>(
      'activateImage',
      <String, dynamic>{
        'device': device,
        'imageId': imageId,
      },
    ).catchError(_convertToUnsupportedError, test: _ifUnsupported);
  }

  /// Unregister an image mouse cursor, so that it can no longer be used by
  /// [activateImage].
  ///
  /// {@macro flutter.mouseCursorController.unsupportedFeature}
  ///
  /// See also:
  ///
  ///  * [ImageMouseCursor], which explains image mouse cursors.
  ///  * [PreparedImageMouseCursor], which uses the image ID.
  static Future<void> unregisterImage(int imageId) {
    assert(imageId != null);
    return _channel.invokeMethod<void>(
      'unregisterImage',
      <String, dynamic>{
        'imageId': imageId,
      },
    ).catchError(_convertToUnsupportedError, test: _ifUnsupported);
  }
}
