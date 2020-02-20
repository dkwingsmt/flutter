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
/// a position, it defaults to [MouseTrackerCursorMixin.defaultCursor], which
/// is typically [SystemMouseCursors.basic].
///
/// A [MouseCursor] object may contain the full resources that are ready to be
/// consumed by the system (in which case it should subclass
/// [PreparedMouseCursor]), or might contain a specification and needs more work
/// to be converted to resources.
///
/// ## Cursor classes
///
/// [SystemMouseCursor] are cursors that are natively supported by the platform
/// that the program is running on, and is the most common kind of cursor. All
/// supported system mouse cursors are enumerated in [SystemMouseCursors].
///
/// [NoopMouseCursor] are cursors that do nothing when switched onto. It is
/// useful in special cases such as a platform view where the mouse cursor is
/// managed by other means.
///
/// ## Using cursors
///
/// A [MouseCursor] object is used by being assigned to a [MouseRegion], while
/// many widgets also exposes such API, such as [InkWell.mouseCursor].
///
/// {@tool snippet --template=stateless_widget_material}
/// This sample creates a rectangular region that is wrapped by a [MouseRegion]
/// with a system mouse cursor. The mouse pointer becomes an I-beam when
/// hovering the region.
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
/// The following classes are designed to be created and used by the framework,
/// therefore should not be directly used by widgets.
///
/// [MouseTrackerCursorMixin] is a class that manages states, and dispatches
/// specific operations based on general mouse device updates.
///
/// [MouseCursorController] implements low-level imperative control by directly
/// talking to the platform.
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
abstract class MouseCursor extends Diagnosticable {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const MouseCursor();

  /// A very short pretty description of the mouse cursor.
  ///
  /// The [debugDescription] shoule be a few words that can differentiate
  /// instances of a class to make debug information more readable. For example,
  /// a [SystemMouseCursor] class with description "drag" will be printed as
  /// "SystemMouseCursor(drag)".
  ///
  /// The [debugDescription] should not be null, but can be an empty string,
  /// which means the class is not configurable.
  String get debugDescription;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    final String debugDescription = this.debugDescription;
    if (minLevel.index >= DiagnosticLevel.info.index && debugDescription != null)
      return '$runtimeType($debugDescription)';
    return super.toString(minLevel: minLevel);
  }
}

/// An interface for mouse cursors that have all resources prepared and ready to
/// be sent to the system.
///
/// Although [PreparedMouseCursor] adds no changes on top of [MouseCursor], this
/// class is designed to prevent unprepared cursor types from methods that
/// directly talk to the system.
abstract class PreparedMouseCursor extends MouseCursor {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const PreparedMouseCursor();
}

class _DeviceState {
  ValueNotifier<PreparedMouseCursor> currentNotifier;
  VoidCallback onCursorChange;
}

/// A mixin for [MouseTracker] to allow maintaining states and handling changes
/// related to mouse cursor.
///
/// See also:
///
///  * [MouseCursor], which contains detailed documentation about the general
///    mouse cursors subsystem.
///  * [MouseRegion], which is the idiomatic way of assigning mouse cursors
///    to regions.
///  * [MouseTracker], which uses this class.
mixin MouseTrackerCursorMixin on MouseTracker {
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

  PreparedMouseCursor get defaultCursor;

  @protected
  Future<void> handleActivateCursor(int device, PreparedMouseCursor cursor);

  @override
  void handleDeviceUpdate(MouseTrackerUpdateDetails details) {
    super.handleDeviceUpdate(details);
    _handleDeviceUpdateMouseCursor(details);
  }

  // Called when a mouse device has a change in status that might affect
  // its cursor.
  //
  // This method is called by [MouseTracker].
  void _handleDeviceUpdateMouseCursor(MouseTrackerUpdateDetails details) {
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
