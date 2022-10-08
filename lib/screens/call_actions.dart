import 'package:flutter/material.dart';

class CallActions extends StatefulWidget {
  final Function()? hangupAction;
  final Function()? speakerAction;
  final Function()? videoAction;
  final Function()? micAction;
    final Function()? swichCamAction;
  final bool speaker;
  final bool video;
  final bool mic;

  const CallActions({
    Key? key,
    this.hangupAction,
    this.speakerAction,
    this.videoAction,
    this.micAction,
    this.swichCamAction,
    required this.speaker,
    required this.video,
    required this.mic,
  }) : super(key: key);

  @override
  State<CallActions> createState() => _CallActionsState();
}

class _CallActionsState extends State<CallActions>
    with SingleTickerProviderStateMixin {
  AnimationController? rotationController;
  @override
  void initState() {
    rotationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          onPressed: widget.speakerAction,
          style: TextButton.styleFrom(
            backgroundColor:
                widget.speaker ? Colors.white : Colors.grey.withOpacity(0.5),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            elevation: 10,
          ),
          child: Icon(
            widget.speaker ? Icons.volume_up : Icons.volume_off_outlined,
            color:
                !widget.speaker ? Colors.white.withOpacity(0.4) : Colors.black,
          ),
        ),
        TextButton(
          onPressed: widget.videoAction,
          style: TextButton.styleFrom(
            backgroundColor:
                widget.video ? Colors.green : Colors.grey.withOpacity(0.5),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            elevation: 10,
          ),
          child: Icon(
            widget.video ? Icons.videocam : Icons.videocam_off_outlined,
            color: !widget.video ? Colors.white.withOpacity(0.4) : Colors.white,
          ),
        ),
        if (widget.video && widget.swichCamAction != null)
          TextButton(
            onPressed: widget.video
                ? () async {
                    rotationController?.forward(from: 0.0);
                    widget.swichCamAction!();
                  }
                : () {},
            style: TextButton.styleFrom(
              backgroundColor:
                  widget.video ? Colors.white : Colors.grey.withOpacity(0.5),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
              elevation: 10,
            ),
            child: RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0)
                  .animate(rotationController!),
              child: Icon(
                widget.video
                    ? Icons.cameraswitch_rounded
                    : Icons.no_photography_rounded,
                color: !widget.video
                    ? Colors.white.withOpacity(0.4)
                    : Colors.black,
                size: 28,
              ),
            ),
          ),
        TextButton(
          onPressed: widget.micAction,
          style: TextButton.styleFrom(
            backgroundColor:
                widget.mic ? Colors.white : Colors.grey.withOpacity(0.5),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            elevation: 10,
          ),
          child: Icon(
            widget.mic ? Icons.mic : Icons.mic_off_outlined,
            color: !widget.mic ? Colors.white.withOpacity(0.4) : Colors.black,
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.red,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            elevation: 10,
          ),
          onPressed: widget.hangupAction,
          child: const Icon(Icons.call_end, color: Colors.white),
        ),
      ],
    );
  }
}
