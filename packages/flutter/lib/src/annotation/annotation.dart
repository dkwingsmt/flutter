// Copyright 2020 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Offset, Rect, RRect, Path, hashValues;

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

typedef AnnotationSearch<S> = bool Function(AnnotationResult<S> result, Offset localPosition);

/// Information collected for an annotation that is found in the Annotator tree.
///
/// See also:
///
///  * [Annotator.findAnnotations], which create and use objects of this class.
@immutable
class AnnotationEntry<T> {
  /// Create an entry of found annotation by providing the object and related
  /// information.
  const AnnotationEntry({
    @required this.annotation,
    @required this.localPosition,
  }) : assert(localPosition != null);

  /// The annotation object that is found.
  final T annotation;

  /// The target location described by the local coordinate space of the Annotator
  /// that contains the annotation.
  final Offset localPosition;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is AnnotationEntry<T>
        && other.annotation == annotation
        && other.localPosition == localPosition;
  }

  @override
  int get hashCode {
    return hashValues(annotation, localPosition);
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, 'AnnotationEntry')}(annotation: $annotation, localPostion: $localPosition)';
  }
}

/// Information collected about a list of annotations that are found in the
/// Annotator tree.
///
/// See also:
///
///  * [AnnotationEntry], which are members of this class.
///  * [Annotator.findAllAnnotations], and [Annotator.findAnnotations], which create and
///    use an object of this class.
class AnnotationResult<T> {
  AnnotationResult({this.onlyFirst = false});

  final bool onlyFirst;

  /// Add a new entry to the end of the result.
  ///
  /// Usually, entries should be added in order from most specific to least
  /// specific, typically during an upward walk of the tree.
  void add(AnnotationEntry<T> entry) => _entries.add(entry);

  /// An unmodifiable list of [AnnotationEntry] objects recorded.
  ///
  /// The first entry is the most specific, typically the one at the leaf of
  /// tree.
  Iterable<AnnotationEntry<T>> get entries => _entries;

  /// An unmodifiable list of annotations recorded.
  ///
  /// The first entry is the most specific, typically the one at the leaf of
  /// tree.
  ///
  /// It is similar to [entries] but does not contain other information.
  Iterable<T> get annotations sync* {
    for (final AnnotationEntry<T> entry in _entries)
      yield entry.annotation;
  }
  final List<AnnotationEntry<T>> _entries = <AnnotationEntry<T>>[];
}

// abstract class Annotatable {
//   AnnotationResult<S> findAllAnnotations<S>(Offset localPosition);
// }

abstract class Annotator extends AbstractNode with DiagnosticableTreeMixin {
  @override
  ContainerAnnotator get parent => super.parent as ContainerAnnotator;

  /// This Annotator's next sibling in the parent Annotator's child list.
  Annotator get nextSibling => _nextSibling;
  Annotator _nextSibling;

  /// This Annotator's previous sibling in the parent Annotator's child list.
  Annotator get previousSibling => _previousSibling;
  Annotator _previousSibling;

  @mustCallSuper
  void remove() {
    parent?._removeChild(this);
  }

  bool search<S>(AnnotationResult<S> result, Offset localPosition);
}

abstract class ContainerAnnotator extends Annotator {
  /// The first composited Annotator in this Annotator's child list.
  Annotator get firstChild => _firstChild;
  Annotator _firstChild;

  /// The last composited Annotator in this Annotator's child list.
  Annotator get lastChild => _lastChild;
  Annotator _lastChild;

  /// Returns whether this Annotator has at least one child Annotator.
  bool get hasChildren => _firstChild != null;

  @override
  void attach(Object owner) {
    super.attach(owner);
    Annotator child = firstChild;
    while (child != null) {
      child.attach(owner);
      child = child.nextSibling;
    }
  }

  @override
  void detach() {
    super.detach();
    Annotator child = firstChild;
    while (child != null) {
      child.detach();
      child = child.nextSibling;
    }
  }

