// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'message_codec.dart';
import 'platform_channel.dart';
import 'system_channels.dart';

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
  /// The returned future completes with an [UnsupportedCursorFeature] if the platform
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
    );
  }

  /// The code of [PlatformException]s that are caused by unsupported
  /// features.
  ///
  /// See also:
  ///
  ///  * [isUnsupportedFeature], which introduces the situation of this code,
  ///    and detects this type of exceptions.
  static const String kUnsupportedFeatureCode = 'unsupported';

  /// Whether the thrown error indicates that a feature is not supported by the
  /// platform, and a fallback is requested.
  ///
  /// This kind of error is thrown when the platform supports mouse cursor, but
  /// is unable to fully fulfill the request.
  static bool isUnsupportedFeature(Object e) {
    return e is PlatformException && e.code == kUnsupportedFeatureCode;
  }
}

mixin StandardMouseTrackerCursorMixin on MouseTrackerCursorMixin {
  @override
  PreparedMouseCursor get defaultCursor => SystemMouseCursors.basic;

  @override
  @protected
  Future<void> handleActivateCursor(int device, PreparedMouseCursor cursor) async {
    if (cursor is NoopMouseCursor)
      return;

    if (cursor is SystemMouseCursor)
      return MouseCursorController.activateShape(device: device, shape: cursor.shape);

    throw UnimplementedError('Unsupported mouse cursor type: ${cursor.runtimeType}');
  }
}
