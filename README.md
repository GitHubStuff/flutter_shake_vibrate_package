# flutter_shake_vibrate_package

A Shake,Vibrate, Monitor Axis Flutter package.

## Getting Started

    OnAxisMonitor(List<double> axisThresholds: [20.0, 20.0, 20.0], bool trace = false)
    -- Stream/Sink class for a StreamBuilder.build() widget that returns AxisData that
       describes shakes along each axis(x,y,z).
    void closeListening();  // **MUST CALL** closes the StreamControllers
    void startListening();  // Start listening for accelerometer events
    void stopListening();   // Stop listening for accelerometer events
       
    OnShakeHandler()
    -- This class be a mix-in on a class
    ---- @override shakeEventListener(ShakeData data)
    -- It can also be used a Stream/Sink instace
    void closeListening();  // Closes the stream controller *MUST CALL*
    void startListening(double shakeGravityThreshold = 2.7, Duration shakeDelta = 100ms, Duration shakeReset = 750ms
                        Duration vibrationDuration = null, bool trace = false);
             shakeGravityThreshold - the larger the more vigorise the shake must be to product ShakeData
             shakeDelta - small duration between processing accelerometer events to improve accuracy of shake counts
             shakeReset - duration between measure the seperation between a shake to reset the shake count
             vibrationDuration - if set, will vibrate the device on shake event
    void stopListening();   // Stop listening for accelerometer events
