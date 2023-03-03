// ignore_for_file: prefer_final_fields, library_private_types_in_public_api

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:liveguide/signaling.dart';
import 'package:wakelock/wakelock.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Wakelock.enable();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Guide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Signaling signaling = Signaling();
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  String? roomId;
  TextEditingController textEditingController = TextEditingController(text: '');
  bool isBroadcaster = false;

  @override
  void initState() {
    _localRenderer.initialize();
    _remoteRenderer.initialize();

    signaling.onAddRemoteStream = ((stream) {
      log("ON ADD REMOTE STREAM");

      _remoteRenderer.srcObject = stream;
      setState(() {});
    });

    super.initState();

    // Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).whenComplete(() {
    //   setState(() {});
    // });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    signaling.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: isBroadcaster
                      ? Expanded(
                          child: RTCVideoView(
                            _localRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                            mirror: true,
                          ),
                        )
                      : Expanded(
                          child: RTCVideoView(
                            _remoteRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                            mirror: true,
                          ),
                        ),
                ),
              ),
              Column(
                children: [
                  TextFormField(
                    controller: textEditingController,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(10),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                      hintText: "Enter Room ID",
                      hintStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    textAlign: TextAlign.center,
                    cursorColor: Colors.black,
                  ),
                  signaling.isConnectionActive()
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(Colors.red[300]),
                            ),
                            onPressed: () async {
                              await signaling.hangUp(_localRenderer);
                              textEditingController.text = '';
                              _localRenderer.srcObject = null;
                              _remoteRenderer.srcObject = null;
                              setState(() {
                                roomId = null;
                              });
                            },
                            child: const Text("Hangup"),
                          ),
                        )
                      : Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ButtonStyle(
                                  backgroundColor: MaterialStateProperty.all(Colors.green[200]),
                                ),
                                onPressed: () async {
                                  // await signaling.openUserMedia(_localRenderer, _remoteRenderer);
                                  signaling.joinRoom(
                                    textEditingController.text,
                                    _remoteRenderer,
                                  );
                                },
                                child: const Text(
                                  "Join Room",
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 8, bottom: 8),
                              child: const Text(
                                "---  Or  ---",
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ButtonStyle(
                                  backgroundColor: MaterialStateProperty.all(Colors.green[800]),
                                ),
                                onPressed: () async {
                                  await signaling.openUserMedia(_localRenderer, _remoteRenderer);
                                  await signaling.createRoom(_remoteRenderer);
                                  isBroadcaster = true;
                                  setState(() {});
                                },
                                child: const Text(
                                  "Create Room",
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
