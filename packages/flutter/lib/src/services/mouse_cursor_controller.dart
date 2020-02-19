// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
}
