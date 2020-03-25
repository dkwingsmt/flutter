// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection' show LinkedHashSet;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'events.dart';
import 'mouse_cursor.dart';
import 'pointer_router.dart';

/// Signature for listening to [PointerEnterEvent] events.
///
/// Used by [MouseTrackerAnnotation], [MouseRegion] and [RenderMouseRegion].
typedef PointerEnterEventListener = void Function(PointerEnterEvent event);

/// Signature for listening to [PointerExitEvent] events.
///
/// Used by [MouseTrackerAnnotation], [MouseRegion] and [RenderMouseRegion].
typedef PointerExitEventListener = void Function(PointerExitEvent event);

/// Signature for listening to [PointerHoverEvent] events.
///
/// Used by [MouseTrackerAnnotation], [MouseRegion] and [RenderMouseRegion].
typedef PointerHoverEventListener = void Function(PointerHoverEvent event);

/// The annotation object used to annotate layers that are interested in mouse
/// movements.
///
/// This is added to a layer and managed by the [MouseRegion] widget.
class MouseTrackerAnnotation extends Diagnosticable {
  /// Creates an annotation that can be used to find layers interested in mouse
  /// movements.
  ///
  /// All arguments are optional.
  MouseTrackerAnnotation({
    this.onEnter,
    this.onHover,
    this.onExit,
    PreparedMouseCursor cursor,
  }) : _cursorNotifier = ValueNotifier<PreparedMouseCursor>(cursor);

  /// Discards any resources used by the object. After this is called, the
  /// object is not in a usable state and should be discarded.
  ///
  /// This method should only be called by the object's owner.
  void dispose() {
    _cursorNotifier.dispose();
  }

  /// Triggered when a mouse pointer, with or without buttons pressed, has
  /// entered the annotated region.
  ///
  /// This callback is triggered when the pointer has started to be contained
  /// by the annotationed region for any reason, which means it always matches a
  /// later [onExit].
  ///
  /// See also:
  ///
  ///  * [onExit], which is triggered when a mouse pointer exits the region.
  ///  * [MouseRegion.onEnter], which uses this callback.
  final PointerEnterEventListener onEnter;

  /// Triggered when a pointer has moved within the annotated region without
  /// buttons pressed.
  ///
  /// This callback is triggered when:
  ///
  ///  * An annotation that did not contain the pointer has moved to under a
  ///    pointer that has no buttons pressed.
  ///  * A pointer has moved onto, or moved within an annotation without buttons
  ///    pressed.
  ///
  /// This callback is not triggered when:
  ///
  ///  * An annotation that is containing the pointer has moved, and still
  ///    contains the pointer.
  final PointerHoverEventListener onHover;

  /// Triggered when a mouse pointer, with or without buttons pressed, has
  /// exited the annotated region when the annotated region still exists.
  ///
  /// This callback is triggered when the pointer has stopped being contained
  /// by the region for any reason, which means it always matches an earlier
  /// [onEnter].
  ///
  /// See also:
  ///
  ///  * [onEnter], which is triggered when a mouse pointer enters the region.
  ///  * [RenderMouseRegion.onExit], which uses this callback.
  ///  * [MouseRegion.onExit], which uses this callback, but is not triggered in
  ///    certain cases and does not always match its earier [MouseRegion.onEnter].
  final PointerExitEventListener onExit;

  /// The cursor that a mouse pointer should change to if it enters or is
  /// hovering the annotated layer.
  ///
  /// If [cursor] is null, the choice is deferred to the next annotation behind
  /// this one.
  ///
  /// The change of [cursor] can be listened to on [cursorNotifier].
  PreparedMouseCursor get cursor => _cursorNotifier.value;
  set cursor(PreparedMouseCursor value) {
    _cursorNotifier.value = value;
  }

  /// Register listeners to get notified whenever [cursor] changes.
  ChangeNotifier get cursorNotifier => _cursorNotifier;
  final ValueNotifier<PreparedMouseCursor> _cursorNotifier;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagsSummary<Function>(
      'callbacks',
      <String, Function> {
        'enter': onEnter,
        'hover': onHover,
        'exit': onExit,
      },
      ifEmpty: '<none>',
    ));
    properties.add(DiagnosticsProperty<PreparedMouseCursor>('cursor', cursor, defaultValue: null));
    properties.add(DiagnosticsProperty<ValueNotifier<PreparedMouseCursor>>(
      'cursorNotifier',
      _cursorNotifier,
      level: DiagnosticLevel.fine,
    ));
  }
}

