library apn_crashlytics;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui show window;

import 'package:device_info/device_info.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info/package_info.dart';
import 'package:sentry/sentry.dart';

class CrashLogging {
  final bool debugEnabled;
  final String envType;
  final String sentryDsn;

  SentryClient sentry;

  CrashLogging(
    this.debugEnabled,
    this.envType,
    this.sentryDsn, {
    AndroidDeviceInfo androidDeviceInfo,
    IosDeviceInfo iosDeviceInfo,
    PackageInfo packageInfo,
    bool isOnline,
  }) {
    OperatingSystem operatingSystem;
    Device device;
    App app;

    // This captures errors reported by the Flutter framework.
    FlutterError.onError = (details) {
      if (debugEnabled) {
        FlutterError.dumpErrorToConsole(details);
      } else {
        Zone.current.handleUncaughtError(details.exception, details.stack);
      }
    };

    if (androidDeviceInfo != null) {
      operatingSystem = OperatingSystem(
        name: 'Android',
        version: androidDeviceInfo.version.release,
      );
      device = Device(
        name: androidDeviceInfo.device,
        model: androidDeviceInfo.model,
        simulator: !androidDeviceInfo.isPhysicalDevice,
        online: isOnline,
        screenResolution: "${ui.window.physicalSize.width.toInt()}x${ui.window.physicalSize.height.toInt()}",
      );
    }

    if (iosDeviceInfo != null) {
      operatingSystem = OperatingSystem(
        name: 'iOS',
        version: iosDeviceInfo.systemVersion,
      );
      device = Device(
        name: iosDeviceInfo.name,
        model: iosDeviceInfo.model,
        simulator: !iosDeviceInfo.isPhysicalDevice,
        online: isOnline,
        screenResolution: "${ui.window.physicalSize.width.toInt()}x${ui.window.physicalSize.height.toInt()}",
      );
    }

    if (packageInfo != null) {
      app = App(
        startTime: DateTime.now(),
        version: packageInfo.version,
        build: packageInfo.buildNumber,
        name: packageInfo.appName,
        identifier: packageInfo.packageName,
      );
    }

    sentry = SentryClient(
      dsn: sentryDsn,
      environmentAttributes: Event(
        environment: envType,
        contexts: Contexts(
          operatingSystem: operatingSystem,
          device: device,
          app: app,
          runtimes: [Runtime(name: 'dart', version: Platform.version)],
        ),
      ),
    );

    Crashlytics.instance.enableInDevMode = true;
  }

  void captureException({dynamic exception, dynamic stacktrace}) {
    print('Capture raw exception and sending to crash logs');

    sentry.captureException(
      exception: exception,
      stackTrace: stacktrace,
    );

    Crashlytics.instance.recordError(exception, stacktrace);
  }

  void setUserId(String userId) {
    if (userId != null) {
      sentry.userContext = User(id: userId);
      Crashlytics.instance.setUserIdentifier(userId);
    } else {
      sentry.userContext = null;
      Crashlytics.instance.setUserIdentifier(null);
    }
  }
}