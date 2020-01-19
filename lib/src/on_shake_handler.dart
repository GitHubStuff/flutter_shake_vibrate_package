import 'dart:async';
import 'dart:math';

import 'package:flutter_tracers/trace.dart' as Log;
import 'package:sensors/sensors.dart';
import 'package:vibration/vibration.dart';

typedef ShakeEvent(ShakeData shakeData);

/// The data type returned when a 'shake' event occurs
class ShakeData {
  final double gForce;
  final int shakeCount;
  final DateTime timestamp;
  ShakeData(this.gForce, this.shakeCount, this.timestamp);
}

/// This class can be used as mix-in using the 'with'-keyword on a class, or a stream.
/// If using as mix-in, the class should '@override shakeEventListener(ShakeData data){}' get
/// shake notifications.
/// As stream, an instance of this class must be instantiated and use of helper 'Stream<ShakeData> stream', to
/// use with StreamBuilder
///
class OnShakeHandler {
  ///
  /// The force of gravity is always influencing the measured acceleration:
  ///     Ad = -g - ∑F / mass
  ///     ==> g = 9.80665 m/s^2
  final double _g = 9.80665; // g = 9.80665 m/s^2

  StreamSubscription<dynamic> _accelerometerStream;

  /// For use with Stream/StreamBuilder
  final StreamController<ShakeData> _streamController = StreamController<ShakeData>.broadcast();
  Stream<ShakeData> get stream => _streamController.stream;
  Sink<ShakeData> get _sink => _streamController.sink;

  /// *********
  /// IMPORTANT - this method should be called to close the streamController to prevent memory leaks
  /// and for listeners to receive the 'done' event
  void closeListening() {
    _streamController.close();
  }

  /// NOTE: If used as Mix-In, this class must be overridden to become the call-back for shake events
  void shakeEventListener(ShakeData shakeData) {}

  /// shakeGravityThreshold - The higher the more pronounce the shake my be in all axis
  /// shakeDelta - To refine the shake counter a small interval will ignore changes reported by the accelerometer, so that
  ///              multiple events in the same axis (eg: rotating device left reports 4 events) counts as roughly 1-shake
  /// shakeReset - To count the number of shakes in a single period there should be an interval that will reset the counter
  /// vibrationDuration - A single vibration of specified duration will happen when a shake is reported.
  ///
  void startListening(
      {double shakeGravityThreshold = 2.7,
      Duration shakeDelta = const Duration(milliseconds: 100),
      Duration shakeReset = const Duration(milliseconds: 750),
      Duration vibrationDuration,
      bool trace = false}) {
    if (_accelerometerStream != null) return;
    assert(shakeGravityThreshold > 0.0);
    assert(shakeDelta != null && !shakeDelta.isNegative);
    assert(shakeReset != null && !shakeReset.isNegative);

    DateTime _shakeReporting = DateTime.now().toUtc();
    int shakeCount = 0;

    _accelerometerStream = accelerometerEvents.listen((AccelerometerEvent event) {
      double gX = event.x;
      double gY = event.y;
      double gZ = event.z;

      // gForce will be close to 1 when there is no movement.
      double gForce = sqrt(gX * gX + gY * gY + gZ * gZ) - _g;
      Log.t('gForce $gForce (gForce will be close to 1 when there is no movement', trace);
      if (gForce > shakeGravityThreshold) {
        Log.t(' >gForce $gForce > $shakeGravityThreshold', trace);

        // ignore shake events too close to each other (500ms)
        DateTime deltaTime = _shakeReporting.add(shakeDelta).toUtc();
        if (deltaTime.isAfter(DateTime.now().toUtc())) {
          Log.t(' Too close to shakeDelta ${shakeDelta.toString()}', trace);
          return;
        }

        // reset the shake count after given number of milliseconds of no shakes
        deltaTime = _shakeReporting.add(shakeReset).toUtc();
        if (deltaTime.isBefore(DateTime.now().toUtc())) {
          Log.t(' Number of shakes reset because ${shakeReset.toString()} lapsed', trace);
          shakeCount = 0;
        }

        if (vibrationDuration != null) Vibration.vibrate(duration: vibrationDuration.inMilliseconds);
        _shakeReporting = DateTime.now().toUtc();
        final result = ShakeData(gForce, ++shakeCount, DateTime.now().toUtc());
        _sink.add(result);
        shakeEventListener(result);
        Log.t(' Reporting ${DateTime.now().toLocal().toIso8601String()}, Count:$shakeCount', trace);
      }
    });
  }

  void stopListening() {
    if (_accelerometerStream != null) {
      _accelerometerStream.cancel();
      _accelerometerStream = null;
    }
  }
}
