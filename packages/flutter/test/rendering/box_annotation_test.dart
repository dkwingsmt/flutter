// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rendering_tester.dart';

void main() {
  test('Single object - empty', () {
    final RenderBox root = _EmptyLeaf();
    expect(root.debugNeedsAnnotate, true);
    layout(root);
    expect(root.debugNeedsAnnotate, true);
    final HashSet<Type> rootAnnotations = root.subtreeAnnotations();
    expect(rootAnnotations, isNull);
    expect(root.debugNeedsAnnotate, false);
    final BoxHitTestResult result = _createResult<ValueTarget<int>>();
    final bool isHit = root.hitTest(result, position: Offset.zero);
    expect(isHit, false);
    expect(result, isEmpty);
  });

  test('Single object - value', () {
    final RenderBox root = _ValueLeaf<int>(101);
    layout(root);
    expect(root.subtreeAnnotations(), _exactlyOneType<ValueTarget<int>>());
    final BoxHitTestResult result = _createResult<ValueTarget<int>>();
    final bool isHit = root.hitTest(result, position: Offset.zero);
    expect(isHit, true);
    expect(_getValues<int>(result), <int>[101]);
  });

  test('Row with one child', () {
    final RenderBox child = _ValueLeaf<int>(101, size: const Size(10, 10));
    final RenderBox root = _BasicRow(
      children: <RenderBox>[
        child,
      ],
    );
    expect(root.debugNeedsAnnotate, true);
    layout(root);
    expect(root.debugNeedsAnnotate, true);
    final HashSet<Type> rootAnnotations = root.subtreeAnnotations();
    expect(rootAnnotations, _exactlyOneType<ValueTarget<int>>());
    expect(identical(rootAnnotations, child.subtreeAnnotations()), true);
    expect(root.debugNeedsAnnotate, false);
    final BoxHitTestResult result = _createResult<ValueTarget<int>>();
    final bool isHit = root.hitTest(result, position: Offset.zero);
    expect(isHit, true);
    expect(_getValues<int>(result), <int>[101]);
  });

  test('Row with multiple children', () {
    final RenderBox root = _BasicRow(
      children: <RenderBox>[
        _ValueLeaf<int>(101, size: const Size(10, 10)),
        _ValueLeaf<String>('123', size: const Size(10, 10)),
      ],
    );
    layout(root);
    final HashSet<Type> rootAnnotations = root.subtreeAnnotations();
    expect(rootAnnotations, _exactlyTwoTypes<ValueTarget<int>, ValueTarget<String>>());
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: Offset.zero);
      expect(isHit, true);
      expect(_getValues<int>(result), <int>[101]);
    }

    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(20, 10));
      expect(isHit, false);
      expect(result, isEmpty);
    }

    {
      final BoxHitTestResult result = _createResult<ValueTarget<String>>();
      final bool isHit = root.hitTest(result, position: const Offset(19, 9));
      expect(isHit, true);
      expect(_getValues<String>(result), <String>['123']);
    }
  });

  test('Row with no child', () {
    final RenderBox root = _BasicRow(
      children: <RenderBox>[],
    );
    layout(root);
    final HashSet<Type> rootAnnotations = root.subtreeAnnotations();
    expect(rootAnnotations, isNull);
    final BoxHitTestResult result = _createResult<ValueTarget<int>>();
    final bool isHit = root.hitTest(result, position: Offset.zero);
    expect(isHit, false);
    expect(result, isEmpty);
  });

  test('Stack - opaque front', () {
    final RenderBox root = _BasicStack(
      children: <RenderBox>[
        _ValueLeaf<int>(101, size: const Size(30, 30), opaque: false),
        _ValueLeaf<int>(202, size: const Size(20, 20), opaque: true),
        _ValueLeaf<String>('123', size: const Size(10, 10), opaque: true),
      ],
    );
    layout(root);
    final HashSet<Type> rootAnnotations = root.subtreeAnnotations();
    expect(rootAnnotations, _exactlyTwoTypes<ValueTarget<int>, ValueTarget<String>>());
    // Hit nothing.
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(39, 1));
      expect(isHit, false);
      expect(result, isEmpty);
    }

    // Only hit the bottom one.
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(29, 1));
      expect(isHit, false);
      expect(_getValues<int>(result), <int>[101]);
    }

    // Hit the bottom two.
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(19, 1));
      expect(isHit, true);
      expect(_getValues<int>(result), <int>[202]);
    }

    // Hit all three.
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(9, 1));
      expect(isHit, true);
      expect(result, isEmpty);
    }
  });

  test('Stack - transparent front', () {
    final RenderBox root = _BasicStack(
      children: <RenderBox>[
        _ValueLeaf<int>(101, size: const Size(30, 30), opaque: false),
        _ValueLeaf<int>(202, size: const Size(20, 20), opaque: false),
        _ValueLeaf<String>('123', size: const Size(10, 10), opaque: false),
      ],
    );
    layout(root);
    final HashSet<Type> rootAnnotations = root.subtreeAnnotations();
    expect(rootAnnotations, _exactlyTwoTypes<ValueTarget<int>, ValueTarget<String>>());
    // Hit nothing.
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(39, 1));
      expect(isHit, false);
      expect(result, isEmpty);
    }

    // Only hit the bottom one.
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(29, 1));
      expect(isHit, false);
      expect(_getValues<int>(result), <int>[101]);
    }

    // Hit the bottom two.
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(19, 1));
      expect(isHit, false);
      expect(_getValues<int>(result), <int>[202, 101]);
    }

    // Hit all three.
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(9, 1));
      expect(isHit, false);
      expect(_getValues<int>(result), <int>[202, 101]);
    }
  });

  test('Row keeps opacity from unrelated type', () {
    final RenderBox root = _BasicStack(
      children: <RenderBox>[
        _ValueLeaf<int>(101, size: const Size(100, 100), opaque: false),
        _BasicRow(
          children: <RenderBox>[
            _ValueLeaf<String>('123', size: const Size(10, 10), opaque: true),
          ],
        ),
      ],
    );
    layout(root);
    final HashSet<Type> rootAnnotations = root.subtreeAnnotations();
    expect(rootAnnotations, _exactlyTwoTypes<ValueTarget<int>, ValueTarget<String>>());
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(19, 1));
      expect(isHit, false);
      expect(_getValues<int>(result), <int>[101]);
    }

    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(9, 1));
      expect(isHit, true);
      expect(result, isEmpty);
    }
  });

  test('Toggleable child - default enabled', () {
    final _ToggleableValueLeaf<int> child = _ToggleableValueLeaf<int>(
      101,
      size: const Size(10, 10),
      opaque: true,
      enabled: true,
    );
    final RenderBox root = _BasicStack(
      children: <RenderBox>[
        _ValueLeaf<String>('123', size: const Size(100, 100), opaque: false),
        _BasicRow(children: <RenderBox>[child]),
      ],
    );
    layout(root);
    final HashSet<Type> rootAnnotations = root.subtreeAnnotations();
    expect(child.debugNeedsAnnotate, false);
    expect(root.debugNeedsAnnotate, false);
    expect(rootAnnotations, _exactlyTwoTypes<ValueTarget<int>, ValueTarget<String>>());
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: Offset.zero);
      expect(isHit, true);
      expect(_getValues<int>(result), <int>[101]);
    }

    child.enabled = false;
    expect(child.debugNeedsAnnotate, true);
    expect(root.debugNeedsAnnotate, true);
    final HashSet<Type> rootAnnotations2 = root.subtreeAnnotations();
    expect(child.debugNeedsAnnotate, false);
    expect(root.debugNeedsAnnotate, false);
    expect(rootAnnotations2, _exactlyOneType<ValueTarget<String>>());
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: Offset.zero);
      expect(isHit, true);
      expect(result, isEmpty);
    }

    child.enabled = true;
    expect(child.debugNeedsAnnotate, true);
    expect(root.debugNeedsAnnotate, true);
    final HashSet<Type> rootAnnotations3 = root.subtreeAnnotations();
    expect(child.debugNeedsAnnotate, false);
    expect(root.debugNeedsAnnotate, false);
    expect(rootAnnotations3, _exactlyTwoTypes<ValueTarget<int>, ValueTarget<String>>());
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: Offset.zero);
      expect(isHit, true);
      expect(_getValues<int>(result), <int>[101]);
    }
  });

  test('Toggleable child - default disabled', () {
    final _ToggleableValueLeaf<int> child = _ToggleableValueLeaf<int>(
      101,
      size: const Size(10, 10),
      opaque: true,
      enabled: false,
    );
    final RenderBox root = _BasicStack(
      children: <RenderBox>[
        _ValueLeaf<String>('123', size: const Size(100, 100), opaque: false),
        _BasicRow(children: <RenderBox>[child]),
      ],
    );
    layout(root);

    final HashSet<Type> rootAnnotations1 = root.subtreeAnnotations();
    expect(child.debugNeedsAnnotate, false);
    expect(root.debugNeedsAnnotate, false);
    expect(rootAnnotations1, _exactlyOneType<ValueTarget<String>>());
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: Offset.zero);
      expect(isHit, true);
      expect(result, isEmpty);
    }

    child.enabled = true;
    expect(child.debugNeedsAnnotate, true);
    expect(root.debugNeedsAnnotate, true);
    final HashSet<Type> rootAnnotations2 = root.subtreeAnnotations();
    expect(child.debugNeedsAnnotate, false);
    expect(root.debugNeedsAnnotate, false);
    expect(rootAnnotations2, _exactlyTwoTypes<ValueTarget<int>, ValueTarget<String>>());
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: Offset.zero);
      expect(isHit, true);
      expect(_getValues<int>(result), <int>[101]);
    }
  });

  test('ProxyBoxWithBehavior - opaque', () {
    final RenderBox root = _TopLeft(
      _AnnotatedProxy<int>(
        101,
        behavior: HitTestBehavior.opaque,
        child: _BasicRow(
          children: <RenderBox>[
            _ValueLeaf<int>(202, size: const Size(10, 10)),
            _EmptyLeaf(size: const Size(10, 10)),
            _ValueLeaf<int>(303, size: const Size(10, 10), opaque: false),
          ],
        ),
      ),
    );
    layout(root);
    final HashSet<Type> rootAnnotations = root.subtreeAnnotations();
    expect(rootAnnotations, _exactlyOneType<ValueTarget<int>>());
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(9, 1));
      expect(isHit, true);
      expect(_getValues<int>(result), <int>[202, 101]);
    }

    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(19, 1));
      expect(isHit, true);
      expect(_getValues<int>(result), <int>[101]);
    }

    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(29, 1));
      expect(isHit, true);
      expect(_getValues<int>(result), <int>[303, 101]);
    }
  });

  test('ProxyBoxWithBehavior - translucent', () {
    final RenderBox root = _TopLeft(
      _AnnotatedProxy<int>(
        101,
        behavior: HitTestBehavior.translucent,
        child: _BasicRow(
          children: <RenderBox>[
            _ValueLeaf<int>(202, size: const Size(10, 10)),
            _EmptyLeaf(size: const Size(10, 10)),
            _ValueLeaf<int>(303, size: const Size(10, 10), opaque: false),
          ],
        ),
      ),
    );
    layout(root);
    final HashSet<Type> rootAnnotations = root.subtreeAnnotations();
    expect(rootAnnotations, _exactlyOneType<ValueTarget<int>>());
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(9, 1));
      expect(isHit, true);
      expect(_getValues<int>(result), <int>[202, 101]);
    }

    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(19, 1));
      expect(isHit, false);
      expect(_getValues<int>(result), <int>[101]);
    }

    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(29, 1));
      expect(isHit, false);
      expect(_getValues<int>(result), <int>[303, 101]);
    }
  });

  test('ProxyBoxWithBehavior - deferToChild', () {
    final RenderBox root = _TopLeft(
      _AnnotatedProxy<int>(
        101,
        behavior: HitTestBehavior.deferToChild,
        child: _BasicRow(
          children: <RenderBox>[
            _ValueLeaf<int>(202, size: const Size(10, 10)),
            _EmptyLeaf(size: const Size(10, 10)),
            _ValueLeaf<int>(303, size: const Size(10, 10), opaque: false),
          ],
        ),
      ),
    );
    layout(root);
    final HashSet<Type> rootAnnotations = root.subtreeAnnotations();
    expect(rootAnnotations, _exactlyOneType<ValueTarget<int>>());
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(9, 1));
      expect(isHit, true);
      expect(_getValues<int>(result), <int>[202, 101]);
    }

    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(19, 1));
      expect(isHit, false);
      expect(result, isEmpty);
    }

    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(29, 1));
      expect(isHit, false);
      expect(_getValues<int>(result), <int>[303]);
    }
  });

  test('ProxyBoxWithBehavior - no child', () {
    final RenderBox root = _TopLeft(
      _AnnotatedProxy<int>(
        101,
        behavior: HitTestBehavior.deferToChild,
      ),
    );
    layout(root);
    final HashSet<Type> rootAnnotations = root.subtreeAnnotations();
    expect(rootAnnotations, _exactlyOneType<ValueTarget<int>>());
    {
      final BoxHitTestResult result = _createResult<ValueTarget<int>>();
      final bool isHit = root.hitTest(result, position: const Offset(9, 1));
      expect(isHit, false);
      expect(result, isEmpty);
    }
  });
}

