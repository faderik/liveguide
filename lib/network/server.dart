import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef ErrorCallback = Function(String error);

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
  ErrorCallback? onError;

  MediaStream? senderStream;
  List<String> senderCandidates = [];
  RTCPeerConnection? peerConnection;

  start() async {
    runZoned(() async {
      running = true;
      server = await ServerSocket.bind('0.0.0.0', 4040);
      server!.listen(onRequest);
    }, onError: (e) {
      onError!(e.toString());
    });
  }

  stop() async {
    senderCandidates.clear();
    await server?.close();
    senderStream!.getTracks().forEach((track) {
      track.stop();
    });
    senderStream?.dispose();
    peerConnection?.close();
    server = null;
    running = false;
  }

  onRequest(Socket socket) {
    if (!sockets.contains(socket)) {
      sockets.add(socket);

      socket.listen((Uint8List data) async {
        // await Future.delayed(const Duration(seconds: 5));
        String rawData = String.fromCharCodes(data);
        while (!rawData.contains("COMPLETE")) {
          data = await socket.first;
          rawData += String.fromCharCodes(data);
        }
        rawData = rawData.replaceAll("COMPLETE", "");

        if (data.isNotEmpty) {
          try {
            int idx = rawData.indexOf(":");
            String reqCode = rawData.substring(0, idx).trim();
            String sdp = rawData.substring(idx + 1).trim();

            if (reqCode == 'consumer') {
              String sdpFromServer = await setConsumer(sdp);
              String json = jsonEncode(senderCandidates);

              socket.write('sdp:${sdpFromServer}candidates:${json}COMPLETE');
              await socket.flush();
            }
          } catch (e) {
            onError!(e.toString());
          }
        }
      });
    }
  }

  Future<String> setBroadcaster(String sdp) async {
    peerConnection = await createPeerConnection(configuration);
    peerConnection!.onTrack = (RTCTrackEvent event) {
      senderStream = event.streams[0];
      // senderStream!.getTracks().forEach((track) {
      //   track.enableSpeakerphone(false);
      // });
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

  storeICECandidate(RTCIceCandidate candidate) async {
    String candidateStr = candidate.toMap().toString();
    senderCandidates.add(candidateStr);
  }
}
