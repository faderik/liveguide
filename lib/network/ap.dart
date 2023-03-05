import 'dart:developer';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';

class AccessPoint {
  bool _isWiFiAPEnabled = false;

  Future<bool> requestPermissions() async {
    PermissionStatus res = await Permission.location.request();
    if (res.isGranted) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> start() async {
    if (!await requestPermissions()) {
      return false;
    }

    if (!await WiFiForIoTPlugin.isWiFiAPEnabled()) {
      await WiFiForIoTPlugin.setWiFiAPEnabled(true);
    }

    _isWiFiAPEnabled = true;
    return true;
  }

  Future<dynamic> stop() async {
    if (await WiFiForIoTPlugin.isWiFiAPEnabled()) {
      await WiFiForIoTPlugin.setWiFiAPEnabled(false);
    }
    _isWiFiAPEnabled = false;
  }

  Future<dynamic> getAPInfo() async {
    String? ssid = await WiFiForIoTPlugin.getWiFiAPSSID();
    String? password = await WiFiForIoTPlugin.getWiFiAPPreSharedKey();

    return {
      'ssid': ssid,
      'password': password,
      'enabled': _isWiFiAPEnabled,
    };
  }

  Future<bool> connectToAP(String ssid, String pwd) async {
    return await WiFiForIoTPlugin.connect(ssid, password: pwd);
  }

  Future<String> getServerIP(String mode) async {
    String serverAddress = '';
    for (var interface in await NetworkInterface.list()) {
      log('== Interface: ${interface.name} ==\n');
      if (interface.name.contains(mode)) {
        // if (interface.name.contains("wlan")) {
        for (var addr in interface.addresses) {
          if (addr.type.name.toLowerCase() == "ipv4") {
            log('${addr.address} ${addr.host} ${addr.isLoopback} ${addr.rawAddress} ${addr.type.name} \n');
            serverAddress = addr.address;
          }
        }
      }
    }

    return serverAddress;
  }

  Future printIP() async {
    for (var interface in await NetworkInterface.list()) {
      log('== Interface: ${interface.name} ==\n');
      for (var addr in interface.addresses) {
        if (addr.type.name.toLowerCase() == "ipv4") {
          log('${addr.address} ${addr.host} ${addr.isLoopback} ${addr.rawAddress} ${addr.type.name} \n');
        }
      }
    }
  }
}