/// Signature for searching for [MouseTrackerAnnotation]s at the given offset.
///
/// It is used by the [MouseTracker] to fetch annotations for the mouse
/// position.
typedef MouseDetectorAnnotationFinder = Iterable<MouseTrackerAnnotation> Function(Offset offset);

// Various states of a connected mouse device used by [MouseTracker].
class _MouseState {
  _MouseState({
    @required PointerEvent initialEvent,
  }) : assert(initialEvent != null),
       _latestEvent = initialEvent;

  // The list of annotations that contains this device.
  LinkedHashSet<MouseTrackerAnnotation> get annotations => _annotations;
  LinkedHashSet<MouseTrackerAnnotation> _annotations = <MouseTrackerAnnotation>{} as LinkedHashSet<MouseTrackerAnnotation>;

  LinkedHashSet<MouseTrackerAnnotation> replaceAnnotations(LinkedHashSet<MouseTrackerAnnotation> value) {
    assert(value != null);
    final LinkedHashSet<MouseTrackerAnnotation> previous = _annotations;
    _annotations = value;
    return previous;
  }

  // The most recently processed mouse event observed from this device.
  PointerEvent get latestEvent => _latestEvent;
  PointerEvent _latestEvent;

  PointerEvent replaceLatestEvent(PointerEvent value) {
    assert(value != null);
    assert(value.device == _latestEvent.device);
    final PointerEvent previous = _latestEvent;
    _latestEvent = value;
    return previous;
  }

  int get device => latestEvent.device;

  @override
  String toString() {
    String describeEvent(PointerEvent event) {
      return event == null ? 'null' : describeIdentity(event);
    }
    final String describeLatestEvent = 'latestEvent: ${describeEvent(latestEvent)}';
    final String describeAnnotations = 'annotations: [list of ${annotations.length}]';
    return '${describeIdentity(this)}($describeLatestEvent, $describeAnnotations)';
  }
}

/// Used by [MouseTracker] to provide the details of an update of a mouse
/// device.
///
/// This class contains the information needed to handle the update that might
/// change the state of a mouse device, or the [MouseTrackerAnnotation]s that
/// the mouse device is hovering.
@immutable
class MouseTrackerUpdateDetails {
  /// When device update is triggered by a new frame.
  ///
  /// All parameters are required.
  const MouseTrackerUpdateDetails.byNewFrame({
    @required this.lastAnnotations,
    @required this.nextAnnotations,
    @required this.previousEvent,
  }) : assert(previousEvent != null),
       assert(lastAnnotations != null),
       assert(nextAnnotations != null),
       triggeringEvent = null;

  /// When device update is triggered by a pointer event.
  ///
  /// The [lastAnnotations], [nextAnnotations], and [triggeringEvent] are
  /// required.
  const MouseTrackerUpdateDetails.byPointerEvent({
    @required this.lastAnnotations,
    @required this.nextAnnotations,
    this.previousEvent,
    @required this.triggeringEvent,
  }) : assert(triggeringEvent != null),
       assert(lastAnnotations != null),
       assert(nextAnnotations != null);

  /// The annotations that the device is hovering before the update.
  ///
  /// It is never null.
  final LinkedHashSet<MouseTrackerAnnotation> lastAnnotations;

  /// The annotations that the device is hovering after the update.
  ///
  /// It is never null.
  final LinkedHashSet<MouseTrackerAnnotation> nextAnnotations;

  /// The last event that the device observed before the update.
  ///
  /// If the update is triggered by a frame, it is not null, since the pointer
  /// must have been added before. If the update is triggered by an event,
  /// it might be null.
  final PointerEvent previousEvent;

  /// The event that triggered this update.
  ///
  /// It is non-null if and only if the update is triggered by a pointer event.
  final PointerEvent triggeringEvent;

  /// The pointer device of this update.
  int get device {
    final int result = (previousEvent ?? triggeringEvent).device;
    assert(result != null);
    return result;
  }

  /// The last event that the device observed after the update.
  ///
  /// The [latestEvent] is never null.
  PointerEvent get latestEvent {
    final PointerEvent result = triggeringEvent ?? previousEvent;
    assert(result != null);
    return result;
  }
}

