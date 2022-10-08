import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:ftchat_video_call/classes/participant.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_webrtc/flutter_webrtc.dart';

class RemoteView extends StatefulWidget {
  final List<Participant?> participants;

  const RemoteView({required this.participants, Key? key}) : super(key: key);

  @override
  State<RemoteView> createState() => _RemoteViewState();
}

class _RemoteViewState extends State<RemoteView> {
  int activePageIndex = 0;

  @override
  initState() {
    super.initState();
  }

  renderRoomProfile() {
    return SizedBox.expand(
      child: Image.asset(
        'assets/images/wallpaper.jpeg',
        fit: BoxFit.cover,
      ),
    );
  }

  renderParticipantProfile(Participant participant) {
    return SizedBox.expand(
      child: Image.asset(
        participant.profileImageUrl,
        fit: BoxFit.cover,
      ),
    );
  }

  renderParticipant(Participant participant,
      {RTCVideoViewObjectFit objectFit =
          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      bool card = false}) {
    Widget child = Stack(
      children: [
        participant.renderer == null || participant.videoConsumer == null
            ? renderParticipantProfile(participant)
            : RTCVideoView(
                participant.renderer!,
                filterQuality: FilterQuality.medium,
                objectFit: objectFit,
              ),
      ],
    );
    return card
        ? Card(
            color: Colors.grey,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
              child: child,
            ),
          )
        : child;
  }

  getToalPageCount() {
    return (widget.participants.length / 4).ceil();
  }

  getPageItems(int pageIndex) {
    int currentPage = pageIndex + 1;
    int limit = 4;
    int start = (currentPage - 1) * limit;
    int end = (start + limit) > widget.participants.length
        ? widget.participants.length
        : (start + limit);

    List pageItems = widget.participants.sublist(start, end);
    return pageItems;
  }

  Widget buildItem(BuildContext context, int pageIndex) {
    List pageItems = getPageItems(pageIndex);
    bool showCard = widget.participants.length > 1 ? true : false;
    Widget child;
    if (pageItems.length == 1) {
      child = renderParticipant(
        pageItems[0]!,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        card: showCard,
      );
    } else if (pageItems.length == 2) {
      child = Column(
        children: [
          Expanded(child: renderParticipant(pageItems[0]!, card: showCard)),
          Expanded(child: renderParticipant(pageItems[1]!, card: showCard))
        ],
      );
    } else if (pageItems.length == 3) {
      child = Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: renderParticipant(pageItems[0]!, card: showCard)),
                Expanded(child: renderParticipant(pageItems[1]!, card: showCard))
              ],
            ),
          ),
          Expanded(child: renderParticipant(pageItems[2]!, card: showCard)),
        ],
      );
    } else {
      child = Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: renderParticipant(pageItems[0]!, card: showCard)),
                Expanded(child: renderParticipant(pageItems[1]!, card: showCard))
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: renderParticipant(pageItems[2]!, card: showCard)),
                Expanded(child: renderParticipant(pageItems[3]!, card: showCard)),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      color: Colors.black,
      child: child,
    );
  }

  // Future manageRenderer() async {
  //   List pageItems = getPageItems(activePageIndex);
  //   for (Participant participant in pageItems) {
  //     if (participant.renderer == null) {
  //       participant.renderer = RTCVideoRenderer();
  //       await participant.renderer!.initialize();
  //       participant.renderer!.srcObject = participant.videoConsumer?.stream;
  //       print('=> Page Changed Create');
  //     } else {
  //       participant.renderer!.srcObject = participant.videoConsumer?.stream;
  //       print('=> Page Changed Set');
  //     }
  //     print('=> Ren  ${participant.id} ${participant.renderer}');
  //   }

  //   List notPageItems =
  //       widget.participants.where((e) => !pageItems.contains(e)).toList();
  //   print('=> Not Page Items ${notPageItems.length}');
  //   for (Participant participant in notPageItems) {
  //     await participant.closeRenderer();
  //     print('=> Not Ren  ${participant.id} ${participant.renderer}');
  //   }
  //   setState(() {});

  //   widget.participants.forEach((e) {
  //     print('=> Participant ${e!.id} ${e.videoConsumer} ${e.renderer}');
  //   });
  // }

  renderRemoteView() {
    return Swiper(
      loop: false,
      itemCount: getToalPageCount(),
      itemBuilder: buildItem,
      pagination: getToalPageCount() > 1 ? const SwiperPagination() : null,
      onIndexChanged: (value) => activePageIndex = value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          color: Colors.black,
          child: widget.participants.isEmpty
              ? renderRoomProfile()
              : renderRemoteView()),
    );
  }
}
