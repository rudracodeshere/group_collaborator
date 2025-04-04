import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

const String appId = '325f2c4be2324f5581c3feb909de31dd';
const String token = '';

class CallPage extends StatefulWidget {
  final String callID;

  const CallPage({Key? key, required this.callID}) : super(key: key);

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  late final RtcEngine _engine;
  int? _remoteUid;
  int _localUid = 0;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isCameraOff = false;

  @override
  void initState() {
    super.initState();
    _localUid = Random().nextInt(10000);
    initAgora();
  }

  Future<void> initAgora() async {
    final micStatus = await Permission.microphone.request();
    final camStatus = await Permission.camera.request();

    if (micStatus != PermissionStatus.granted ||
        camStatus != PermissionStatus.granted) {
      print('Permissions not granted');
      return;
    }

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));

    await _engine.enableVideo();

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print('Local user joined: ${connection.localUid}');
          setState(() {
            _isJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print('Remote user joined: $remoteUid');
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          print('Remote user left: $remoteUid');
          setState(() {
            _remoteUid = null;
          });
        },
      ),
    );

    await _engine.joinChannel(
      token: token,
      channelId: widget.callID,
      uid: _localUid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
      ),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  Widget _renderLocalVideo() {
    if (!_isJoined) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: 0),
          ),
        ),
        if (_isCameraOff)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Icon(
              Icons.videocam_off,
              size: 64,
              color: Colors.white,
            ),
          ),
      ],
    );
  }

  Widget _renderRemoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.callID),
        ),
      );
    } else {
      return const Center(child: Text('Waiting for someone to join...'));
    }
  }

  void _onSwitchCamera() async {
    try {
      await _engine.switchCamera();
      print('Camera switched');
    } catch (e) {
      print('Error switching camera: $e');
    }
  }

  void _onToggleMute() async {
    try {
      setState(() {
        _isMuted = !_isMuted;
      });
      await _engine.muteLocalAudioStream(_isMuted);
    } catch (e) {
      print('Error toggling mute: $e');
    }
  }

  void _onToggleCamera() async {
    try {
      setState(() {
        _isCameraOff = !_isCameraOff;
      });

      if (_isCameraOff) {
        await _engine.muteLocalVideoStream(
            true); 
        await _engine.enableLocalVideo(false);
      } else {
        await _engine.muteLocalVideoStream(false);
        await _engine.enableLocalVideo(true);
      }
    } catch (e) {
      print('Error toggling camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
            onPressed: _onToggleMute,
          ),
          IconButton(
            icon: Icon(_isCameraOff ? Icons.videocam_off : Icons.videocam),
            onPressed: _onToggleCamera,
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Switch Camera',
            onPressed: _onSwitchCamera,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _renderLocalVideo()),
          const Divider(height: 1),
          Expanded(child: _renderRemoteVideo()),
        ],
      ),
    );
  }
}
