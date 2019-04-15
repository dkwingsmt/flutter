// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'test_async_utils.dart';

export 'dart:ui' show Offset;

/// A class for generating coherent artificial pointer events.
///
/// You can use this to manually simulate individual events, but the simplest
/// way to generate coherent gestures is to use [TestGesture].
class TestPointer {
  /// Creates a [TestPointer]. By default, the pointer identifier used is 1,
  /// however this can be overridden by providing an argument to the
  /// constructor.
  ///
  /// Multiple [TestPointer]s created with the same pointer identifier will
  /// interfere with each other if they are used in parallel.
  TestPointer([this.pointer = 1, this.kind = PointerDeviceKind.touch])
      : assert(kind != null),
        assert(pointer != null);

  /// The pointer identifier used for events generated by this object.
  ///
  /// Set when the object is constructed. Defaults to 1.
  final int pointer;

  /// The kind of pointer device to simulate. Defaults to
  /// [PointerDeviceKind.touch].
  final PointerDeviceKind kind;

  /// Whether the pointer simulated by this object is currently down.
  ///
  /// A pointer is released (goes up) by calling [up] or [cancel].
  ///
  /// Once a pointer is released, it can no longer generate events.
  bool get isDown => _isDown;
  bool _isDown = false;

  /// The position of the last event sent by this object.
  ///
  /// If no event has ever been sent by this object, returns null.
  Offset get location => _location;
  Offset _location;

  /// If a custom event is created outside of this class, this function is used
  /// to set the [isDown].
  bool setDownInfo(PointerEvent event, Offset newLocation) {
    _location = newLocation;
    switch (event.runtimeType) {
      case PointerDownEvent:
        assert(!isDown);
        _isDown = true;
        break;
      case PointerUpEvent:
      case PointerCancelEvent:
        assert(isDown);
        _isDown = false;
        break;
      default: break;
    }
    return isDown;
  }

  /// Create a [PointerDownEvent] at the given location.
  ///
  /// By default, the time stamp on the event is [Duration.zero]. You can give a
  /// specific time stamp by passing the `timeStamp` argument.
  PointerDownEvent down(Offset newLocation, {Duration timeStamp = Duration.zero}) {
    assert(!isDown);
    _isDown = true;
    _location = newLocation;
    return PointerDownEvent(
      timeStamp: timeStamp,
      kind: kind,
      pointer: pointer,
      position: location,
    );
  }

  /// Create a [PointerMoveEvent] to the given location.
  ///
  /// By default, the time stamp on the event is [Duration.zero]. You can give a
  /// specific time stamp by passing the `timeStamp` argument.
  ///
  /// [isDown] must be true when this is called, since move events can only
  /// be generated when the pointer is down.
  PointerMoveEvent move(Offset newLocation, {Duration timeStamp = Duration.zero}) {
    assert(
        isDown,
        'Move events can only be generated when the pointer is down. To '
        'create a movement event simulating a pointer move when the pointer is '
        'up, use hover() instead.');
    final Offset delta = newLocation - location;
    _location = newLocation;
    return PointerMoveEvent(
      timeStamp: timeStamp,
      kind: kind,
      pointer: pointer,
      position: newLocation,
      delta: delta,
    );
  }

  /// Create a [PointerUpEvent].
  ///
  /// By default, the time stamp on the event is [Duration.zero]. You can give a
  /// specific time stamp by passing the `timeStamp` argument.
  ///
  /// The object is no longer usable after this method has been called.
  PointerUpEvent up({Duration timeStamp = Duration.zero}) {
    assert(isDown);
    _isDown = false;
    return PointerUpEvent(
      timeStamp: timeStamp,
      kind: kind,
      pointer: pointer,
      position: location,
    );
  }

  /// Create a [PointerCancelEvent].
  ///
  /// By default, the time stamp on the event is [Duration.zero]. You can give a
  /// specific time stamp by passing the `timeStamp` argument.
  ///
  /// The object is no longer usable after this method has been called.
  PointerCancelEvent cancel({Duration timeStamp = Duration.zero}) {
    assert(isDown);
    _isDown = false;
    return PointerCancelEvent(
      timeStamp: timeStamp,
      kind: kind,
      pointer: pointer,
      position: location,
    );
  }

  /// Create a [PointerHoverEvent] to the given location.
  ///
  /// By default, the time stamp on the event is [Duration.zero]. You can give a
  /// specific time stamp by passing the `timeStamp` argument.
  ///
  /// [isDown] must be false, since hover events can't be sent when the pointer
  /// is up.
  PointerHoverEvent hover(
    Offset newLocation, {
    Duration timeStamp = Duration.zero,
  }) {
    assert(newLocation != null);
    assert(timeStamp != null);
    assert(
        !isDown,
        'Hover events can only be generated when the pointer is up. To '
        'simulate movement when the pointer is down, use move() instead.');
    assert(kind != PointerDeviceKind.touch, "Touch pointers can't generate hover events");
    final Offset delta = location != null ?  newLocation - location : Offset.zero;
    _location = newLocation;
    return PointerHoverEvent(
      timeStamp: timeStamp,
      kind: kind,
      position: newLocation,
      delta: delta,
    );
  }

