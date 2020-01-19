import 'package:flutter/material.dart';
import 'package:flutter_shake_vibrate_package/flutter_shake_vibrate_package.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with OnShakeHandler {
  String _counter = 'Waiting';
  OnShakeHandler _onShakeHandler = OnShakeHandler();
  OnAxisMonitor _onAxisMonitor = OnAxisMonitor(trace: true);

  @override
  void shakeEventListener(ShakeData data) {
    final answer = '${data.timestamp.toLocal().toIso8601String()} ${data.shakeCount}';
    debugPrint(answer);
    setState(() {
      _counter = answer;
    });
  }

  @override
  void dispose() {
    /// Close the stream controller of the superclass
    closeListening();
    _onShakeHandler.closeListening();
    _onAxisMonitor.closeListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Shake reporting',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.title,
            ),
            StreamBuilder<AxisData>(
              stream: _onAxisMonitor.stream,
              builder: (context, data) {
                if (!data.hasData) return CircularProgressIndicator();
                AxisData result = data.data;
                return Text('${result.axis.toString()} range: ${result.axisDistance}');
              },
            ),
            StreamBuilder<ShakeData>(
              stream: _onShakeHandler.stream,
              builder: (context, data) {
                if (data.hasData) {
                  ShakeData result = data.data;
                  return Text(
                    '${result.timestamp.toLocal().toIso8601String()} Count: ${result.shakeCount}',
                    style: Theme.of(context).textTheme.title,
                  );
                } else {
                  return CircularProgressIndicator();
                }
              },
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _shaker,
        tooltip: 'Shake',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _shaker() {
    if (_counter == 'Waiting') {
      startListening();
      _onShakeHandler.startListening(vibrationDuration: Duration(milliseconds: 500));
      _onAxisMonitor.startListening();
    } else {
      stopListening();
      _onShakeHandler.stopListening();
      _onAxisMonitor.stopListening();
      setState(() {
        _counter = 'Waiting';
      });
    }
  }
}