BoxHitTestResult _createResult<T>({bool stopAfterFirstResult = false}) {
  return BoxHitTestResult.wrap(
    HitTestResult(type: T, stopAtFirstResult: stopAfterFirstResult),
  );
}

Matcher _exactlyOneType<T>() {
  return equals(HashSet<Type>()..add(T));
}

Matcher _exactlyTwoTypes<T1, T2>() {
  return equals(HashSet<Type>()..add(T1)..add(T2));
}

List<T> _getValues<T>(HitTestResult result) {
  Type typeOf<K>() => K;
  assert(typeOf<ValueTarget<T>>() == result.type, 'Called getValues<$T> on result of type ${result.type}');
  return result.path.map((HitTestEntry entry) {
    return entry.targetAs<ValueTarget<T>>().value;
  }).toList();
}

class _TopLeft extends RenderPositionedBox {
  _TopLeft(RenderBox child)
    : super(
      child: child,
      alignment: Alignment.topLeft,
      textDirection: TextDirection.ltr,
    );
}

// A box that is not annotated.
//
// By default it is not opaque. Set `opaque` to true to make it opaque.
class _EmptyLeaf extends RenderBox {
  _EmptyLeaf({this.hit = false, Size size}) : _size = size;

  final bool hit;
  final Size _size;

