// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

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