typedef MouseTrackerUpdateListener = void Function(MouseTrackerUpdateDetails update);

/// Maintains the relationship between mouse devices and
/// [MouseTrackerAnnotation]s, and notifies interested callbacks of the changes
/// thereof.
///
/// An instance of [MouseTracker] is owned by the global singleton of
/// [RendererBinding].
///
/// This class is a [ChangeNotifier] that notifies its listeners if the value of
/// [mouseIsConnected] changes.
///
/// ### Details
///
/// The state of [MouseTracker] consists of two parts:
///
///  * The mouse devices that are connected.
///  * In which annotations each device is contained.
///
/// The states remain stable most of the time, and are only changed at the
/// following moments:
///
///  * An eligible [PointerEvent] has been observed, e.g. a device is added,
///    removed, or moved. In this case, the state related to this device will
///    be immediately updated.
///  * A frame has been painted. In this case, a callback will be scheduled for
///    the upcoming post-frame phase to update all devices.
///
/// See also:
///
///   * [MouseTracker], which is a subclass of [MouseTracker] with definition
///     of how to process mouse event callbacks and mouse cursors.
///   * [MouseCursorMixin], which is a mixin of [MouseTracker] that defines
///     how to process mouse cursors.
class MouseTracker extends ChangeNotifier {
  /// Creates a mouse tracker to keep track of mouse locations.
  ///
  /// The first parameter is a [PointerRouter], which [MouseTracker] will
  /// subscribe to and receive events from. Usually it is the global singleton
  /// instance [GestureBinding.pointerRouter].
  ///
  /// The second parameter is a function with which the [MouseTracker] can
  /// search for [MouseTrackerAnnotation]s at a given position.
  /// Usually it is [Layer.findAllAnnotations] of the root layer.
  ///
  /// The third parameter is a [MouseCursorManager] that handles the mouse
  /// cursor system.
  ///
  /// All of the parameters must be non-null.
  MouseTracker(this._router, this.annotationFinder) : assert(_router != null),
       assert(annotationFinder != null) {
    _router.addGlobalRoute(_handleEvent);
  }

  @override
  void dispose() {
    super.dispose();
    _router.removeGlobalRoute(_handleEvent);
  }

  /// Find annotations at a given offset in global logical coordinate space
  /// in visual order from front to back.
  ///
  /// [MouseTracker] uses this callback to know which annotations are
  /// affected by each device.
  ///
  /// The annotations should be returned in visual order from front to
  /// back, so that the callbacks are called in an correct order.
  final MouseDetectorAnnotationFinder annotationFinder;

  // The pointer router that the mouse tracker listens to, and receives new
  // mouse events from.
  final PointerRouter _router;

  // Tracks the state of connected mouse devices.
  //
  // It is the source of truth for the list of connected mouse devices.
  final Map<int, _MouseState> _mouseStates = <int, _MouseState>{};

  // Used to wrap any procedure that might change `mouseIsConnected`.
  //
  // This method records `mouseIsConnected`, runs `task`, and calls
  // [notifyListeners] at the end if the `mouseIsConnected` has changed.
  void _monitorMouseConnection(VoidCallback task) {
    final bool mouseWasConnected = mouseIsConnected;
    task();
    if (mouseWasConnected != mouseIsConnected)
      notifyListeners();
  }

  bool _debugDuringDeviceUpdate = false;
  // Used to wrap any procedure that might call [handleDeviceUpdate].
  //
  // In debug mode, this method uses `_debugDuringDeviceUpdate` to prevent
  // `_deviceUpdatePhase` being recursively called.
  void _deviceUpdatePhase(VoidCallback task) {
    assert(!_debugDuringDeviceUpdate);
    assert(() {
      _debugDuringDeviceUpdate = true;
      return true;
    }());
    task();
    assert(() {
      _debugDuringDeviceUpdate = false;
      return true;
    }());
  }

