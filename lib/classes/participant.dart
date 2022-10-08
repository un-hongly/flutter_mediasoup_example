

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mediasoup_client_flutter/mediasoup_client_flutter.dart';

class Participant { 
  String id;

  Producer? audioProducer;
  Producer? videoProducer;

  Consumer? audioConsumer;
  Consumer? videoConsumer;

  MediaStream? videoStream;
  MediaStream? audioStream;

  Transport? sendTransport;
  Transport? recvTransport;
  List<Transport> transports = [];

  RTCVideoRenderer? renderer;

  bool isCameraEnabled = false;
  bool isMicEnabled = false;

  double audioLevel = 0;

  String name = 'Unknown';
  String profileImageUrl = 'assets/images/iphone_cat.jpeg';

  Participant(this.id, );

  setProducer(Producer producer) {
    switch (producer.kind) {
    case 'video': 
      videoProducer = producer;
      break;
    case 'audio': 
      audioProducer = producer;
      break;
    }
  }

  setConsumer(Consumer consumer) {
    switch (consumer.kind) {
    case 'video': 
      videoConsumer = consumer;
      break;
    case 'audio': 
      audioConsumer = consumer;
      break;
    }
  }

  setTransport(Transport transport) {
    transport.direction == Direction.send ? (sendTransport = transport) : (recvTransport = transport);
    transports.add(transport);
  }

  closeAllProducers() {
    audioProducer?.close();
    audioProducer = null;
    videoProducer?.close();
    videoProducer = null;
  }

  closeAllConsumers() async {
    await audioConsumer?.close();
     audioConsumer = null;
    await videoConsumer?.close();
     videoConsumer = null;
  }

  closeAllTransport() async {
    for (var transport in transports) {
      await transport.close();
    }
    transports = [];
    sendTransport = null;
    recvTransport = null;
  }

  closeRenderer() async {
    renderer?.srcObject = null;
    await renderer?.dispose();
    renderer = null;
  }

  closeAllResource() async {
    await closeAllTransport();
    await closeAllProducers();
    await closeAllConsumers();
    await closeRenderer();
    audioStream = null;
    videoStream = null;
  }

  closeAllExceptRenderer() async {
    await closeAllTransport();
    await closeAllProducers();
    await closeAllConsumers();
  }

}