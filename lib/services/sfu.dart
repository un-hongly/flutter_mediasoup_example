// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mediasoup_client_flutter/mediasoup_client_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart';

class SFU {
  String peerId;
  late Socket webSocket;
  Duration emitTimeout = const Duration(seconds: 30);
  int socketReconnetionDelay = 15000;

  SFU(this.peerId);

  Future connect() async {
    Completer completer = Completer();
    webSocket = io(
      dotenv.env['SOCKET_CALL_SFU_SERVER'],
      OptionBuilder()
          .enableForceNew()
          .setPath('/call/socket')
          .setTransports(['websocket'])
          .setQuery({'peerId': peerId})
          .setReconnectionDelay(socketReconnetionDelay)
          .setReconnectionDelayMax(socketReconnetionDelay)
          .build(),
    );
    webSocket.onConnect((data) {
      print('SFU socket connect successfully');
      if (!completer.isCompleted) {
        completer.complete(webSocket);
      }
    });
    webSocket.onConnectError((data) {
      print('SFU socket connect error $data');
      if (!completer.isCompleted) {
        completer.completeError(data);
      }
    });
    webSocket.onError((data) {
      print('SFU socket error$data');
      if (!completer.isCompleted) {
        completer.completeError(data);
      }
    });
    webSocket.onDisconnect((data) => print('SFU socket disconnected'));
    return completer.future;
  }