  // Whether an observed event might update a device.
  static bool _shouldMarkStateDirty(_MouseState state, PointerEvent event) {
    if (state == null)
      return true;
    assert(event != null);
    final PointerEvent lastEvent = state.latestEvent;
    assert(event.device == lastEvent.device);
    // An Added can only follow a Removed, and a Removed can only be followed
    // by an Added.
    assert((event is PointerAddedEvent) == (lastEvent is PointerRemovedEvent));

    // Ignore events that are unrelated to mouse tracking.
    if (event is PointerSignalEvent)
      return false;
    return lastEvent is PointerAddedEvent
      || event is PointerRemovedEvent
      || lastEvent.position != event.position;
  }

  // Handler for events coming from the PointerRouter.
  //
  // If the event marks the device dirty, update the device immediately.
  void _handleEvent(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse)
      return;
    if (event is PointerSignalEvent)
      return;
    final int device = event.device;
    final _MouseState existingState = _mouseStates[device];
    if (!_shouldMarkStateDirty(existingState, event))
      return;

    _monitorMouseConnection(() {
      _deviceUpdatePhase(() {
        // Update mouseState to the latest devices that have not been removed,
        // so that [mouseIsConnected], which is decided by `_mouseStates`, is
        // correct during the callbacks.
        if (existingState == null) {
          _mouseStates[device] = _MouseState(initialEvent: event);
        } else {
          assert(event is! PointerAddedEvent);
          if (event is PointerRemovedEvent)
            _mouseStates.remove(event.device);
        }
        final _MouseState targetState = _mouseStates[device] ?? existingState;

        final PointerEvent lastEvent = targetState.replaceLatestEvent(event);
        final LinkedHashSet<MouseTrackerAnnotation> nextAnnotations = _findAnnotations(targetState);
        final LinkedHashSet<MouseTrackerAnnotation> lastAnnotations = targetState.replaceAnnotations(nextAnnotations);

        handleDeviceUpdate(MouseTrackerUpdateDetails.byPointerEvent(
          lastAnnotations: lastAnnotations,
          nextAnnotations: nextAnnotations,
          previousEvent: lastEvent,
          triggeringEvent: event,
        ));
      });
    });
  }

  // Find the annotations that is hovered by the device of the `state`.
  //
  // If the device is not connected, an empty set is returned without calling
  // `annotationFinder`.
  LinkedHashSet<MouseTrackerAnnotation> _findAnnotations(_MouseState state) {
    final Offset globalPosition = state.latestEvent.position;
    final int device = state.device;
    return (_mouseStates.containsKey(device))
      ? LinkedHashSet<MouseTrackerAnnotation>.from(annotationFinder(globalPosition))
      : <MouseTrackerAnnotation>{} as LinkedHashSet<MouseTrackerAnnotation>;
  }

  static bool get _duringBuildPhase {
    return SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks;
  }

  // Update all devices, despite observing no new events.
  //
  // This is called after a new frame, since annotations can be moved after
  // every frame.
  void _updateAllDevices() {
    _deviceUpdatePhase(() {
      for (final _MouseState dirtyState in _mouseStates.values) {
        final PointerEvent lastEvent = dirtyState.latestEvent;
        final LinkedHashSet<MouseTrackerAnnotation> nextAnnotations = _findAnnotations(dirtyState);
        final LinkedHashSet<MouseTrackerAnnotation> lastAnnotations = dirtyState.replaceAnnotations(nextAnnotations);

        handleDeviceUpdate(MouseTrackerUpdateDetails.byNewFrame(
          lastAnnotations: lastAnnotations,
          nextAnnotations: nextAnnotations,
          previousEvent: lastEvent,
        ));
      }
    });
  }

  /// A callback that is called on the update of a device.
  ///
  /// Override this method to handle updates when the relationship between a
  /// device and annotations have changed. The update has 2 kind of triggers:
  ///
  ///   * If `details.triggeringEvent` is not null, then the update is triggered
  ///     by the addition, movement, or removal of the pointer during the handler
  ///     of the event.
  ///   * If `details.triggeringEvent` is null, then the update is triggered by
  ///     the appearance, movement, or disappearance of the annotation during
  ///     the post-frame callback phase following the frame.
  ///
  /// Typically called only by [MouseTracker].
  ///
  /// Subclasses should override this method to first call to first call their
  /// inherited [handleDeviceUpdate] method, and then process the update as
  /// desired.
  // Calling method must be wrapped in `_deviceUpdatePhase`.
  @mustCallSuper
  @protected
  void handleDeviceUpdate(MouseTrackerUpdateDetails details) {
    assert(_debugDuringDeviceUpdate);

    _handleDeviceUpdateMouseEvents(details);
  }

  // Dispatch callbacks related to a device after all necessary information
  // has been collected.
  //
  // The `previousEvent` is the latest event before `unhandledEvent`. It might be
  // null, which means the update is triggered by a new event.
  // The `triggeringEvent` can be null, which means the update is not triggered
  // by an event.
  // However, one of `previousEvent` or `unhandledEvent` must not be null.
  static void _handleDeviceUpdateMouseEvents(MouseTrackerUpdateDetails details) {
    final PointerEvent previousEvent = details.previousEvent;
    final PointerEvent triggeringEvent = details.triggeringEvent;
    final PointerEvent latestEvent = details.latestEvent;

    final LinkedHashSet<MouseTrackerAnnotation> lastAnnotations = details.lastAnnotations;
    final LinkedHashSet<MouseTrackerAnnotation> nextAnnotations = details.nextAnnotations;

    // Order is important for mouse event callbacks. The `findAnnotations`
    // returns annotations in the visual order from front to back. We call
    // it the "visual order", and the opposite one "reverse visual order".
    // The algorithm here is explained in
    // https://github.com/flutter/flutter/issues/41420

    // Send exit events to annotations that are in last but not in next, in
    // visual order.
    final Iterable<MouseTrackerAnnotation> exitingAnnotations = lastAnnotations.difference(nextAnnotations);
    for (final MouseTrackerAnnotation annotation in exitingAnnotations) {
      if (annotation.onExit != null) {
        annotation.onExit(PointerExitEvent.fromMouseEvent(latestEvent));
      }
    }

    // Send enter events to annotations that are not in last but in next, in
    // reverse visual order.
    final Iterable<MouseTrackerAnnotation> enteringAnnotations = nextAnnotations
      .difference(lastAnnotations).toList().reversed;
    for (final MouseTrackerAnnotation annotation in enteringAnnotations) {
      if (annotation.onEnter != null) {
        annotation.onEnter(PointerEnterEvent.fromMouseEvent(latestEvent));
      }
    }

    // Send hover events to annotations that are in next, in reverse visual
    // order. The reverse visual order is chosen only because of the simplicity
    // by keeping the hover events aligned with enter events.
    if (triggeringEvent is PointerHoverEvent) {
      final Offset hoverPositionBeforeUpdate = previousEvent is PointerHoverEvent ? previousEvent.position : null;
      final bool pointerHasMoved = hoverPositionBeforeUpdate == null || hoverPositionBeforeUpdate != triggeringEvent.position;
      // If the hover event follows a non-hover event, or has moved since the
      // last hover, then trigger hover the callback to all annotations.
      // Otherwise, trigger the hover callback only to annotations that it
      // newly enters.
      final Iterable<MouseTrackerAnnotation> hoveringAnnotations = pointerHasMoved ? nextAnnotations.toList().reversed : enteringAnnotations;
      for (final MouseTrackerAnnotation annotation in hoveringAnnotations) {
        if (annotation.onHover != null) {
          annotation.onHover(triggeringEvent);
        }
      }
    }
  }

  bool _hasScheduledPostFrameCheck = false;
  /// Mark all devices as dirty, and schedule a callback that is executed in the
  /// upcoming post-frame phase to check their updates.
  ///
  /// Checking a device means to collect the annotations that the pointer
  /// hovers, and triggers necessary callbacks accordingly.
  ///
  /// Although the actual callback belongs to the scheduler's post-frame phase,
  /// this method must be called in persistent callback phase to ensure that
  /// the callback is scheduled after every frame, since every frame can change
  /// the position of annotations. Typically the method is called by
  /// [RendererBinding]'s drawing method.
  void schedulePostFrameCheck() {
    assert(_duringBuildPhase);
    assert(!_debugDuringDeviceUpdate);
    if (!mouseIsConnected)
      return;
    if (!_hasScheduledPostFrameCheck) {
      _hasScheduledPostFrameCheck = true;
      SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
        assert(_hasScheduledPostFrameCheck);
        _hasScheduledPostFrameCheck = false;
        _updateAllDevices();
      });
    }
  }

  /// Whether or not a mouse is connected and has produced events.
  bool get mouseIsConnected => _mouseStates.isNotEmpty;
}
