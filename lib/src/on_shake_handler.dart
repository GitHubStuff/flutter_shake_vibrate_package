import 'dart:async';
import 'dart:math';

import 'package:flutter_tracers/trace.dart' as Log;
import 'package:sensors/sensors.dart';

typedef ShakeEvent(ShakeData shakeData);

class ShakeData {
  final double gForce;
  final int shakeCount;
  final DateTime timestamp;
  ShakeData(this.gForce, this.shakeCount, this.timestamp);
}

class OnShakeHandler {
  ///
  /// The force of gravity is always influencing the measured acceleration:
  ///     Ad = -g - ∑F / mass
  ///     ==> g = 9.80665 m/s^2
  final double _g = 9.80665; // g = 9.80665 m/s^2

  StreamSubscription<dynamic> _accelerometerStream;

  final StreamController<ShakeData> _streamController = StreamController<ShakeData>.broadcast();
  Stream<ShakeData> get stream => _streamController.stream;
  Sink<ShakeData> get _sink => _streamController.sink;

  void shakeEventListener(ShakeData shakeData) {}

  void startListening(
      {double shakeGravityThreshold = 2.7,
      Duration shakeDelta = const Duration(milliseconds: 100),
      Duration shakeReset = const Duration(milliseconds: 750),
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
          Log.t(' Too close to shakeDelta ${shakeDelta.toString()}');
          return;
        }

        // reset the shake count after given number of milliseconds of no shakes
        deltaTime = _shakeReporting.add(shakeReset).toUtc();
        if (deltaTime.isBefore(DateTime.now().toUtc())) {
          Log.t(' Number of shakes reset because ${shakeReset.toString()} lapsed');
          shakeCount = 0;
        }

        _shakeReporting = DateTime.now().toUtc();
        final result = ShakeData(gForce, ++shakeCount, DateTime.now().toUtc());
        _sink.add(result);
        shakeEventListener(result);
        Log.t(' Reporting ${DateTime.now().toLocal().toIso8601String()}, Count:$shakeCount');
      }
    });
  }

  void stopListening() {
    if (_accelerometerStream != null) {
      _accelerometerStream.cancel();
      _accelerometerStream = null;
    }
  }

  void dispose() {
    _streamController.close();
  }
}