  setEmitTimeout(Completer completer) {
    return Future.delayed(emitTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Socket emit timeout.'));
      }
    });
  }

  subscribe({required String roomId}) {
    Completer completer = Completer();
    webSocket.emitWithAck('subscribe', {
      'roomId': roomId,
    }, ack: (Map response) {
      var data = response['data'];
      var error = response['error'];
      if (error != null) completer.completeError(error);
      completer.complete(data);
    });
    return completer.future;
  }

  createOrJoinRoom({required String roomId}) {
    Completer completer = Completer();
    webSocket.emitWithAck('createOrJoinRoom', {
      'roomId': roomId,
    }, ack: (Map response) {
      var data = response['data'];
      var error = response['error'];
      if (error != null) completer.completeError(error);
      var rtpCapabilities = RtpCapabilities.fromMap(data['rtpCapabilities']);

      rtpCapabilities.headerExtensions
          .removeWhere((he) => he.uri == 'urn:3gpp:video-orientation');

      completer.complete(rtpCapabilities);
    });
    return completer.future;
  }

  createRoom({required String roomId}) {
    Completer completer = Completer();
    webSocket.emitWithAck('createRoom', {
      'roomId': roomId,
    }, ack: (Map response) {
      var data = response['data'];
      var error = response['error'];
      if (error != null) completer.completeError(error);
      var rtpCapabilities = RtpCapabilities.fromMap(data['rtpCapabilities']);

      rtpCapabilities.headerExtensions
          .removeWhere((he) => he.uri == 'urn:3gpp:video-orientation');
      completer.complete(rtpCapabilities);
    });
    setEmitTimeout(completer);
    return completer.future;
  }

  joinRoom({required String roomId}) {
    Completer completer = Completer();
    webSocket.emitWithAck('joinRoom', {
      'roomId': roomId,
    }, ack: (Map response) {
      var data = response['data'];
      var error = response['error'];
      if (error != null) completer.completeError(error);
      var rtpCapabilities = RtpCapabilities.fromMap(data['rtpCapabilities']);

      rtpCapabilities.headerExtensions
          .removeWhere((he) => he.uri == 'urn:3gpp:video-orientation');
      completer.complete(rtpCapabilities);
    });
    setEmitTimeout(completer);
    return completer.future;
  }

  leaveRoom() {
    Completer completer = Completer();
    webSocket.emitWithAck('leaveRoom', {}, ack: (Map response) {
      var data = response['data'];
      var error = response['error'];
      if (error != null) completer.completeError(error);
      completer.complete(data);
    });
    setEmitTimeout(completer);
    return completer.future;
  }

  createWebRtcTransport() {
    Completer completer = Completer();
    webSocket.emitWithAck('createWebRtcTransport', {}, ack: (Map response) {
      var data = response['data'];
      var error = response['error'];
      if (error != null) completer.completeError(error);
      completer.complete(data);
    });
    setEmitTimeout(completer);
    return completer.future;
  }

  restartIce({required String transportId}) {
    Completer completer = Completer();
    webSocket.emitWithAck('restartIce', {
      'transportId': transportId,
    }, ack: (Map response) {
      var error = response['error'];
      if (error != null) completer.completeError(error);
      IceParameters iceParameters =
          IceParameters.fromMap(response['data']['iceParameters']);
      completer.complete(iceParameters);
    });
    setEmitTimeout(completer);
    return completer.future;
  }

  pauseProducer({required String producerId}) {
    Completer completer = Completer();
    webSocket.emitWithAck('pauseProducer', {
      'producerId': producerId,
    }, ack: (Map response) {
      var data = response['data'];
      var error = response['error'];
      if (error != null) throw (error);
      completer.complete(data);
    });
    setEmitTimeout(completer);
    return completer.future;
  }

  resumeProducer({required String producerId}) {
    Completer completer = Completer();
    webSocket.emitWithAck('resumeProducer', {
      'producerId': producerId,
    }, ack: (Map response) {
      var data = response['data'];
      var error = response['error'];
      if (error != null) throw (error);
      completer.complete(data);
    });
    setEmitTimeout(completer);
    return completer.future;
  }

  closeProducer({required String producerId}) {
    Completer completer = Completer();
    webSocket.emitWithAck('closeProducer', {
      'producerId': producerId,
    }, ack: (Map response) {
      var data = response['data'];
      var error = response['error'];
      if (error != null) throw (error);
      completer.complete(data);
    });
    setEmitTimeout(completer);
    return completer.future;
  }

  resumeConsumer({required String consumerId}) {
    Completer completer = Completer();
    webSocket.emitWithAck('resumeConsumer', {
      'consumerId': consumerId,
    }, ack: (Map response) {
      var data = response['data'];
      var error = response['error'];
      if (error != null) throw (error);
      completer.complete(data);
    });
    setEmitTimeout(completer);
    return completer.future;
  }

  connectWebRtcTransport({
    required String transportId,
    required Map dtlsParameters,
  }) {
    Completer completer = Completer();
    webSocket.emitWithAck('connectWebRtcTransport', {
      'transportId': transportId,
      'dtlsParameters': dtlsParameters,
    }, ack: (Map response) {
      completer.complete(response);
    });
    setEmitTimeout(completer);
    return completer.future;
  }

  produce({
    required String transportId,
    required Map produceParams,
  }) {
    Completer completer = Completer();
    webSocket.emitWithAck('produce', {
      'transportId': transportId,
      'produceParams': produceParams,
    }, ack: (Map response) {
      var data = response['data'];
      var error = response['error'];
      if (error != null) throw (error);
      completer.complete(data);
    });
    setEmitTimeout(completer);
    return completer.future;
  }

  consume({
    required String transportId,
    required String producerId,
    required Map rtpCapabilities,
  }) {
    Completer completer = Completer();
    webSocket.emitWithAck('consume', {
      'transportId': transportId,
      'producerId': producerId,
      'rtpCapabilities': rtpCapabilities,
    }, ack: (Map response) async {
      var data = response['data'];
      var error = response['error'];
      if (error != null) throw error;
      completer.complete(data);
    });
    setEmitTimeout(completer);
    return completer.future;
  }

  getOtherPeers() {
    Completer completer = Completer();
    webSocket.emitWithAck('getOtherPeers', {
      'peerId': peerId,
    }, ack: (Map response) async {
      var error = response['error'];
      var data = response['data'];
      if (error != null) throw error;
      List<dynamic> peers = data['peers'];
      completer.complete(peers);
    });
    setEmitTimeout(completer);
    return completer.future;
  }
}
