import 'package:draggable_widget/draggable_widget.dart';
import 'package:floating/floating.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:ftchat_video_call/classes/participant.dart';
import 'package:ftchat_video_call/screens/call_actions.dart';
import 'package:ftchat_video_call/screens/remote_view.dart';
import 'package:ftchat_video_call/services/sfu.dart';
import 'package:mediasoup_client_flutter/mediasoup_client_flutter.dart';
import 'package:wakelock/wakelock.dart';

class CallScreen extends StatefulWidget {
  final String myId;
  final String roomId;
  final bool isCameraEnabled;
  final bool isMicEnabled;
  final bool startCall;

  CallScreen({
    required this.myId,
    required this.roomId,
    required this.isCameraEnabled,
    required this.isMicEnabled,
    required this.startCall,
  }) : super(key: Key(myId));

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with WidgetsBindingObserver {
  late final roomId = widget.roomId;
  late Participant me = Participant(widget.myId)
    ..isCameraEnabled = widget.isCameraEnabled
    ..isMicEnabled = widget.isMicEnabled;
  final Device _device = Device();
  String callStatus = 'connecting';
  String facingMode = 'user';
  List<Participant?> participants = [];
  late MediaStream mediaStream;
  final floating = Floating();
  FilterQuality filterQuality = FilterQuality.medium;
  bool isSpeakerEnabled = false;
  bool localViewEnabled = true;
  late SFU sfu;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _enablePiPMode();
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    Wakelock.enable();
    run();
    super.initState();
  } 

  run() async {
    sfu = SFU(widget.myId);
    await sfu.connect();
    setupWebSocketListener();
    sfu.subscribe(roomId: roomId);
    widget.startCall ? _startCall() : _joinCall();
  }

