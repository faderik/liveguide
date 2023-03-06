// ignore_for_file: avoid_print

import 'dart:developer';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:liveguide/network/client.dart';
import 'package:liveguide/network/server.dart';

typedef StreamStateCallback = void Function(MediaStream stream);
typedef ConnectionStateCallback = void Function(RTCPeerConnectionState stream);

class Signaling {
  Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': ['stun:stun1.l.google.com:19302', 'stun:stun2.l.google.com:19302']
      }
    ]
  };

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;
  String? currentRoomText;
  StreamStateCallback? onAddRemoteStream;
  ConnectionStateCallback? onConnectionState;
  Server? server;
  Client? client;
  bool isBroadcaster = false;
  String connectionStatus = '-';

  void close() {
    server?.stop();
    client?.disconnect();
  }

  Future createRoom() async {
    isBroadcaster = true;
    server = Server();
    if (!server!.running) {
      server!.start();
    }

    peerConnection = await createPeerConnection(configuration);
    peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      onConnectionState!(state);
    };
    peerConnection!.onSignalingState = (RTCSignalingState state) {
      log('CLIENT: ON SIGNALING STATE: $state.toString()');
    };
    peerConnection!.onRenegotiationNeeded = () async {
      log('ON RE-NEGOTIATION : SERVER');

      await handleNegotiationNeededEventServer();
    };

    localStream?.getTracks().forEach((track) {
      log("SERVER: ADDING TRACK: ${track.toString()}");
      // Disable audio output
      // track.applyConstraints({"deviceId": null});
      // track.enabled = false;
      peerConnection?.addTrack(track, localStream!);
    });
  }

  Future handleNegotiationNeededEventServer() async {
    var offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);
    RTCSessionDescription? payload = await peerConnection!.getLocalDescription();

    String sdpFromServer = await server!.setBroadcaster(payload!.sdp!);

    RTCSessionDescription desc = RTCSessionDescription(sdpFromServer, 'answer');
    await peerConnection!.setRemoteDescription(desc);
  }

  Future<void> joinRoom(String serverIp, RTCVideoRenderer remoteRenderer, {bool audioOnly = false}) async {
    client = Client(
      hostname: serverIp,
      port: 4040,
    );
    await client!.connect();
    client!.onSdpReceived = ((sdp) async {
      await setRdpClient(sdp);
    });

    peerConnection = await createPeerConnection(configuration);
    peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      onConnectionState!(state);
    };
    peerConnection!.onSignalingState = (RTCSignalingState state) {
      log('CLIENT: ON SIGNALING STATE: $state');
    };
    remoteRenderer.srcObject = await createLocalMediaStream('key');
    peerConnection!.onTrack = (RTCTrackEvent event) {
      remoteStream = event.streams[0];
      onAddRemoteStream!(remoteStream!);
    };
    peerConnection!.onRenegotiationNeeded = () async {
      log('ON RE-NEGOTIATION : CLIENT');
      await handleNegotiationNeededEventClient();
    };

    peerConnection!.addTransceiver(
      kind: audioOnly ? RTCRtpMediaType.RTCRtpMediaTypeAudio : RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(
        direction: TransceiverDirection.RecvOnly,
      ),
    );
  }

  Future handleNegotiationNeededEventClient() async {
    var offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);
    RTCSessionDescription? payload = await peerConnection!.getLocalDescription();

    await client!.getSdpFromServer(payload!.sdp!);
  }

  setRdpClient(String sdp) async {
    RTCSessionDescription desc = RTCSessionDescription('$sdp\n', 'answer');
    log("CLIENT: FROM WS SERVER: $sdp");
    await peerConnection!.setRemoteDescription(desc);
  }

  Future<void> openUserMedia(RTCVideoRenderer localVideo, {bool audioOnly = false}) async {
    var stream = await navigator.mediaDevices.getUserMedia({'video': !audioOnly, 'audio': true});

    localVideo.srcObject = stream;
    localStream = stream;

    // remoteVideo.srcObject = await createLocalMediaStream('key');
  }

  Future<void> hangUp(RTCVideoRenderer localVideo, RTCVideoRenderer remoteVideo) async {
    if (isBroadcaster) {
      if (localVideo.srcObject != null) {
        List<MediaStreamTrack> tracks = localVideo.srcObject!.getTracks();
        for (var track in tracks) {
          track.stop();
        }
      }
    } else {
      if (remoteVideo.srcObject != null) {
        List<MediaStreamTrack> tracks = remoteVideo.srcObject!.getTracks();
        for (var track in tracks) {
          track.stop();
        }
      }
    }

    if (remoteStream != null) {
      remoteStream!.getTracks().forEach((track) => track.stop());
    }
    if (localStream != null) {
      localStream!.getTracks().forEach((track) => track.stop());
    }
    if (peerConnection != null) peerConnection!.close();

    localStream?.dispose();
    remoteStream?.dispose();

    remoteStream = null;
    peerConnection = null;
    server?.stop();
    client?.disconnect();
    isBroadcaster = false;
  }

  bool isConnectionActive() {
    return remoteStream != null || peerConnection != null;
  }
}
