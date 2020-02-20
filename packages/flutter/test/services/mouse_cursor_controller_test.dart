// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Should work on platforms that does not support mouse cursor', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final MethodChannel mockChannel = SystemChannels.mouseCursor;

    mockChannel.setMockMethodCallHandler((MethodCall call) async {
      return null;
    });

    await MouseCursorController.activateShape(device: 10, shape: 100);

    // Passes if no errors are thrown
  });

  test('activateShape should correctly pass argument', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final List<MethodCall> logs = <MethodCall>[];
    final MethodChannel mockChannel = SystemChannels.mouseCursor;

    mockChannel.setMockMethodCallHandler((MethodCall call) async {
      logs.add(call);
      return true;
    });
    await MouseCursorController.activateShape(device: 10, shape: 100);
    expectMethodCallsEquals(logs, const <MethodCall>[
      MethodCall('activateShape', <String, dynamic>{'device': 10, 'shape': 100}),
    ]);
    logs.clear();

  });

  test('Should throw a PlatformException of unsupported feature when told so', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final MethodChannel mockChannel = SystemChannels.mouseCursor;

    mockChannel.setMockMethodCallHandler((MethodCall call) async {
      throw PlatformException(
        code: MouseCursorController.kUnsupportedFeatureCode,
        message: 'mock details',
      );
    });
    await expectLater(
      MouseCursorController.activateShape(device: 11, shape: 101),
      throwsA(_UnsupportedFeatureMatcher(
        message: 'mock details',
      )),
    );
  });

  test('Should throw a PlatformException when an error occurs', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final MethodChannel mockChannel = SystemChannels.mouseCursor;

    mockChannel.setMockMethodCallHandler((MethodCall call) async {
      throw ArgumentError('some error');
    });
    await expectLater(
      MouseCursorController.activateShape(device: 12, shape: 102),
      throwsA(isInstanceOf<PlatformException>()));
  });
}

void expectMethodCallsEquals(dynamic subject, List<MethodCall> target) {
  expect(subject is List<MethodCall>, true);
  final List<MethodCall> list = subject as List<MethodCall>;
  expect(list.length, target.length);
  for (int i = 0; i < list.length; i++) {
    expect(list[i].method, target[i].method);
    expect(list[i].arguments, equals(target[i].arguments));
  }
}

class _UnsupportedFeatureMatcher extends Matcher {
  _UnsupportedFeatureMatcher({this.message, this.details});

  final String message;
  final dynamic details;

  @override
  bool matches(dynamic untypedItem, Map<dynamic, dynamic> matchState) {
    return untypedItem is PlatformException
        && MouseCursorController.isUnsupportedFeature(untypedItem)
        && untypedItem.message == message
        && untypedItem.details == details;
  }

  @override
  Description describe(Description description) {
    description
      .add('indicates unsupported feature with message: ').addDescriptionOf(message);
    if (details != null)
      description.add('and details: ').addDescriptionOf(details);
    return description;
  }

  @override
  Description describeMismatch(
    dynamic untypedItem,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (!MouseCursorController.isUnsupportedFeature(untypedItem)) {
      mismatchDescription.add('does not indicate unsupported feature, because it is type ${untypedItem.runtimeType}');
      if (untypedItem is PlatformException)
        mismatchDescription.add(' with code ${untypedItem.code}');
      return mismatchDescription;
    }
    final PlatformException item = untypedItem as PlatformException;
    if (item.message != message) {
      return mismatchDescription
        .add('has message ${item.message} instead of $message');
    } else if (item.details != details) {
      return mismatchDescription
        .add('has details ${item.details} instead of $details');
    }
    return mismatchDescription;
  }
}
