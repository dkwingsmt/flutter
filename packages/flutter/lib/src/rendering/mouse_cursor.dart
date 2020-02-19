// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show hashValues, Image;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';

/// A mouse cursor that does when activated.
///
/// This class is used as [SystemMouseCursors.releaseControl], which tells
/// more about its usage.
class NoopMouseCursor extends PreparedMouseCursor {
  /// Create a [NoopMouseCursor].
  const NoopMouseCursor();
}

/// A mouse cursor that comes with the system that the program is running on.
///
/// System cursors are the most commonly used cursors, since they are avaiable
/// without external resources, and matches the experience of native apps.
/// Examples of system cursors are a pointing arrow, a pointing hand, a double
/// arrow for resizing, or a text I-beam, etc. [SystemMouseCursors] enumerates
/// the complete set of system cursors supported by Flutter.
///
/// Same or similar system cursors from each platform are grouped under the same
/// name, and assigned with a constant integer [shape]. Since every platform
/// provides a different set of system cursors, multiple [shape]s might refer to
/// the same system cursor on some platforms.
///
/// The exact value of a [shape] is intentionally random, and its interpretation
/// (i.e. corresponding system cursor) is hard-coded in the platform engine.
/// Manually instantiating this class is meaningless since all supported shapes
/// have been enumerated in [SystemMouseCursors].
class SystemMouseCursor extends PreparedMouseCursor {
  // Application code shouldn't directly instantiate system mouse cursors, since
  // the supported system cursors are enumerated in [SystemMouseCursors].
  const SystemMouseCursor._({
    @required this.shape,
    @required String debugDescription,
  }) : assert(shape != null),
       assert(debugDescription != null),
       super(debugDescription: debugDescription);

  /// Identifies the kind of cursor across platforms.
  ///
  /// The exact value of [shape] is intentionally random and meaningless, and
  /// its concrete implementation is hard-coded in the platform engine.
  final int shape;

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
    properties.add(IntProperty('shape', shape));
  }
}

/// A mouse cursor that displays an image.
///
/// [ImageMouseCursor] can accepts images from various sources as long as they
/// are supported by [ImageProvider], including files, assets, network, or
/// simply memory data.
///
/// [ImageMouseCursor] can be used directly on [MouseRegion] or other supporting
/// widgets, although there might be a delay when the cursor is first activated.
/// The delay is due to the preparation needed for the cursor, including loading
/// the image and registering it with the Flutter engine, and the preparation is
/// not started until the first activation. The cursor will shown as
/// [MouseCursorManager.defaultCursor] during the preparation, and automatically
/// updated after that. Internally, the preparation generates a
/// [PreparedImageMouseCursor] out of the [ImageMouseCursor] and caches it
/// globally.
///
/// You can remove the first-activation delay by manually calling
/// [precacheImageMouseCursor] to prepare it beforehand.
///
/// See also:
///
///  * [ImageProvider], which describes loading an image in Flutter.
///  * [ImageMouseCursorCache], which caches the prepared image mouse cursors.
///  * [precacheImageMouseCursor], which prepares the image mouse cursor
///    beforehand and therefore removes the delay on the first activation of the
///    cursor.
class ImageMouseCursor extends MouseCursor {
  /// Create a mouse cursor that displays an image.
  ///
  /// To show an image from a specific source, such as the network, consider
  /// using the corresponding constuctor, such as [ImageMouseCursor.network].
  ///
  /// The [image] argument must not be null. The [hotSpot] defaults to the upper
  /// left corner of the image.
  const ImageMouseCursor({
    @required this.image,
    this.hotSpot = Offset.zero,
    String debugDescription,
  }) : assert(image != null),
       assert(hotSpot != null),
       super(debugDescription: debugDescription);

  /// Creates a widget that displays an image obtained from the network.
  ///
  /// The [src], and [scale] arguments must not be null. The [hotSpot] defaults
  /// to the upper left corner of the image.
  ///
  /// All network images are cached regardless of HTTP headers.
  ///
  /// An optional [headers] argument can be used to send custom HTTP headers
  /// with the image request.
  ImageMouseCursor.network(
    String src, {
    this.hotSpot = Offset.zero,
    double scale = 1.0,
    Map<String, String> headers,
    String debugDescription,
  }) : image = NetworkImage(src, scale: scale, headers: headers),
       super(debugDescription: debugDescription);

  /// The image to display.
  final ImageProvider image;

  /// The pixel on the image that the platform sees as the position of the
  /// pointer.
  ///
  /// The [hotSpot] defaults to [Offset.zero], which is the upper-left corner
  /// of the image.
  final Offset hotSpot;

  @override
  bool operator ==(dynamic other) {
    if (identical(other, this))
      return true;
    if (other.runtimeType != runtimeType)
      return false;
    return other is ImageMouseCursor
        && other.image == image
        && other.hotSpot == hotSpot;
  }

  @override
  int get hashCode => hashValues(image, hotSpot);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ImageProvider>('image', image));
    properties.add(DiagnosticsProperty<Offset>('hotSpot', hotSpot, defaultValue: null));
  }
}

class PreparedImageMouseCursor extends PreparedMouseCursor {
  const PreparedImageMouseCursor({
    @required this.imageId,
    String debugDescription,
  }) : assert(imageId != null),
       super(debugDescription: debugDescription);

  final int imageId;

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is PreparedImageMouseCursor
        && other.imageId == imageId;
  }

  @override
  int get hashCode => imageId;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('imageId', imageId));
  }
}

class StandardMouseCursorManager extends MouseCursorManager {
  StandardMouseCursorManager();

  @override
  Future<void> dispose() {
    final List<int> registeredImages = imageCursorCache.dispose();
    return Future.wait(registeredImages.map(MouseCursorController.unregisterImage));
  }

  @override
  PreparedMouseCursor get defaultCursor => SystemMouseCursors.basic;

  @override
  @protected
  Future<void> handleActivateCursor(int device, PreparedMouseCursor cursor) async {
    if (cursor is NoopMouseCursor)
      return;

    if (cursor is SystemMouseCursor)
      return MouseCursorController.activateShape(device: device, shape: cursor.shape);

    if (cursor is PreparedImageMouseCursor)
      return MouseCursorController.activateImage(device: device, imageId: cursor.imageId);

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
  static const NoopMouseCursor releaseControl = NoopMouseCursor();

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

@immutable
class ImageMouseCursorCacheKey {
  const ImageMouseCursorCacheKey({
    @required this.imageKey,
    @required this.hotSpot,
  }) : assert(imageKey != null),
       assert(hotSpot != null);

  final Object imageKey;
  final Offset hotSpot;

  @override
  bool operator ==(dynamic other) {
    if (identical(other, this))
      return true;
    if (other.runtimeType != runtimeType)
      return false;
    return other is ImageMouseCursorCacheKey
        && other.imageKey == imageKey
        && other.hotSpot == hotSpot;
  }

  @override
  int get hashCode => hashValues(imageKey, hotSpot);

  @override
  String toString() => 'ImageMouseCursorCacheKey(imageKey: $imageKey, hotSpot: $hotSpot)';
}
