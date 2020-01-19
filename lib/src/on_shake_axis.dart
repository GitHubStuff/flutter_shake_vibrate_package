import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tracers/trace.dart' as Log;
import 'package:sensors/sensors.dart';

enum Axis { x, y, z }

/// Date returned when monitoring shakes for an axis
class AxisData {
  final Axis axis;
  final double axisDistance;
  final DateTime timestamp;
  AxisData(this.axis, this.axisDistance, this.timestamp);
}

/// This class use Sink/Streams to report on shake events in the x, y, and z axis.
/// The formula is using a list of accelerometer events where each axis is checked and
/// if the change in the change in distance is great enough an AxisData is put into the
/// the stream.
/// This allows for shakes to be reported in each axis and processed per-axis events or
/// as overall shake.
class OnAxisMonitor {
  StreamSubscription<dynamic> _accelerometerStream;
  _AxisMonitor _monitorX;
  _AxisMonitor _monitorY;
  _AxisMonitor _monitorZ;

  /// For use with Stream/StreamBuilder
  final StreamController<AxisData> _streamController = StreamController<AxisData>.broadcast();
  Stream<AxisData> get stream => _streamController.stream;
  Sink<AxisData> get _sink => _streamController.sink;
  final bool trace;

  /// axisThresholds are the delta's in position change that will put AxisData into the stream
  OnAxisMonitor({List<double> axisThresholds = const [20.0, 20.0, 20.0], this.trace = false})
      : assert(axisThresholds != null && axisThresholds.length >= 1 && axisThresholds.length <= 3),
        assert(axisThresholds[0] != null),
        assert(trace != null) {
    double xRange = axisThresholds[0];
    double yRange = (axisThresholds.length >= 2 && axisThresholds[1] != null) ? axisThresholds[1] : xRange;
    double zRange = (axisThresholds.length == 3 && axisThresholds[2] != null) ? axisThresholds[2] : yRange;

    _monitorX = _AxisMonitor(Axis.x, sink: _sink, detectionThreshold: xRange, trace: trace);
    _monitorY = _AxisMonitor(Axis.y, sink: _sink, detectionThreshold: yRange, trace: trace);
    _monitorZ = _AxisMonitor(Axis.z, sink: _sink, detectionThreshold: zRange, trace: trace);
  }

  /// NOTE: It is very important this be called to close the StreamControllers
  void closeListening() {
    stopListening();
    _streamController.close();
  }

  /// As each event from the accelerometer comes in the x,y and z values are examined.
  void startListening() {
    if (_accelerometerStream != null) return;
    _accelerometerStream = accelerometerEvents.listen((AccelerometerEvent event) {
      _monitorX.add(event: event);
      _monitorY.add(event: event);
      _monitorZ.add(event: event);
    });
  }

  void stopListening() {
    if (_accelerometerStream == null) return;
    _accelerometerStream.cancel();
    _accelerometerStream = null;
  }
}

/// This is a file-private class that handles examining an axis to see if the movements should put an AxisData into the stream.
/// A list of axis points are stored in a list and the max/min values are compared to see if their difference is enough
/// to signal a shake event.
class _AxisMonitor {
  static const _CircularBufferSize = 10;

  final Axis axis;
  List<double> _circularBuffer = List.filled(_CircularBufferSize, 0.0);
  final double detectionThreshold;
  int _index = 0;
  double _maxValue = 0.0;
  double _minValue = 0.0;
  final Sink<AxisData> sink;
  final bool trace;

  _AxisMonitor(this.axis, {@required this.sink, @required this.detectionThreshold, @required this.trace})
      : assert(axis != null),
        assert(detectionThreshold > 0.0),
        assert(sink != null),
        assert(trace != null);

  Future<void> add({AccelerometerEvent event}) async {
    double value = 0;
    switch (axis) {
      case Axis.x:
        value = event.x;
        break;
      case Axis.y:
        value = event.y;
        break;
      case Axis.z:
        value = event.z;
        break;
    }
    Log.t('Axis $axis value:$value', trace);

    _index = (_index == _CircularBufferSize - 1) ? 0 : ++_index;
    var oldValue = _circularBuffer[_index];
    if (oldValue == _maxValue) {
      _maxValue = _circularBuffer.reduce(max);
    }
    if (oldValue == _minValue) {
      _minValue = _circularBuffer.reduce(min);
    }
    _circularBuffer[_index] = value;
    if (value < _minValue) _minValue = value;
    if (value > _maxValue) _maxValue = value;
    final range = _maxValue - _minValue;
    Log.t('Axis $axis range: $range threshold: $detectionThreshold', trace);
    if (range > detectionThreshold) {
      final timestamp = DateTime.now().toUtc();
      Log.t('Axis $axis Reporting ${timestamp.toLocal().toIso8601String()}', trace);
      sink.add(AxisData(axis, range, timestamp));
      _circularBuffer.fillRange(0, _CircularBufferSize, 0.0);
      _minValue = _minValue = 0.0;
    }
  }
}
