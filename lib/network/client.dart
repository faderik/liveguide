// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

typedef void SdpCallback(String sdp);

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

  connect() async {
    try {
      socket = await Socket.connect(hostname, 4040);
      connected = true;
    } on Exception catch (exception) {
      print('Client connect error: $exception');
    }
  }

  getSdpFromServer(String sdp) async {
    socket!.write('consumer:$sdp\n');
    socket!.listen(
      (Uint8List data) {
        if (data.isNotEmpty) {
          String rawData = String.fromCharCodes(data);
          int idx = rawData.indexOf(":");
          String code = rawData.substring(0, idx).trim();
          String sdp = rawData.substring(idx + 1).trim();

          if (code == 'server') {
            onSdpReceived!(sdp);
          }
        }
      },
    );
  }

  write(String message) {
    //Connect standard in to the socket
    socket!.write('$message\n');
  }

  disconnect() {
    if (socket != null) {
      socket!.destroy();
      connected = false;
    }
  }
}
