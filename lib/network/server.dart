import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

class Server {
  Server();

  Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': ['stun:stun1.l.google.com:19302', 'stun:stun2.l.google.com:19302']
      }
    ]
  };

  ServerSocket? server;
  bool running = false;
  List<Socket> sockets = [];

  MediaStream? senderStream;
  RTCPeerConnection? peerConnection;

  start() async {
    runZoned(() async {
      server = await ServerSocket.bind('0.0.0.0', 4040);
      running = true;
      server!.listen(onRequest);
    }, onError: (e) {
      log(e);
    });
  }

  stop() async {
    await server?.close();
    server = null;
    running = false;
  }

  onRequest(Socket socket) {
    if (!sockets.contains(socket)) {
      sockets.add(socket);
    }

    socket.listen((Uint8List data) async {
      if (data.isNotEmpty) {
        String rawData = String.fromCharCodes(data);
        int idx = rawData.indexOf(":");
        String reqCode = rawData.substring(0, idx).trim();
        String sdp = rawData.substring(idx + 1).trim();

        if (reqCode == 'consumer') {
          String sdpFromServer = await setConsumer(sdp);
          log("SERVER: TO CLIENT: $sdpFromServer");
          socket.write('server:$sdpFromServer\n');
          await socket.flush();
        }
      }
    });
  }

  Future<String> setBroadcaster(String sdp) async {
    peerConnection = await createPeerConnection(configuration);
    peerConnection!.onTrack = (RTCTrackEvent event) {
      senderStream = event.streams[0];
    };

    RTCSessionDescription desc = RTCSessionDescription(sdp, 'offer');
    await peerConnection!.setRemoteDescription(desc);

    RTCSessionDescription answer = await peerConnection!.createAnswer();
    peerConnection!.setLocalDescription(answer);
    RTCSessionDescription? payload = await peerConnection!.getLocalDescription();

    return payload!.sdp!;
  }

  Future<String> setConsumer(String sdp) async {
    peerConnection = await createPeerConnection(configuration);

    RTCSessionDescription desc = RTCSessionDescription('$sdp\n', 'offer');
    log(desc.toMap().toString());
    await peerConnection!.setRemoteDescription(desc);
    senderStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, senderStream!);
    });

    RTCSessionDescription answer = await peerConnection!.createAnswer();
    peerConnection!.setLocalDescription(answer);
    RTCSessionDescription? payload = await peerConnection!.getLocalDescription();

    return payload!.sdp!;
  }
}
