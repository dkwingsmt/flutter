// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show window;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('provides a value to the layer tree', (WidgetTester tester) async {
    await tester.pumpWidget(
      const AnnotatedRegion<int>(
        child: SizedBox(width: 100.0, height: 100.0),
        value: 1,
      ),
    );
    final List<Layer> layers = tester.layers;
    final AnnotatedRegionLayer<int> layer = layers.whereType<AnnotatedRegionLayer<int>>().first;
    expect(layer.value, 1);
  });
  testWidgets('provides a value to the layer tree in a particular region', (WidgetTester tester) async {
    await tester.pumpWidget(
      Transform.translate(
        offset: const Offset(25.0, 25.0),
        child: const AnnotatedRegion<int>(
          child: SizedBox(width: 100.0, height: 100.0),
          value: 1,
        ),
      ),
    );
    int result = RendererBinding.instance.renderView.debugLayer.find<int>(Offset(
      10.0 * window.devicePixelRatio,
      10.0 * window.devicePixelRatio,
    ));
    expect(result, null);
    result = RendererBinding.instance.renderView.debugLayer.find<int>(Offset(
      50.0 * window.devicePixelRatio,
      50.0 * window.devicePixelRatio,
    ));
    expect(result, 1);
  });
  testWidgets('provides a value to the annotation tree in a particular region', (WidgetTester tester) async {
    await tester.pumpWidget(
      Transform.translate(
        offset: const Offset(25.0, 25.0),
        child: const AnnotatedRegion<int>(
          child: SizedBox(width: 100.0, height: 100.0),
          value: 1,
        ),
      ),
    );
    AnnotationEntry<int> result = RendererBinding.instance.renderView.searchFirst<int>(const Offset(10.0, 10.0));
    expect(result, isNull);
    result = RendererBinding.instance.renderView.searchFirst<int>(const Offset(50.0, 50.0));
    expect(result, isNotNull);
    expect(result.annotation, 1);
  });
}
