// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;
import 'dart:ui' show PointerChange;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../flutter_test_alternative.dart';


void main() {
  void _setUpMouseTracker({
    MouseDetectorAnnotationFinder annotationFinder,
    List<_CursorUpdateDetails> logCursors,
    PreparedMouseCursor defaultCursor,
  }) {
    final MouseTracker mouseTracker = _TestMouseTracker(
      GestureBinding.instance.pointerRouter,
      annotationFinder,
      logCursors: logCursors,
    );
    RendererBinding.instance.initMouseTracker(mouseTracker);
  }

  // System cursors must be constants.
  const SystemMouseCursor testCursor = SystemMouseCursors.grabbing;

  test('should correctly set to the cursor of the first annotation, or default cursor if none', () {
    final List<_CursorUpdateDetails> logCursors = <_CursorUpdateDetails>[];
    const PreparedMouseCursor defaultCursor = SystemMouseCursors.grab;
    MouseTrackerAnnotation annotation;
    _setUpMouseTracker(
      annotationFinder: (Offset position) => <MouseTrackerAnnotation>[annotation],
      logCursors: logCursors,
      defaultCursor: defaultCursor,
    );

    // Pointer is added outside of the annotation.
    ui.window.onPointerDataPacket(ui.PointerDataPacket(data: <ui.PointerData>[
      _pointerData(PointerChange.add, const Offset(0.0, 0.0)),
    ]));

    expect(logCursors, const <_CursorUpdateDetails>[
      _CursorUpdateDetails(device: 0, cursor: defaultCursor),
    ]);
    logCursors.clear();

    // TODO
  });
}

ui.PointerData _pointerData(
  PointerChange change,
  Offset logicalPosition, {
  int device = 0,
  PointerDeviceKind kind = PointerDeviceKind.mouse,
}) {
  return ui.PointerData(
    change: change,
    physicalX: logicalPosition.dx * ui.window.devicePixelRatio,
    physicalY: logicalPosition.dy * ui.window.devicePixelRatio,
    kind: kind,
    device: device,
  );
}

class _TestMouseTracker extends MouseTracker with MouseTrackerCursorMixin {
  _TestMouseTracker(
    PointerRouter router,
    MouseDetectorAnnotationFinder annotationFinder, {
    this.logCursors,
    this.defaultCursor = SystemMouseCursors.basic,
  }) : super(router, annotationFinder);

  final List<_CursorUpdateDetails> logCursors;
  @override
  final PreparedMouseCursor defaultCursor;

  @override
  Future<void> handleActivateCursor(int device, PreparedMouseCursor cursor) async {
    if (logCursors != null)
      logCursors.add(_CursorUpdateDetails(cursor: cursor, device: device));
  }

}

@immutable
class _CursorUpdateDetails {
  const _CursorUpdateDetails({@required this.cursor, @required this.device});

  final PreparedMouseCursor cursor;
  final int device;

  @override
  bool operator ==(dynamic other) {
    if (identical(other, this))
      return true;
    if (other.runtimeType != runtimeType)
      return false;
    return other is _CursorUpdateDetails
        && other.cursor == cursor
        && other.device == device;
  }

  @override
  int get hashCode => hashValues(runtimeType, cursor, device);

  @override
  String toString() {
    return '_CursorUpdateDetails(device: $device, cursor: $cursor)';
  }
}
