// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection' show LinkedHashSet;

import 'package:flutter/foundation.dart';

import 'events.dart';
import 'mouse_tracking.dart';

/// An interface for mouse cursor definitions.
///
/// A mouse cursor is a graphical image on the screen that echoes the movement
/// of a pointer device, such as a mouse or a stylus. A [MouseCursor] object
/// defines a kind of mouse cursor, such as an arrow, a pointing hand, or an
/// I-beam.
///
/// Internally, when the mouse pointer moves, it finds the front-most region
/// assigned with a mouse cursor, and, if the cursor for this pointer changes,
/// activates the cursor based on its type. If no cursors are assigned to
/// a position, it defaults to [SystemMouseCursors.basic].
///
/// ## Cursor classes
///
/// [SystemMouseCursor] is a cursor that is natively supported by the platform
/// that the program is running on, and is the most common kind of cursor. All
/// supported system mouse cursors are enumerated in [SystemMouseCursors].
///
/// [ImageMouseCursor] is a cursor that displays an image. Various sources
/// of the image are supported, such as network, file, assets, memory, etc.
/// Internally it must be prepared before being activated, which results into a
/// cached [PreparedImageMouseCursor].
///
/// [NoopMouseCursor] is a kind of cursor that does nothing when switched onto.
/// It is useful in special cases such as a platform view where the mouse
/// cursor is managed by other means.
///
/// ## Using cursors
///
/// A [MouseCursor] object is used by being assigned to a [MouseRegion], while
/// many widgets also exposes such API, such as [InkWell.mouseCursor].
///
/// {@tool snippet --template=stateless_widget_material}
/// This sample creates a rectangular region that is wrapped by a [MouseRegion]
/// with a system mouse cursor. The mouse pointer becomes an I-beam when
/// hovering on it.
///
/// ```dart imports
/// import 'package:flutter/widgets.dart';
/// import 'package:flutter/gestures.dart';
/// ```
///
/// ```dart
/// Widget build(BuildContext context) {
///   return Center(
///     child: MouseRegion(
///       cursor: SystemMouseCursors.text,
///       child: Container(
///         width: 200,
///         height: 100,
///         decoration: BoxDecoration(
///           color: Colors.blue,
///           border: Border.all(color: Colors.yellow),
///         ),
///       ),
///     ),
///   );
/// }
/// ```
/// {@end-tool}
///
/// Assigning regions with mouse cursors on platforms that do not support mouse
/// cursors, or when there are no mouse connected, will result in no-op.
///
/// ## Related classes
///
/// [MouseCursorManager] is an class that manages the states, and dispatches
/// specific operations based on general mouse device updates.
///
/// [MouseCursorController] implements low-level imperative control by directly
/// talking to the platform. This class is designed to be created and used by
/// the framework, therefore should not be directly used by widgets.
///
/// See also:
///
///  * [MouseRegion], which is a common way of assigning a region with a
///    [MouseCursor].
///  * [MouseTracker], which determines the cursor that each device should show,
///    and dispatches the changing callbacks.
///  * [SystemMouseCursors], which provies many system cursors.
///  * [NoopMouseCursors], which is a special type of mouse cursor that does
///    nothing.
@immutable
class MouseCursor extends Diagnosticable {
  const MouseCursor({this.debugDescription});

  final String debugDescription;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.debug}) {
    if (debugDescription != null)
      return '$runtimeType($debugDescription)';
    return super.toString(minLevel: minLevel);
  }
}

class PreparedMouseCursor extends MouseCursor {
  const PreparedMouseCursor({String debugDescription})
    : super(debugDescription: debugDescription);
}

class _DeviceState {
  ValueNotifier<PreparedMouseCursor> currentNotifier;
  VoidCallback onCursorChange;
}

class ImageMouseCursorCache {
  final Map<Object, FutureOr<int>> _cache = <Object, FutureOr<int>>{};

  void query(
    Object key, {
    void Function(int value) ifHit,
    void Function(Future<int> value) ifPending,
    Future<int> Function() ifMiss,
  }) {
    final FutureOr<int> cachedValue = _cache[key];
    if (cachedValue is int) {
      ifHit(cachedValue);
      return;
    }
    if (cachedValue is Future<int>) {
      ifPending(cachedValue);
      return;
    }
    assert(cachedValue == null);

    final Future<int> newTask = ifMiss();
    _cache[key] = newTask;
    newTask.then((int result) {
      if (!identical(newTask, _cache[key])) {
        // This can happen when the cache is disposed while the task is pending
        return null;
      }
      _cache[key] = result;
    });
  }

  List<int> dispose() {
    final List<int> previousValues = _cache.values.whereType<int>().toList();
    _cache.clear();
    return previousValues;
  }
}

/// A manager that maintains the states related to mouse cursor.
///
/// This class is an internal class used by the framework. Widgets that want to
/// set cursors should not directly call this class, instead should assign
/// [MouseCursor]s to the intended regions using [MouseRegion] or related tools.
///
/// See also:
///
///  * [MouseCursor], which contains detailed documentation about the general
///    mouse cursors subsystem.
///  * [MouseRegion], which is the idiomatic way of assigning mouse cursors
///    to regions.
///  * [MouseTracker], which uses this class.
///  * [StandardMouseCursorManager], which provides the standard implementation
///    by talking to the platform with a method channel, and is used by
///    [MouseTracker].
abstract class MouseCursorManager {
  /// Create an instance of this class.
  MouseCursorManager();

  Future<void> dispose();

  final Map<int, _DeviceState> _deviceStates = <int, _DeviceState>{};

  // Find the mouse cursor.
  // The `annotations` is the current annotations that the device is
  // hovering in visual order from front the back.
  static ValueNotifier<PreparedMouseCursor> _findDeviceCursor(LinkedHashSet<MouseTrackerAnnotation> annotations) {
    for (final MouseTrackerAnnotation annotation in annotations) {
      if (annotation.cursor != null) {
        return annotation.cursor;
      }
    }
    return null;
  }

  ImageMouseCursorCache get imageCursorCache => _imageCursorCache;
  final ImageMouseCursorCache _imageCursorCache = ImageMouseCursorCache();

  PreparedMouseCursor get defaultCursor;

  @protected
  Future<void> handleActivateCursor(int device, PreparedMouseCursor cursor);

  /// Called when a mouse device has a change in status that might affect
  /// its cursor.
  ///
  /// This method is called by [MouseTracker].
  void updateFromMouseTracker(MouseTrackerUpdateDetails details) {
    final int device = details.device;

    if (details.triggeringEvent is PointerRemovedEvent) {
      _deviceStates.remove(device);
      return;
    }

    _deviceStates.putIfAbsent(device, () {
      final _DeviceState state = _DeviceState();
      state.onCursorChange = () {
        handleActivateCursor(device, state.currentNotifier?.value ?? defaultCursor);
      };
      return state;
    });

    final _DeviceState state = _deviceStates[device];
    final ValueNotifier<PreparedMouseCursor> lastNotifier = state.currentNotifier;
    final ValueNotifier<PreparedMouseCursor> nextNotifier = _findDeviceCursor(details.nextAnnotations);
    if (lastNotifier == nextNotifier)
      return;

    state.currentNotifier = nextNotifier;
    lastNotifier?.removeListener(state.onCursorChange);
    nextNotifier?.addListener(state.onCursorChange);

    final PreparedMouseCursor lastCursor = lastNotifier?.value ?? defaultCursor;
    final PreparedMouseCursor nextCursor = nextNotifier?.value ?? defaultCursor;
    if (nextCursor != lastCursor) {
      handleActivateCursor(device, nextCursor);
    }
  }
}