  /// Create a [PointerScrollEvent] (e.g., scroll wheel scroll; not finger-drag
  /// scroll) with the given delta.
  ///
  /// By default, the time stamp on the event is [Duration.zero]. You can give a
  /// specific time stamp by passing the `timeStamp` argument.
  PointerScrollEvent scroll(
    Offset scrollDelta, {
    Duration timeStamp = Duration.zero,
  }) {
    assert(scrollDelta != null);
    assert(timeStamp != null);
    assert(kind != PointerDeviceKind.touch, "Touch pointers can't generate pointer signal events");
    return PointerScrollEvent(
      timeStamp: timeStamp,
      kind: kind,
      position: location,
      scrollDelta: scrollDelta,
    );
  }
}

/// Signature for a callback that can dispatch events and returns a future that
/// completes when the event dispatch is complete.
typedef EventDispatcher = Future<void> Function(PointerEvent event, HitTestResult result);

/// Signature for callbacks that perform hit-testing at a given location.
typedef HitTester = HitTestResult Function(Offset location);

/// A class for performing gestures in tests.
///
/// The simplest way to create a [TestGesture] is to call
/// [WidgetTester.startGesture].
class TestGesture {
  /// Create a [TestGesture] without dispatching any events from it.
  /// The [TestGesture] can then be manipulated to perform future actions.
  ///
  /// By default, the pointer identifier used is 1. This can be overridden by
  /// providing the `pointer` argument.
  ///
  /// A function to use for hit testing must be provided via the `hitTester`
  /// argument, and a function to use for dispatching events must be provided
  /// via the `dispatcher` argument.
  ///
  /// The device `kind` defaults to [PointerDeviceKind.touch], but move events
  /// when the pointer is "up" require a kind other than
  /// [PointerDeviceKind.touch], like [PointerDeviceKind.mouse], for example,
  /// because touch devices can't produce movement events when they are "up".
  ///
  /// None of the arguments may be null. The `dispatcher` and `hitTester`
  /// arguments are required.
  TestGesture({
    @required EventDispatcher dispatcher,
    @required HitTester hitTester,
    int pointer = 1,
    PointerDeviceKind kind = PointerDeviceKind.touch,
    int buttons = kPrimaryButton,
  }) : assert(dispatcher != null),
       assert(hitTester != null),
       assert(pointer != null),
       assert(kind != null),
       assert(buttons != null),
       _dispatcher = dispatcher,
       _hitTester = hitTester,
       _pointer = TestPointer(pointer, kind, buttons),
       _result = null;

  /// Dispatch a pointer down event at the given `downLocation`, caching the
  /// hit test result.
  Future<void> down(Offset downLocation) async {
    return TestAsyncUtils.guard<void>(() async {
      _result = _hitTester(downLocation);
      return _dispatcher(_pointer.down(downLocation), _result);
    });
  }

  /// Dispatch a pointer down event at the given `downLocation`, caching the
  /// hit test result with a custom down event.
  Future<void> downWithCustomEvent(Offset downLocation, PointerDownEvent event) async {
    _pointer.setDownInfo(event, downLocation);
    return TestAsyncUtils.guard<void>(() async {
      _result = _hitTester(downLocation);
      return _dispatcher(event, _result);
    });
  }

  final EventDispatcher _dispatcher;
  final HitTester _hitTester;
  final TestPointer _pointer;
  HitTestResult _result;

  /// In a test, send a move event that moves the pointer by the given offset.
  @visibleForTesting
  Future<void> updateWithCustomEvent(PointerEvent event, { Duration timeStamp = Duration.zero }) {
    _pointer.setDownInfo(event, event.position);
    return TestAsyncUtils.guard<void>(() {
      return _dispatcher(event, _result);
    });
  }

  /// Send a move event moving the pointer by the given offset.
  ///
  /// If the pointer is down, then a move event is dispatched. If the pointer is
  /// up, then a hover event is dispatched. Touch devices are not able to send
  /// hover events.
  Future<void> moveBy(Offset offset, {Duration timeStamp = Duration.zero}) {
    return moveTo(_pointer.location + offset, timeStamp: timeStamp);
  }

  /// Send a move event moving the pointer to the given location.
  ///
  /// If the pointer is down, then a move event is dispatched. If the pointer is
  /// up, then a hover event is dispatched. Touch devices are not able to send
  /// hover events.
  Future<void> moveTo(Offset location, {Duration timeStamp = Duration.zero}) {
    return TestAsyncUtils.guard<void>(() {
      if (_pointer._isDown) {
        assert(_result != null,
            'Move events with the pointer down must be preceeded by a down '
            'event that captures a hit test result.');
        return _dispatcher(_pointer.move(location, timeStamp: timeStamp), _result);
      } else {
        assert(_pointer.kind != PointerDeviceKind.touch,
            'Touch device move events can only be sent if the pointer is down.');
        return _dispatcher(_pointer.hover(location, timeStamp: timeStamp), null);
      }
    });
  }

  /// End the gesture by releasing the pointer.
  Future<void> up() {
    return TestAsyncUtils.guard<void>(() async {
      assert(_pointer._isDown);
      await _dispatcher(_pointer.up(), _result);
      assert(!_pointer._isDown);
      _result = null;
    });
  }

  /// End the gesture by canceling the pointer (as would happen if the
  /// system showed a modal dialog on top of the Flutter application,
  /// for instance).
  Future<void> cancel() {
    return TestAsyncUtils.guard<void>(() async {
      assert(_pointer._isDown);
      await _dispatcher(_pointer.cancel(), _result);
      assert(!_pointer._isDown);
      _result = null;
    });
  }
}
