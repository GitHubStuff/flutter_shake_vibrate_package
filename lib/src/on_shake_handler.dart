import 'dart:async';
import 'dart:math';

import 'package:sensors/sensors.dart';

typedef ShakeEvent(DateTime timestamp, int shakeCount);

class OnShakeHandler {
  StreamSubscription<dynamic> _accelerometerStream;

  double _detectionThreshold = 20.0;

  void shakeEventListener(DateTime timestamp, int shakeCount) {}

  void startListeningShake(double detectionThreshold) {
    _detectionThreshold = detectionThreshold;
    if (_accelerometerStream == null) {
      _listenForShake();
    }
  }

  void _listenForShake() {
    const CircularBufferSize = 10;

    List<double> circularBuffer = List.filled(CircularBufferSize, 0.0);
    int index = 0;
    double minX = 0.0, maxX = 0.0;

    final gravityShake = _GravityShake(shakeEventListener);

    _accelerometerStream = accelerometerEvents.listen((AccelerometerEvent event) {
      gravityShake.onSensor(event: event);
      index = (index == CircularBufferSize - 1) ? 0 : index + 1;

      var oldX = circularBuffer[index];

      if (oldX == maxX) {
        maxX = circularBuffer.reduce(max);
      }
      if (oldX == minX) {
        minX = circularBuffer.reduce(min);
      }

      circularBuffer[index] = event.x;
      if (event.x < minX) minX = event.x;
      if (event.x > maxX) maxX = event.x;

      if (maxX - minX > _detectionThreshold) {
        shakeEventListener(DateTime.now().toUtc(), null);
        circularBuffer.fillRange(0, CircularBufferSize, 0.0);
        minX = 0.0;
        maxX = 0.0;
      }
    });
  }

  void resetShakeListeners() {
    if (_accelerometerStream != null) {
      _accelerometerStream.cancel();
      _accelerometerStream = null;
    }
  }
}

class _GravityShake {
  ShakeEvent callback;
  Duration resetInterval;
  int shakeCount = 0;
  int shakeDeltaMilliseconds;
  double shakeGravityThreshold;
  DateTime _shakeReporting = DateTime.now().toUtc();
  int shakeResetMilliseconds;

  _GravityShake(this.callback,
      [this.resetInterval = const Duration(seconds: 2),
      this.shakeGravityThreshold = 2.7,
      this.shakeDeltaMilliseconds = 500,
      this.shakeResetMilliseconds = 200])
      : assert(!resetInterval.isNegative),
        assert(shakeDeltaMilliseconds > 100);

  ///
  /// In particular, the force of gravity is always influencing the measured acceleration:
  ///     Ad = -g - ∑F / mass
  ///     ==> g = 9.80665 m/s^2
  void onSensor({AccelerometerEvent event}) {
    const double g = 9.80665; // g = 9.80665 m/s^2

    double gX = event.x / g;
    double gY = event.y / g;
    double gZ = event.z / g;

    // gForce will be close to 1 when there is no movement.
    double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

    if (gForce > shakeGravityThreshold) {
      // ignore shake events too close to each other (500ms)
      DateTime deltaTime = _shakeReporting.add(Duration(milliseconds: shakeDeltaMilliseconds)).toUtc();
      if (deltaTime.isAfter(DateTime.now().toUtc())) {
        return;
      }

      // reset the shake count after given number of milliseconds of no shakes
      deltaTime = _shakeReporting.add(Duration(milliseconds: shakeResetMilliseconds)).toUtc();
      if (deltaTime.isBefore(DateTime.now().toUtc())) {
        shakeCount = 0;
      }

      _shakeReporting = DateTime.now().toUtc();

      callback(_shakeReporting, ++shakeCount);
    }
  }
}