  @override
  dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Wakelock.disable();
    floating.dispose();
    super.dispose();
  }

  setupWebSocketListener() {
    sfu.webSocket.on('connect', (data) { // reconnect
      _joinCall();
    });

    sfu.webSocket.on('disconnect', (data) async {
      _handleWebSocketDisconnected();
    });

    sfu.webSocket.on('newProducer', (peer) {
      consumeParticipantMedia(peer);
    });

    sfu.webSocket.on('peerJoined', (data) {
      _handlePeerJoined(data['peerId']);
    });

    sfu.webSocket.on('peerLeft', (data) {
      _handlePeerLeft(data['peerId']);
    });

    sfu.webSocket.on('peerPausedProducer', (data) {
      _handlePeerPausedProducer(
          data['peerId'], data['producerId'], data['producerKind']);
    });

    sfu.webSocket.on('peerResumedProducer', (data) {
      _handlePeerResumedProducer(
          data['peerId'], data['producerId'], data['producerKind']);
    });

    sfu.webSocket.on('peerClosedProducer', (data) {
      _handlePeerClosedProducer(
          data['peerId'], data['producerId'], data['producerKind']);
    });

    // sfu.webSocket.on('peerVideoOrientationChanged', (data) {
    //   _hanlePeerVideoOrientationChanged(
    //       data['peerId'], data['videoOrientation']);
    // });

    sfu.webSocket.on('audioLevel', (data) {
      _handleAudioLevel(data);
    });

    sfu.webSocket.on('audioSilence', (data) {
      _handleAudioSilence();
    });

    sfu.webSocket.on('activeSpeaker', (data) {
      _handleActiveSpeaker(data['peerId']);
    });
    
  }

  _handleWebSocketDisconnected() async {
    for (var participant in participants) {
      await participant!.closeAllExceptRenderer();
    }
    await me.closeAllExceptRenderer();
    Future.delayed(const Duration(seconds: 15), () {
      if (!sfu.webSocket.connected) {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    });
  }

  _handlePeerJoined(String peerId) async {
    Participant? participant = findParticipantById(peerId);
    setState(() {
      if (participant == null) {
        participants.add(Participant(peerId));
      } else {
        replaceParticipantById(peerId, participant);
      }
    });
  }

  _handlePeerPausedProducer(
      String peerId, String producerId, String producerKind) {
    Participant? participant = findParticipantById(peerId);
    if (participant == null) return;
    setState(() {
      if (producerKind == 'video') {
        participant.isCameraEnabled = false;
      } else {
        participant.isMicEnabled = false;
      }
    });
  }

  _handlePeerResumedProducer(
      String peerId, String producerId, String producerKind) {
    Participant? participant = findParticipantById(peerId);
    if (participant == null) return;
    setState(() {
      if (producerKind == 'video') {
        participant.isCameraEnabled = true;
      } else {
        participant.isMicEnabled = true;
      }
    });
  }

  _handlePeerClosedProducer(
      String peerId, String producerId, String producerKind) {
    setState(() {
      Participant? participant = findParticipantById(peerId);
      if (participant == null) return;
      if (producerKind == 'video') {
        participant.videoConsumer?.close();
        participant.videoConsumer = null;
      } else {
        participant.audioConsumer?.close();
        participant.audioConsumer = null;
      }
    });
  }

  _handlePeerLeft(String peerId) {
    Participant? participant = findParticipantById(peerId);
    if (participant == null) return;
    participant.closeAllResource();
    setState(() {
      participants.remove(participant);
    });

    if (participants.isEmpty) _endCall();
  }

  _handleAudioLevel(List volumeData) {
    // data sample: { peerId, producerId, volume, volumeUnit }
    // volume as dBvo unit range from -127 to 0, the bigger the louder

    for (var e in volumeData) {
      Participant? participant = findParticipantById(e['peerId']);
      if (participant == null) continue;
      double dBvo = e['volume'].toDouble();
      double percentage = dBvo / -127.0;
      double audioLevel = 0;

      if (percentage <= 0.30) {
        audioLevel = 30;
      } else if (percentage <= 0.70) {
        audioLevel = 20;
      } else {
        audioLevel = 10;
      }

      setState(() {
        participant.audioLevel = audioLevel;
      });

      print('=> ${dBvo} ${participant.audioLevel}');
    }
  }

  _handleAudioSilence() {
    for (var e in participants) {
      setState(() {
        e!.audioLevel = 0;
      });
    }
  }

  _handleActiveSpeaker(String peerId) {
    Participant? participant = findParticipantById(peerId);
    print('=> ACTIVE SPEAKER ${peerId} ${participant?.id}');
    if (participant != null) {
      setState(() {
        participants.remove(participant);
        participants.insert(0, participant);
      });
    }
  }

  Participant? findParticipantById(String peerId) {
    return participants.firstWhere((e) => e!.id == peerId, orElse: () => null);
  }

  // _hanlePeerVideoOrientationChanged(
  //     String peerId, Map<String, dynamic> videoOrientation) {
  //   // videoOrientation object sample: {"camera":false,"flip":false,"rotation":270}
  //   Participant? participant = participants[peerId];

  //   if (videoOrientation['rotation'] == 0 ||
  //       videoOrientation['rotation'] == 180) {
  //     participant?.isVideoPotriat = false;
  //   } else if (videoOrientation['rotation'] == 90 ||
  //       videoOrientation['rotation'] == 270) {
  //     participant?.isVideoPotriat = true;
  //   }

  //   setState(() {}); // rebuild UI
  // }

  _startCall() async {
    print("STAT");
    try {
      setState(() {
        callStatus = 'connecting';
      });
      await _createRoom();
      await produceMyMedia();
      await consumeOtherParticipants();
      setState(() {
        callStatus = 'connected';
      });
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  _joinCall() async {
    try {
      setState(() {
        callStatus = 'connecting';
      });
      await _joinRoom();
      await produceMyMedia();
      await consumeOtherParticipants();
      setState(() {
        callStatus = 'connected';
      });
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  _endCall() async {
    for (Participant? participant in participants) {
      await participant!.closeAllResource();
    }
    await me.closeAllResource();
   await sfu.leaveRoom();
    sfu.webSocket.disconnect();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  _toggleMic() {
    if (me.audioProducer == null) {
      enableMic();
    } else {
      bool newStatus = !me.isMicEnabled;
      if (newStatus) {
        me.audioProducer?.resume();
      } else {
        me.audioProducer?.pause();
      }
      setState(() {
        me.isMicEnabled = newStatus;
      });
    }
  }

  _toggleCamera() {
    if (me.videoProducer == null) {
      enableCamera();
    } else {
      disableCamera();
    }
  }

  _switchCamera() async {
    if (facingMode == 'user') {
      facingMode = 'environment';
    } else {
      facingMode = 'user';
    }
    await disableCamera();
    await enableCamera();

    // this is the correct way to switch camera but since the library has bug on .replaceTrack we don't do this for now
    // await closeVideoStream();
    // MediaStream newStream = await createVideoStream(facingMode);
    // await me.videoProducer?.replaceTrack(newStream.getVideoTracks()[0]);
  }

  _toggleSpeaker() {
    var newStatus = !isSpeakerEnabled;
    for (var element in participants) {
      element?.audioConsumer?.stream
          .getAudioTracks()[0]
          .enableSpeakerphone(newStatus);
    }
    setState(() {
      isSpeakerEnabled = !isSpeakerEnabled;
    });
  }

  _createRoom() async {
    RtpCapabilities rtpCapabilities =
       await sfu.createRoom(roomId: roomId);
    if (!_device.loaded) {
      await _device.load(routerRtpCapabilities: rtpCapabilities);
    }
  }

  _joinRoom() async {
    RtpCapabilities rtpCapabilities =
       await sfu.joinRoom(roomId: roomId);
    if (!_device.loaded) {
      await _device.load(routerRtpCapabilities: rtpCapabilities);
    }
  }


  _restartIce(participantId, transportId) async {
    IceParameters iceParameters =
       await sfu.restartIce(transportId: transportId);
    var participant = me.id == participantId ? me : participants[participantId];
    var transport =
        participant?.transports.firstWhere((e) => e.id == transportId);
    if (transport != null) {
      transport.restartIce(iceParameters);
    }
  }

  _refreshNetwork() async {
    for (var participant in [me, ...participants]) {
      for (var transport in participant!.transports) {
        _restartIce(participant.id, transport.id);
      }
    }
  }

  createAudioStream() async {
    me.audioStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    return me.audioStream;
  }

  createVideoStream(String facingMode) async {
    me.videoStream = await navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': {
        'facingMode': facingMode,
      },
    });
    if (me.renderer == null) {
      me.renderer = RTCVideoRenderer();
      await me.renderer?.initialize();
    }
    setState(() {
      me.isCameraEnabled = true;
      me.renderer?.srcObject = me.videoStream;
    });

    return me.videoStream;
  }

  closeAudioStream() async {
    me.audioStream?.getAudioTracks()[0].stop();
    me.audioStream?.dispose();
  }

  closeVideoStream() async {
    me.videoStream?.getVideoTracks()[0].stop();
    me.videoStream?.dispose();
  }

  _setupProducerObserver(Producer producer) {
    producer.observer.on('pause', () {
      sfu.pauseProducer(producerId: producer.id);
    });
    producer.observer.on('resume', () {
      sfu.resumeProducer(producerId: producer.id);
    });
    producer.observer.on('trackended', () {
      print('Producer trackended');
    });
  }

  createSendTransport(Participant participant) async {
    if (participant.sendTransport != null) {
      return participant.sendTransport;
    } else {
      var webRtcTransportParams =await sfu.createWebRtcTransport();
      var sendTransport = _device.createSendTransportFromMap(
          webRtcTransportParams, producerCallback: (Producer producer) {
        participant.setProducer(producer);
        _setupProducerObserver(producer);
      });
      sendTransport.on('connect', (Map data) async {
        var callback = data['callback'];
        var errback = data['errback'];
        try {
         await sfu.connectWebRtcTransport(
            transportId: sendTransport.id,
            dtlsParameters: data['dtlsParameters'].toMap(),
          );
          callback();
        } catch (error) {
          errback(error);
        }
      });

      sendTransport.on('connectionstatechange', (dynamic data) async {
        setState(() {});
        switch (data['connectionState']) {
          case 'failed':
          // _restartIce(participant.id, sendTransport.id);
        }
      });

      sendTransport.on('produce', (Map data) async {
        var callback = data['callback'];
        var errback = data['errback'];
        var kind = data['kind'];
        var rtpParameters = data['rtpParameters'].toMap();
        var appData = data['appData'];
        try {
          var data =await sfu.produce(
            transportId: sendTransport.id,
            produceParams: {
              'kind': kind,
              'rtpParameters': rtpParameters,
              'appData': appData
            },
          );
          callback(data['producerId']);
        } catch (error) {
          errback(error);
        }
      });
      participant.setTransport(sendTransport);
      return sendTransport;
    }
  }

  produceMyMedia() async {
    await createSendTransport(me);

    if (me.isMicEnabled) {
      await enableMic();
    }

    if (me.isCameraEnabled) {
      await enableCamera();
    }
  }

  enableMic() async {
    var audioStream = await createAudioStream();
    me.sendTransport!.produce(
      track: audioStream.getAudioTracks().first,
      stream: audioStream,
      source: 'mic',
    );
    setState(() {
      me.isMicEnabled = true;
    });
  }

  enableCamera() async {
    var videoStream = await createVideoStream(facingMode);
    const videoVPVersion = 8;
    RtpCodecCapability? codec = _device.rtpCapabilities.codecs.firstWhere(
      (RtpCodecCapability c) =>
          c.mimeType.toLowerCase() == 'video/vp$videoVPVersion',
      orElse: () =>
          throw 'desired vp$videoVPVersion codec+configuration is not supported',
    );

    List<RtpEncodingParameters> encodings = videoVPVersion == 9
        ? [
            RtpEncodingParameters(
              scalabilityMode: 'L4T5_KEY',
              scaleResolutionDownBy: 1.0,
            )
          ]
        : [
            // RtpEncodingParameters(maxBitrate: 500000, scaleResolutionDownBy: 4),
            // RtpEncodingParameters(maxBitrate: 1000000, scaleResolutionDownBy: 2),
            // RtpEncodingParameters(maxBitrate: 5000000, scaleResolutionDownBy: 1),
            // RtpEncodingParameters(rid: 'r0', scalabilityMode: 'S1T3' ),
            // RtpEncodingParameters(rid: 'r1', scalabilityMode: 'S1T3' ),
            // RtpEncodingParameters(rid: 'r2', scalabilityMode: 'S1T3' ),
            // RtpEncodingParameters(rid: 'r3', scalabilityMode: 'S1T3' ),
          ];

    me.sendTransport!.produce(
      track: videoStream.getVideoTracks().first,
      stream: videoStream,
      codecOptions: ProducerCodecOptions(videoGoogleStartBitrate: 1000),
      encodings: encodings,
      codec: codec,
      source: 'webcam',
      appData: {
        'source': 'webcam',
      },
    );
    setState(() {
      me.isCameraEnabled = true;
    });
  }

  disableCamera() async {
   await sfu.closeProducer(producerId: me.videoProducer!.id);
    await closeVideoStream();
    me.videoProducer?.close();
    me.videoProducer = null;
    setState(() {
      me.isCameraEnabled = false;
    });
  }

  consumeOtherParticipants() async {
    List<dynamic> peers =await sfu.getOtherPeers();
    for (var peer in peers) {
      consumeParticipantMedia(peer);
    }
  }

  _setupConsumerObserver(Consumer consumer) {
    consumer.observer.on('pause', () {
      print('Consumer paused');
    });
    consumer.observer.on('resume', () {
      print('Consumer resume');
    });
    consumer.observer.on('trackended', () {
      print('Consumer trackended');
    });
  }

  replaceParticipantById(String peerId, Participant newParticipant) {
    Participant? oldDarticipant = findParticipantById(peerId);
    if (oldDarticipant != null) {
      final index = participants
          .indexWhere((element) => element!.id == oldDarticipant.id);
      participants[index] = newParticipant;
    }
  }

  _initializeRenderer(Participant participant, Consumer consumer) async {
    if (consumer.kind == 'audio') {
      // consumer.stream.getAudioTracks()[0].enableSpeakerphone(isSpeakerEnabled);
    }

    if (participant.renderer == null) {
      participant.renderer = RTCVideoRenderer();
      await participant.renderer!.initialize();
      participant.renderer!.srcObject = consumer.stream;
    } else {
      participant.renderer!.srcObject = consumer.stream;
    }
    setState(() {
      // findAndReplaceParticipantById(participant.id, participant);
    }); // rebuild renderer
  }

  createRecvTrasport(Participant participant) async {
    if (participant.recvTransport != null) {
      return participant.recvTransport!;
    } else {
      var webRtcTransportParams =await sfu.createWebRtcTransport();
      Transport recvTransport = _device.createRecvTransportFromMap(
        webRtcTransportParams,
        consumerCallback: (Consumer consumer, [dynamic accept]) async {
          participant.setConsumer(consumer);
          _setupConsumerObserver(consumer);
          await _initializeRenderer(participant, consumer);
          accept({'consumerId': consumer.id});
        },
      );

      recvTransport.on('connect', (Map data, callback, errback) async {
        try {
         await sfu.connectWebRtcTransport(
            transportId: recvTransport.id,
            dtlsParameters: data['dtlsParameters'].toMap(),
          );
          data['callback']();
        } catch (error) {
          data['errback']();
        }
      });
      recvTransport.on('connectionstatechange', (dynamic data) async {
        setState(() {});
        switch (data['connectionState']) {
          case 'failed':
          // _restartIce(participant.id, recvTransport.id);
        }
      });
      participant.setTransport(recvTransport);
      return recvTransport;
    }
  }

  consumeParticipantMedia(peer) async {
    var participantId = peer['_id'];
    Participant? participant = findParticipantById(participantId);
    if (participant == null) {
      participant = Participant(participantId);
      setState(() {
        participants.add(participant);
      });
    }

    Transport recvTransport = await createRecvTrasport(participant);

    for (var producerId in peer['producers']) {
      var data =await sfu.consume(
          transportId: recvTransport.id,
          producerId: producerId,
          rtpCapabilities: _device.rtpCapabilities.toMap());
      recvTransport.consume(
          id: data['id'],
          peerId: data['id'],
          producerId: data['producerId'],
          kind: RTCRtpMediaTypeExtension.fromString(data['kind']),
          rtpParameters: RtpParameters.fromMap(data['rtpParameters']),
          accept: (params) async {
           await sfu.resumeConsumer(consumerId: params['consumerId']);
          });
    }
  }

  renderCallStatus() {
    switch (callStatus) {
      case 'connected':
        return const Text('Connected');
      case 'connecting':
        return const Text('Connecting');
      case 'disconnected':
        return const Text('Disconnected');
    }
  }

  renderProfile(String url) {
    return Image.asset(
      url,
      fit: BoxFit.cover,
    );
  }

  renderLocalView() {
    const ratioHeight = 210.0;
    const ratioWidth = 118.13;
    bool isVideoPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    Widget nothing = const SizedBox.shrink();
    Widget localViewWidget = DraggableWidget(
      topMargin: 40,
      bottomMargin: 40,
      horizontalSpace: 15,
      dragAnimationScale: 1,
      intialVisibility: true,
      normalShadow: const BoxShadow(
        color: Colors.transparent,
      ),
      draggingShadow: const BoxShadow(
        color: Colors.transparent,
      ),
      initialPosition: AnchoringPosition.topRight,
      child: Visibility(
        visible: localViewEnabled,
        replacement: IconButton(
            icon: const Icon(
              Icons.photo_camera,
              size: 30,
            ),
            onPressed: () => setState(() {
                  localViewEnabled = true;
                })),
        child: Container(
          height: isVideoPortrait ? ratioHeight : ratioWidth,
          width: isVideoPortrait ? ratioWidth : ratioHeight,
          decoration: const BoxDecoration(
            color: Colors.black,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              (me.isCameraEnabled && me.renderer != null
                  ? RTCVideoView(
                      me.renderer!,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      filterQuality: filterQuality,
                    )
                  : renderProfile('assets/images/iphone_cat.jpeg')),
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 30,
                  ),
                  onPressed: () => setState(() {
                    localViewEnabled = false;
                  }),
                ),
              )
            ],
          ),
        ),
      ),
    );
    return FutureBuilder(
        future: floating.isPipAvailable,
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.hasData && snapshot.data == true) {
            return PiPSwitcher(
              childWhenEnabled: nothing,
              childWhenDisabled: localViewWidget,
            );
          }
          return localViewWidget;
        });
  }

  Future<void> _enablePiPMode() async {
    final canUsePiP = await floating.isPipAvailable;
    if (canUsePiP) {
      await floating.enable(const Rational.vertical());
    }
  }

  renderActions() {
    Widget nothing = const SizedBox.shrink();
    Widget actionWidget = Positioned.fill(
      bottom: 100,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: CallActions(
          speaker: isSpeakerEnabled,
          video: me.isCameraEnabled,
          mic: me.isMicEnabled,
          speakerAction: _toggleSpeaker,
          micAction: _toggleMic,
          videoAction: _toggleCamera,
          swichCamAction: _switchCamera,
          hangupAction: _endCall,
        ),
      ),
    );
    return FutureBuilder(
        future: floating.isPipAvailable,
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.hasData && snapshot.data == true) {
            return PiPSwitcher(
              childWhenEnabled: nothing,
              childWhenDisabled: actionWidget,
            );
          }
          return actionWidget;
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          RemoteView(participants: participants),
          renderLocalView(),
          renderActions(),
        ],
      ),
    );
  }
}