  /// Adds the given Annotator to the end of this Annotator's child list.
  void append(Annotator child) {
    assert(child != this);
    assert(child != firstChild);
    assert(child != lastChild);
    assert(child.parent == null);
    assert(!child.attached);
    assert(child.nextSibling == null);
    assert(child.previousSibling == null);
    assert(() {
      Annotator node = this;
      while (node.parent != null)
        node = node.parent;
      assert(node != child); // indicates we are about to create a cycle
      return true;
    }());
    adoptChild(child);
    child._previousSibling = lastChild;
    if (lastChild != null)
      lastChild._nextSibling = child;
    _lastChild = child;
    _firstChild ??= child;
    assert(child.attached == attached);
  }

  // Implementation of [Annotator.remove].
  void _removeChild(Annotator child) {
    assert(child.parent == this);
    assert(child.attached == attached);
    // assert(_debugUltimatePreviousSiblingOf(child, equals: firstChild));
    // assert(_debugUltimateNextSiblingOf(child, equals: lastChild));
    if (child._previousSibling == null) {
      assert(_firstChild == child);
      _firstChild = child._nextSibling;
    } else {
      child._previousSibling._nextSibling = child.nextSibling;
    }
    if (child._nextSibling == null) {
      assert(lastChild == child);
      _lastChild = child.previousSibling;
    } else {
      child.nextSibling._previousSibling = child.previousSibling;
    }
    assert((firstChild == null) == (lastChild == null));
    assert(firstChild == null || firstChild.attached == attached);
    assert(lastChild == null || lastChild.attached == attached);
    // assert(firstChild == null || _debugUltimateNextSiblingOf(firstChild, equals: lastChild));
    // assert(lastChild == null || _debugUltimatePreviousSiblingOf(lastChild, equals: firstChild));
    child._previousSibling = null;
    child._nextSibling = null;
    dropChild(child);
    assert(!child.attached);
  }

  /// Removes all of this Annotator's children from its child list.
  void removeAllChildren() {
    Annotator child = firstChild;
    while (child != null) {
      final Annotator next = child.nextSibling;
      child._previousSibling = null;
      child._nextSibling = null;
      assert(child.attached == attached);
      dropChild(child);
      child = next;
    }
    _firstChild = null;
    _lastChild = null;
  }

  @override
  bool search<S>(AnnotationResult<S> result, Offset localPosition) {
    for (Annotator child = lastChild; child != null; child = child.previousSibling) {
      final bool isAbsorbed = child.search<S>(result, localPosition);
      if (isAbsorbed)
        return true;
      if (result.onlyFirst && result.entries.isNotEmpty)
        return isAbsorbed;
    }
    return false;
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final List<DiagnosticsNode> children = <DiagnosticsNode>[];
    if (firstChild == null)
      return children;
    Annotator child = firstChild;
    int count = 1;
    while (true) {
      children.add(child.toDiagnosticsNode(name: 'child $count'));
      if (child == lastChild)
        break;
      count += 1;
      child = child.nextSibling;
    }
    return children;
  }
}

class OffsetAnnotator extends ContainerAnnotator {
  OffsetAnnotator({this.offset = Offset.zero});

  // TODO(dkwingsmt): aftermath of mutable?
  Offset offset;

  @override
  bool search<S>(AnnotationResult<S> result, Offset localPosition) {
    return super.search(result, localPosition - offset);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('offset', offset, defaultValue: null));
  }
}

class TransformAnnotator extends OffsetAnnotator {
  TransformAnnotator({this.transform, Offset offset = Offset.zero});

  final Matrix4 transform;

  Matrix4 _invertedTransform;
  bool _inverseDirty = true;

  Offset _transformOffset(Offset localPosition) {
    if (_inverseDirty) {
      _invertedTransform = Matrix4.tryInvert(
        removePerspectiveTransform(transform)
      );
      _inverseDirty = false;
    }
    if (_invertedTransform == null)
      return null;

    return transformPoint(_invertedTransform, localPosition);
  }

