// @dart=2.10
library apn_crashlytics;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui show window;

import 'package:connectivity/connectivity.dart';
import 'package:device_info/device_info.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info/package_info.dart';
import 'package:sentry/sentry.dart';

abstract class ICrashLogging {
  Future<ICrashLogging> init(Map<String, String> params);

  void captureException({dynamic exception, dynamic stacktrace});

  void setUserId(String userId);
}

class ConsoleLogging extends ICrashLogging {
  @override
  void captureException({exception, stacktrace}) {
    //Nothing special needed
  }

  @override
  Future<ICrashLogging> init(Map<String, String> params) {
    // This captures errors reported by the Flutter framework.
    FlutterError.onError = (details) => FlutterError.dumpErrorToConsole(details);
    return Future.value(ConsoleLogging());
  }

  @override
  void setUserId(String userId) {
    //Nothing special needed
  }
}

class CrashlyticsLogging extends ICrashLogging {
  @override
  void captureException({exception, stacktrace}) {
    print('Capture raw exception and sending it to Crashlytics');
    Crashlytics.instance.recordError(exception, stacktrace);
  }

  @override
  Future<ICrashLogging> init(Map<String, String> params) async {
    // This captures errors reported by the Flutter framework.
    FlutterError.onError = (details) => Zone.current.handleUncaughtError(details.exception, details.stack);

    Crashlytics.instance.enableInDevMode = true;

    return CrashlyticsLogging();
  }

  @override
  void setUserId(String userId) {
    if (userId != null) {
      Crashlytics.instance.setUserIdentifier(userId);
    } else {
      Crashlytics.instance.setUserIdentifier(null);
    }
  }
}

class SentryLogging extends ICrashLogging {
  static SentryClient sentry;

  @override
  void captureException({exception, stacktrace}) {
    print('Capture raw exception and sending it to Sentry');
    sentry.captureException(
      exception: exception,
      stackTrace: stacktrace,
    );
  }

  @override
  Future<ICrashLogging> init(Map<String, String> params) async {
    OperatingSystem operatingSystem;
    Device device;
    App app;

    // This captures errors reported by the Flutter framework.
    FlutterError.onError = (details) => Zone.current.handleUncaughtError(details.exception, details.stack);

    final packageInfo = await PackageInfo.fromPlatform();
    AndroidDeviceInfo androidDeviceInfo;
    IosDeviceInfo iosDeviceInfo;

    if (Platform.isAndroid) androidDeviceInfo = await DeviceInfoPlugin().androidInfo;
    if (Platform.isIOS) iosDeviceInfo = await DeviceInfoPlugin().iosInfo;
    var isOnline = (await Connectivity().checkConnectivity()) != ConnectivityResult.none;

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
      dsn: params['sentryDsn'],
      environmentAttributes: Event(
        environment: params['envType'],
        contexts: Contexts(
          operatingSystem: operatingSystem,
          device: device,
          app: app,
          runtimes: [Runtime(name: 'dart', version: Platform.version)],
        ),
      ),
    );

    return SentryLogging();
  }

  @override
  void setUserId(String userId) {
    if (userId != null) {
      sentry.userContext = User(id: userId);
    } else {
      sentry.userContext = null;
    }
  }
}

class NoopCrashLogging extends ICrashLogging {
  @override
  void captureException({exception, stacktrace}) {
    //No-op
  }

  @override
  Future<ICrashLogging> init(Map<String, String> params) {
    return Future.value(NoopCrashLogging());
  }

  @override
  void setUserId(String userId) {
    //No-op
  }
}
