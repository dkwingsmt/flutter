// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'base/context.dart';
import 'device.dart';
import 'doctor.dart';
import 'fuchsia/fuchsia_sdk.dart';
import 'ios/simulators.dart';
import 'macos/cocoapods_validator.dart';
import 'macos/xcdevice.dart';
import 'reporting/crash_reporting.dart';
import 'runner/local_engine.dart';

export 'globals_null_migrated.dart';

CrashReporter get crashReporter => context.get<CrashReporter>();
Doctor get doctor => context.get<Doctor>();
DeviceManager get deviceManager => context.get<DeviceManager>();

CocoaPodsValidator get cocoapodsValidator => context.get<CocoaPodsValidator>();

LocalEngineLocator get localEngineLocator => context.get<LocalEngineLocator>();
FuchsiaArtifacts get fuchsiaArtifacts => context.get<FuchsiaArtifacts>();
IOSSimulatorUtils get iosSimulatorUtils => context.get<IOSSimulatorUtils>();

XCDevice get xcdevice => context.get<XCDevice>();