  @override
  bool search<S>(AnnotationResult<S> result, Offset localPosition) {
    final Offset transformedOffset = _transformOffset(localPosition);
    if (transformedOffset == null)
      return false;
    return super.search<S>(result, transformedOffset);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Matrix4>('transform', transform, defaultValue: null));
  }

  // TODO(dkwingsmt): This function is copied from MatrixUtils. Resolve this
  // duplication.
  /// Applies the given matrix as a perspective transform to the given point.
  ///
  /// This function assumes the given point has a z-coordinate of 0.0. The
  /// z-coordinate of the result is ignored.
  static Offset transformPoint(Matrix4 transform, Offset point) {
    final Float64List storage = transform.storage;
    final double x = point.dx;
    final double y = point.dy;

    // Directly simulate the transform of the vector (x, y, 0, 1),
    // dropping the resulting Z coordinate, and normalizing only
    // if needed.

    final double rx = storage[0] * x + storage[4] * y + storage[12];
    final double ry = storage[1] * x + storage[5] * y + storage[13];
    final double rw = storage[3] * x + storage[7] * y + storage[15];
    if (rw == 1.0) {
      return Offset(rx, ry);
    } else {
      return Offset(rx / rw, ry / rw);
    }
  }

  // TODO(dkwingsmt): This function is copied from PointerEvent. Resolve this
  // duplication.
  /// Removes the "perspective" component from `transform`.
  ///
  /// When applying the resulting transform matrix to a point with a
  /// z-coordinate of zero (which is generally assumed for all points
  /// represented by an [Offset]), the other coordinates will get transformed as
  /// before, but the new z-coordinate is going to be zero again. This is
  /// achieved by setting the third column and third row of the matrix to
  /// "0, 0, 1, 0".
  static Matrix4 removePerspectiveTransform(Matrix4 transform) {
    final Vector4 vector = Vector4(0, 0, 1, 0);
    return transform.clone()
      ..setColumn(2, vector)
      ..setRow(2, vector);
  }
}

abstract class ClipAnnotator extends ContainerAnnotator {
  bool contains(Offset localPosition);

  @override
  bool search<S>(AnnotationResult<S> result, Offset localPosition) {
    if (!contains(localPosition))
      return false;
    return super.search(result, localPosition);
  }
}

class ClipRectAnnotator extends ClipAnnotator {
  ClipRectAnnotator({this.clipRect});

  final Rect clipRect;

  @override
  bool contains(ui.Offset localPosition) => clipRect.contains(localPosition);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Rect>('clipRect', clipRect));
  }
}

class ClipRRectAnnotator extends ClipAnnotator {
  ClipRRectAnnotator({this.clipRRect});

  final RRect clipRRect;

  @override
  bool contains(ui.Offset localPosition) => clipRRect.contains(localPosition);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<RRect>('clipRRect', clipRRect));
  }
}

class ClipPathAnnotator extends ClipAnnotator {
  ClipPathAnnotator({this.clipPath});

  final Path clipPath;

  @override
  bool contains(ui.Offset localPosition) => clipPath.contains(localPosition);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Path>('clipPath', clipPath));
  }
}

class SingleTypeAnnotator<T> extends ContainerAnnotator {
  SingleTypeAnnotator(this.onSearch, this.offset, {this.debugOwner});

  final AnnotationSearch<T> onSearch;
  final Offset offset;

  @override
  bool search<S>(AnnotationResult<S> result, Offset localPosition) {
    final bool absorbedByChildren = super.search(result, localPosition);
    if (result.entries.isNotEmpty && result.onlyFirst)
      return absorbedByChildren;
    if (T != S)
      return absorbedByChildren;
    final AnnotationResult<T> typedResult = result as AnnotationResult<T>;
    final bool absorbedBySelf = onSearch(typedResult, localPosition - offset);
    return absorbedByChildren || absorbedBySelf;
  }

  /// The annotator's owner.
  ///
  /// This is used in the [toString] serialization to report the object for which
  /// this annotator was created, to aid in debugging.
  final Object debugOwner;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('offset', offset, defaultValue: null));
    properties.add(DiagnosticsProperty<Object>('debugOwner', debugOwner, defaultValue: null));
  }
}
