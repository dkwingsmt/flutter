// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

const String _kTestChannel = 'test';

void main() {
  // test('Should works on platforms that has not implemented ', () async {
  //   TestWidgetsFlutterBinding.ensureInitialized();
  //   final MethodChannel mockChannel = const OptionalMethodChannel(_kTestChannel)
  //     ..setMockMethodCallHandler((MethodCall call) async => null);

  //   expect(
  //     await manager.activateShape(const MouseCursorDelegateActivateShapeDetails(
  //       device: 10,
  //       shape: 100,
  //     )),
  //     isTrue,
  //   );
  // });

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

    mockChannel.setMockMethodCallHandler((MethodCall call) async {
      logs.add(call);
      throw PlatformException(
        code: UnsupportedFeature.kErrorCode,
        message: 'mock details',
      );
    });
    await expectLater(
      MouseCursorController.activateShape(device: 11, shape: 101),
      throwsA(_UnsupportedFeatureMatcher(UnsupportedFeature('mock details'))),
    );
    expectMethodCallsEquals(logs, const <MethodCall>[
      MethodCall('activateShape', <String, dynamic>{'device': 11, 'shape': 101}),
    ]);
    logs.clear();

    mockChannel.setMockMethodCallHandler((MethodCall call) async {
      logs.add(call);
      throw ArgumentError('some error');
    });
    await expectLater(
      MouseCursorController.activateShape(device: 12, shape: 102),
      throwsA(isInstanceOf<PlatformException>()),
    );
    expectMethodCallsEquals(logs, const <MethodCall>[
      MethodCall('activateShape', <String, dynamic>{'device': 12, 'shape': 102}),
    ]);
    logs.clear();
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
  _UnsupportedFeatureMatcher(this._expected);

  final UnsupportedFeature _expected;

  @override
  bool matches(dynamic untypedItem, Map<dynamic, dynamic> matchState) {
    return untypedItem is UnsupportedFeature
        && untypedItem.message == _expected.message
        && untypedItem.details == _expected.details;
  }

  @override
  Description describe(Description description) {
    return description
      .addDescriptionOf(_expected);
  }

  @override
  Description describeMismatch(
    dynamic untypedItem,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (untypedItem is! UnsupportedFeature) {
      return mismatchDescription
        .add('is type ${untypedItem.runtimeType} instead of UnsupportedFeature');
    }
    final UnsupportedFeature item = untypedItem as UnsupportedFeature;
    if (item.message != _expected.message) {
      return mismatchDescription
        .add('has message ${item.message} instead of ${_expected.message}');
    } else if (item.details != _expected.details) {
      return mismatchDescription
        .add('has details ${item.details} instead of ${_expected.details}');
    }
    return mismatchDescription;
  }
}
