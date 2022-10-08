import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ftchat_video_call/screens/call_screen.dart';
import 'package:ftchat_video_call/services/sfu.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
  // SystemChrome.setEnabledSystemUIMode (SystemUiMode.edgeToEdge, overlays: []);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  bool? isCameraEnabled = true;
  bool? isMicEnabled = true;
  String myId = '';
  String roomId = '';
  bool isVisible = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  _startCall() async {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CallScreen(
            myId: myId,
            roomId: roomId,
            isCameraEnabled: isCameraEnabled!,
            isMicEnabled: isMicEnabled!,
            startCall: true,
          ),
        ),
      );
    }
  }

  _joinCall() async {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CallScreen(
            myId: myId,
            roomId: roomId,
            isCameraEnabled: isCameraEnabled!,
            isMicEnabled: isMicEnabled!,
            startCall: false,
          ),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call'),
      ),
      body: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Column(children: [
            TextField(
              onChanged: (value) => myId = value,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter Your ID',
              ),
            ),
            TextField(
              onChanged: (value) => roomId = value,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter Room ID',
              ),
            ),
            SizedBox(
              height: 40,
              width: 300,
              child: CheckboxListTile(
                title: const Text('Enable Camera'),
                value: isCameraEnabled,
                onChanged: (value) {
                  setState(() {
                    isCameraEnabled = value;
                  });
                },
              ),
            ),
            SizedBox(
                height: 40,
                width: 300,
                child: CheckboxListTile(
                  title: const Text('Enable Microphone'),
                  value: isMicEnabled,
                  onChanged: (value) {
                    setState(() {
                      isMicEnabled = value;
                    });
                  },
                )),
            SizedBox(
              height: 40,
              width: 300,
              child: ElevatedButton(
                onPressed: _startCall,
                child: const Text('Start Call'),
              ),
            ),
            SizedBox(
              height: 40,
              width: 300,
              child: ElevatedButton(
                onPressed: _joinCall,
                child: const Text('Join Call'),
              ),
            ),
          ])),
    );
  }
}
