import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:liveguide/network/ap.dart';
import 'package:liveguide/signaling.dart';
import 'package:open_settings/open_settings.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  Signaling signaling = Signaling();
  bool isBroadcaster = false;
  AccessPoint? ap = AccessPoint();
  TextEditingController ssidController = TextEditingController(text: '');
  TextEditingController pwdController = TextEditingController(text: '');
  TextEditingController ipController = TextEditingController(text: '192.168.1.5');

  // String mode = 'ap';
  String mode = 'wlan';
  bool audioOnly = false;
  // bool audioOnly = true;

  bool gathering = true;
  bool loadingSdp = false;

  @override
  void initState() {
    _localRenderer.initialize();
    _remoteRenderer.initialize();

    signaling.onAddRemoteStream = ((stream) {
      log("ON ADD REMOTE STREAM");

      _remoteRenderer.srcObject = stream;
      setState(() {});
    });

    signaling.onConnectionState = ((RTCPeerConnectionState state) {
      log("ON CONNECTION STATE");

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnecting) {
        loadingSdp = false;
      }

      signaling.connectionStatus = state.toString();
      setState(() {});
    });

    signaling.onICEGatheringState = ((RTCIceGatheringState state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        gathering = false;
        log("ICE GATHERING COMPLETE");
      }

      setState(() {});
    });

    signaling.onError = ((error) {
      showMsgDialog(error);
    });

    super.initState();
  }

  @override
  void dispose() {
    signaling.hangUp(_localRenderer, _remoteRenderer);
    signaling.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    ap!.stop();
    super.dispose();
  }

  Future createRoom() async {
    isBroadcaster = true;

    try {
      if (mode == 'ap') {
        if (!await ap!.start()) {
          showMsgDialog("Failed to start Access Point");
          return;
        }

        dynamic apInfo = await ap!.getAPInfo();
        ssidController.text = apInfo!['ssid'];
        pwdController.text = apInfo!['password'];
      }

      String ip = await ap!.getServerIP(mode);
      if (ip == '') {
        showMsgDialog("Failed to get server IP");
        return;
      }
      ipController.text = ip;

      await ap!.printIP();

      await signaling.openUserMedia(_localRenderer, audioOnly: audioOnly);
      await signaling.createRoom();

      setState(() {});
    } catch (e) {
      showMsgDialog(e.toString());
    }
  }

  Future joinRoom() async {
    // if (!await ap!.connectToAP(ssidController.text, pwdController.text)) {
    //   showMsgDialog("Failed to connect to Access Point");
    //   return;
    // }
    if (ipController.text == '') {
      showMsgDialog("Please enter IP address");
      return;
    }

    try {
      loadingSdp = true;
      signaling.joinRoom(ipController.text, _remoteRenderer, audioOnly: audioOnly);
      setState(() {});
    } catch (e) {
      showMsgDialog(e.toString());
    }
  }

  Future hangUp() async {
    await signaling.hangUp(_localRenderer, _remoteRenderer);
    await ap!.stop();

    ipController.text = '192.168.1.5';
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    isBroadcaster = false;
    gathering = true;
    loadingSdp = false;

    setState(() {});
  }

  Future reConnect() async {
    bool isBroadcasterTemp = isBroadcaster;
    String ip = ipController.text;

    await hangUp();
    ipController.text = ip;
    setState(() {});

    if (isBroadcasterTemp) {
      await createRoom();
    } else {
      await joinRoom();
    }
  }

  openWifiSetting() async {
    await OpenSettings.openWIFISetting();
  }

  showMsgDialog(String msg) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Message"),
          content: Text(msg),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
                child: Container(
                  padding: const EdgeInsets.only(top: 10, bottom: 10),
                  child: isBroadcaster
                      ? (audioOnly
                          ? const Text("Broadcasting audio only")
                          : RTCVideoView(
                              _localRenderer,
                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                              mirror: true,
                            ))
                      : (audioOnly
                          ? const Text("Receiving audio only")
                          : RTCVideoView(
                              _remoteRenderer,
                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                              mirror: true,
                            )),
                ),
              ),
              Column(
                children: [
                  (isBroadcaster && mode == 'ap')
                      ? Container(
                          padding: const EdgeInsets.only(top: 10, bottom: 10),
                          child: Column(
                            children: [
                              TextFormField(
                                enabled: false,
                                controller: ssidController,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.all(10),
                                  label: Text("SSID"),
                                  floatingLabelBehavior: FloatingLabelBehavior.always,
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.black),
                                    borderRadius: BorderRadius.all(Radius.circular(5)),
                                  ),
                                ),
                                textAlign: TextAlign.center,
                                cursorColor: Colors.black,
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                enabled: false,
                                controller: pwdController,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.all(10),
                                  label: Text("Password"),
                                  floatingLabelBehavior: FloatingLabelBehavior.always,
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.black),
                                    borderRadius: BorderRadius.all(Radius.circular(5)),
                                  ),
                                ),
                                textAlign: TextAlign.center,
                                cursorColor: Colors.black,
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(),
                  !isBroadcaster ? const SizedBox(height: 10) : const SizedBox(),
                  (gathering && isBroadcaster)
                      ? Center(
                          child: Container(
                            margin: const EdgeInsets.all(10),
                            height: 20,
                            width: 20,
                            child: const CircularProgressIndicator(),
                          ),
                        )
                      : TextFormField(
                          enabled: isBroadcaster ? false : true,
                          controller: ipController,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.all(10),
                            label: Text("IP Address"),
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.black),
                              borderRadius: BorderRadius.all(Radius.circular(5)),
                            ),
                            hintText: "Enter IP Address",
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          textAlign: TextAlign.center,
                          cursorColor: Colors.black,
                        ),
                  signaling.isConnectionActive()
                      ? Row(
                          children: [
                            ElevatedButton(
                              style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all(Colors.green[200]),
                              ),
                              onPressed: () async {
                                await reConnect();
                              },
                              child: const Icon(Icons.replay_outlined),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: ElevatedButton(
                                style: ButtonStyle(
                                  backgroundColor: MaterialStateProperty.all(Colors.red[300]),
                                ),
                                onPressed: () async {
                                  await hangUp();
                                },
                                child: const Text("Hangup"),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ButtonStyle(
                                      backgroundColor: MaterialStateProperty.all(Colors.green[200]),
                                    ),
                                    onPressed: () async {
                                      await openWifiSetting();
                                    },
                                    child: const Text("Open Wifi Setting"),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ButtonStyle(
                                      backgroundColor: MaterialStateProperty.all(Colors.green[200]),
                                    ),
                                    onPressed: loadingSdp
                                        ? null
                                        : () async {
                                            await joinRoom();
                                          },
                                    child: loadingSdp
                                        ? const SizedBox(
                                            width: 15,
                                            height: 15,
                                            child: CircularProgressIndicator(),
                                          )
                                        : const Text(
                                            "Join Room",
                                            style: TextStyle(color: Colors.black),
                                          ),
                                  ),
                                ),
                              ],
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
                                  await createRoom();
                                },
                                child: const Text(
                                  "Create Room",
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                          ],
                        ),
                  Text(
                    signaling.connectionStatus,
                    style: const TextStyle(fontSize: 10),
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