  @override
  void performLayout() {
    if (_size == null)
      super.performLayout();
    else
      size = _size;
  }

  @override
  bool hitTestSelf(Offset position) => hit;

  @override
  bool get sizedByParent => _size == null;
}

// A box that contains a value.
//
// By default it is opaque. Set `opaque` to false to make it transparent.
class _ValueLeaf<T> extends RenderBox
  with ValueTarget<T>,
       SingleAnnotationRenderObject<ValueTarget<T>> {
  _ValueLeaf(this.value, {this.opaque = true, Size size}) : _size = size;

  @override
  T value;

  final bool opaque;
  final Size _size;

  @override
  void performLayout() {
    if (_size == null)
      super.performLayout();
    else
      size = _size;
  }

  @override
  bool hitTest(BoxHitTestResult result, {Offset position}) {
    return super.hitTest(result, position: position) && opaque;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool get sizedByParent => _size == null;
}

// A box that contains a value that can be diabled and enabled.
//
// By default it is opaque. Set `opaque` to false to make it transparent.
//
// It will still be opaque (if opaque is true) even when disalbed.
class _ToggleableValueLeaf<T> extends RenderBox
  with ValueTarget<T>,
       SingleAnnotationRenderObject<ValueTarget<T>> {
  _ToggleableValueLeaf(this.value, {this.opaque = true, Size size, bool enabled})
    : _size = size,
      _enabled = enabled;

  @override
  T value;

  final bool opaque;
  final Size _size;
  bool get enabled => _enabled;
  bool _enabled;
  set enabled(bool value) {
    if (_enabled != value) {
      _enabled = value;
      markNeedsAnnotate();
    }
  }

  @override
  void performLayout() {
    if (_size == null)
      super.performLayout();
    else
      size = _size;
  }

  @override
  bool hitTest(BoxHitTestResult result, {Offset position}) {
    return super.hitTest(result, position: position) && opaque;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  HashSet<Type> get selfAnnotations => _enabled ? super.selfAnnotations : null;

  @override
  bool get sizedByParent => _size == null;
}

// Layouts its children in a row aligned at the top left.
//
// Used to test behavior of a container with non-overlapping children.
class _BasicRow extends RenderFlex {
  _BasicRow({List<RenderBox> children})
    : super(
        direction: Axis.horizontal,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.ltr,
        verticalDirection: VerticalDirection.down,
        textBaseline: TextBaseline.alphabetic,
        children: children,
      );
}

// Layouts its children in a stack aligned at the top left.
//
// Used to test behavior of a container with overlapping children.
class _BasicStack extends RenderStack {
  _BasicStack({List<RenderBox> children})
    : super(
        textDirection: TextDirection.ltr,
        children: children,
      );
}

class _AnnotatedProxy<T> extends RenderProxyBoxWithHitTestBehavior
  with ValueTarget<T>,
       SingleAnnotationRenderObject<ValueTarget<T>> {
  _AnnotatedProxy(this.value, {RenderBox child, HitTestBehavior behavior})
    : super(child: child, behavior: behavior);

  @override
  final T value;

  @override
  void performResize() {
    size = constraints.biggest;
  }
}
