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

/// A mouse cursor that does nothing when activated.
///
/// An instance of this class is accessible at
/// [SystemMouseCursors.releaseControl], which also introduces its usage.
/// Directly instantiating this class is unnecessary, since it's not
/// configurable.
class NoopMouseCursor extends PreparedMouseCursor {
  // Application code shouldn't directly instantiate this class, since its only
  // instance is accessible at [SystemMouseCursors.releaseControl].
  const NoopMouseCursor._();

  @override
  String get debugDescription => '';
}

/// A mouse cursor that comes with the system that the program is running on.
///
/// System cursors are the most commonly used cursors, since they are avaiable
/// without external resources, and matches the experience of native apps.
/// Examples of system cursors are a pointing arrow, a pointing hand, a double
/// arrow for resizing, or a text I-beam, etc.
///
/// [SystemMouseCursors] enumerates the complete set of system cursors supported
/// by Flutter, which are hard-coded in the platform engine. Therefore, manually
/// instantiating this class is neither useful nor supported.
///
/// Same or similar system cursors from each platform are mapped onto the same
/// instance in [SystemMouseCursors], and assigned with a constant integer
/// [shape]. Since the set of system cursors supported by each platform varies,
/// multiple instances can be mapped to the same system cursor. The exact value
/// of a [shape] is intentionally random.
class SystemMouseCursor extends PreparedMouseCursor {
  // Application code shouldn't directly instantiate system mouse cursors, since
  // the supported system cursors are enumerated in [SystemMouseCursors].
  const SystemMouseCursor._({
    @required this.shape,
    @required this.debugDescription,
  }) : assert(shape != null),
       assert(debugDescription != null);

  /// Identifies the kind of cursor across platforms.
  ///
  /// The exact value of a [shape] is intentionally random, and its
  /// interpretation (i.e. corresponding system cursor) is hard-coded in the
  /// platform engine.
  ///
  /// See the documentation of [SystemMouseCursor] for introduction.
  final int shape;

  @override
  final String debugDescription;

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is SystemMouseCursor
        && other.shape == shape;
  }

  @override
  int get hashCode => shape;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('shape', shape, level: DiagnosticLevel.debug));
  }
}

/// A collection of system [MouseCursor]s.
///
/// System cursors are mouse cursors provided by the current platform, available
/// without external resources, and are therefore the most common cursors.
///
/// [SystemMouseCursors] is a superset of the system cursors of every platform
/// that Flutter supports, therefore some of these objects might map to the same
/// result, or fallback to the basic arrow. This mapping is implemented by the
/// Flutter engine that the program is running on.
class SystemMouseCursors {
  // This class only contains static members, and should not be initiated or
  // extended.
  factory SystemMouseCursors._() => null;

  /// A special value that tells Flutter to release the control of cursors.
  ///
  /// A region with this value will absorb the search for mouse cursor
  /// configuration, but the pointer's cursor will not be changed when it enters
  /// or is hovering this region. In other words, Flutter has released its
  /// control over the mouse cursor.
  ///
  /// This value is typically used on a platform view or other layers that
  /// manages the cursor by itself.
  static const NoopMouseCursor releaseControl = NoopMouseCursor._();

  // The shape values are chosen as the first 6 bytes of the MD5 hash of the
  // cursor's name at the time of creation. The reason for the 6-byte limit
  // is because JavaScript only supports 54 bits of integer.
  //
  // The shape values must be kept in sync with the engine implementations.

  /// Displays no cursor at the pointer.
  static const SystemMouseCursor none = SystemMouseCursor._(shape: 0x334c4a, debugDescription: 'none');

  /// The platform-dependent basic cursor. Typically the shape of an arrow.
  ///
  /// This cursor is the fallback of unimplemented cursors, and should be
  /// implemented by all platforms that support mouse cursor.
  static const SystemMouseCursor basic = SystemMouseCursor._(shape: 0xf17aaa, debugDescription: 'basic');

  /// A cursor that indicates links or something that needs to be emphasized
  /// to be clickable.
  ///
  /// Typically the shape of a pointing hand.
  static const SystemMouseCursor click = SystemMouseCursor._(shape: 0xa8affc, debugDescription: 'click');

  /// A cursor that indicates a selectable text.
  ///
  /// Typically the shape of a capital I.
  static const SystemMouseCursor text = SystemMouseCursor._(shape: 0x1cb251, debugDescription: 'text');

  /// A cursor that indicates an unpermitted action.
  ///
  /// Typically the shape of a circle with a diagnal line.
  static const SystemMouseCursor forbidden = SystemMouseCursor._(shape: 0x350f9d, debugDescription: 'forbidden');

  /// A cursor that indicates something that can be dragged.
  ///
  /// Typically the shape of an open hand.
  static const SystemMouseCursor grab = SystemMouseCursor._(shape: 0x28b91f, debugDescription: 'grab');

  /// A cursor that indicates something that is being dragged.
  ///
  /// Typically the shape of a closed hand.
  static const SystemMouseCursor grabbing = SystemMouseCursor._(shape: 0x6631ce, debugDescription: 'grabbing');
}
