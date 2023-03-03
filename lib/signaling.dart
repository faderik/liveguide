// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:liveguide/network/client.dart';
import 'package:liveguide/network/server.dart';

typedef StreamStateCallback = void Function(MediaStream stream);

class Signaling {
  Map<String, dynamic> configuration = {
    'iceServers': [
      // {
      //   'urls': [
      //     'stun:stun1.l.google.com:19302',
      //     'stun:stun2.l.google.com:19302'
      //   ]
      // }
    ]
  };

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;
  String? currentRoomText;
  StreamStateCallback? onAddRemoteStream;
  Server? server;
  Client? client;

  void close() {
    server?.stop();
    client?.disconnect();
  }

  Future createRoom(RTCVideoRenderer remoteRenderer) async {
    server = Server();
    server!.start();

    peerConnection = await createPeerConnection(configuration);
    peerConnection!.onRenegotiationNeeded = () async {
      await handleNegotiationNeededEventServer();
    };

    localStream?.getTracks().forEach((track) {
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

  Future<void> joinRoom(String roomId, RTCVideoRenderer remoteVideo) async {
    client = Client(
      hostname: '192.168.1.5',
      port: 4040,
    );
    await client!.connect();
    client!.onSdpReceived = ((sdp) {
      setRdpClient(sdp);
    });

    peerConnection = await createPeerConnection(configuration);
    peerConnection!.onTrack = (RTCTrackEvent event) {
      remoteStream = event.streams[0];
      onAddRemoteStream!(remoteStream!);
    };
    peerConnection!.onRenegotiationNeeded = () async {
      await handleNegotiationNeededEventClient();
    };

    peerConnection!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(
        direction: TransceiverDirection.RecvOnly,
        streams: [await createLocalMediaStream('key')],
      ),
    );
  }

  Future handleNegotiationNeededEventClient() async {
    var offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);
    RTCSessionDescription? payload = await peerConnection!.getLocalDescription();

    await client!.getSdpFromServer(payload!.sdp!);
  }

  setRdpClient(String sdp) {
    RTCSessionDescription desc = RTCSessionDescription('$sdp\n', 'answer');
    peerConnection!.setRemoteDescription(desc);
  }

  Future<void> openUserMedia(
    RTCVideoRenderer localVideo,
    RTCVideoRenderer remoteVideo,
  ) async {
    var stream = await navigator.mediaDevices.getUserMedia({'video': true, 'audio': false});

    localVideo.srcObject = stream;
    localStream = stream;

    remoteVideo.srcObject = await createLocalMediaStream('key');
  }

  Future<void> hangUp(RTCVideoRenderer localVideo) async {
    List<MediaStreamTrack> tracks = localVideo.srcObject!.getTracks();
    tracks.forEach((track) {
      track.stop();
    });

    if (remoteStream != null) {
      remoteStream!.getTracks().forEach((track) => track.stop());
    }
    if (peerConnection != null) peerConnection!.close();

    if (roomId != null) {
      var db = FirebaseFirestore.instance;
      var roomRef = db.collection('rooms').doc(roomId);
      var calleeCandidates = await roomRef.collection('calleeCandidates').get();
      calleeCandidates.docs.forEach((document) => document.reference.delete());

      var callerCandidates = await roomRef.collection('callerCandidates').get();
      callerCandidates.docs.forEach((document) => document.reference.delete());

      await roomRef.delete();
    }

    localStream!.dispose();
    remoteStream?.dispose();

    remoteStream = null;
    peerConnection = null;
  }

  bool isConnectionActive() {
    return remoteStream != null || peerConnection != null;
  }
}
