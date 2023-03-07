// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef SdpCallback = Future Function(String sdp);
typedef ICECallback = Future Function(RTCIceCandidate);

class Client {
  Client({
    required this.hostname,
    required this.port,
  });

  String hostname;
  int port;
  bool connected = false;

  Socket? socket;
  SdpCallback? onSdpReceived;
  ICECallback? onICEReceived;

  connect() async {
    try {
      socket = await Socket.connect(hostname, 4040);
      connected = true;
    } on Exception catch (exception) {
      print('Client connect error: $exception');
    }
  }

  getSdpFromServer(String sdp) async {
    socket!.write('consumer:${sdp}COMPLETE');
    await socket!.flush();

    socket!.listen(
      (Uint8List data) async {
        // await Future.delayed(const Duration(seconds: 8));
        String rawData = String.fromCharCodes(data);
        while (!rawData.contains("COMPLETE")) {
          data = await socket!.first;
          rawData += String.fromCharCodes(data);
        }
        rawData = rawData.replaceAll("COMPLETE", "");

        if (data.isNotEmpty) {
          int idx = rawData.indexOf(":");
          String code = rawData.substring(0, idx).trim();
          String dataFromServer = rawData.substring(idx + 1).trim();

          int idxOfCandidates = dataFromServer.indexOf("candidates:");

          if (code == 'sdp') {
            await onSdpReceived!(dataFromServer.substring(0, idxOfCandidates).trim());
          }

          if (idxOfCandidates != -1) {
            var json = jsonDecode(dataFromServer.substring(idxOfCandidates + 11).trim());

            for (var candidate in json) {
              String rawCandidate = candidate.toString().replaceAll(RegExp(r'[{}]+'), '').trim();

              RegExp exp = RegExp(r'candidate:(.*)sdpMid:(.*)sdpMLineIndex:(.*)');

              Match match = exp.firstMatch(rawCandidate)!;
              String candidateFinal = match.group(1)!.trim();
              candidateFinal = candidateFinal.substring(0, candidateFinal.length - 1);
              String sdpMid = match.group(2)!.trim();
              sdpMid = sdpMid.substring(0, sdpMid.length - 1);
              String sdpMLineIndex = match.group(3)!.trim();

              RTCIceCandidate iceCandidate = RTCIceCandidate(
                candidateFinal,
                sdpMid,
                int.parse(sdpMLineIndex),
              );

              onICEReceived!(iceCandidate);
            }
          }
        }
      },
    );
  }

  disconnect() {
    if (socket != null) {
      socket!.destroy();
      connected = false;
    }
  }
}
