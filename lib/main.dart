import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VideoCallScreen(),
    );
  }
}

class VideoCallScreen extends StatefulWidget {
  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with WidgetsBindingObserver {
  late io.Socket socket;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  String? _selfId;
  String? _remoteId;
  List<String> _users = [];
  dynamic _incomingOffer;
  Timer? _callTimeoutTimer; // Timer for auto-disconnect

  double _remoteViewTop = 8.0;
  double _remoteViewLeft = 8.0;
  bool _isLocalFullScreen = true;
  bool _isRemoteFullScreen = false;
  bool _isMuted = false;
  bool _isVideoOn = true;
  bool _isFrontCamera = true;
  bool _isSwitchingCamera = false;
  bool _remoteVideoOn = true;
  bool _remoteAudioOn = true;

  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initRenderers();
    initNotifications();
    requestPermissions();
    connectToSocket();
    initWebRTC();
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.notification,
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  Future<void> initNotifications() async {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload == 'incoming_call') {
          if (response.actionId == 'accept') {
            print('Accepting call');
            _cancelCallTimeout(); // Cancel timer when accepting
            if (_incomingOffer != null) {
              await handleOffer(_incomingOffer);
            }
          } else if (response.actionId == 'decline') {
            print('Declining call');
            _cancelCallTimeout(); // Cancel timer when declining
            if (_remoteId != null) {
              await endCall();
            }
            await _flutterLocalNotificationsPlugin.cancel(0);
          }
        }
      },
    );

    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'call_channel',
      'Incoming Calls',
      description: 'Notifications for incoming video calls',
      importance: Importance.high,
      playSound: true,
      showBadge: true,
      ledColor: Colors.green,
      sound: RawResourceAndroidNotificationSound('custom_ringtone'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showIncomingCallNotification(String callerId) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'call_channel',
      'Incoming Calls',
      channelDescription: 'Notifications for incoming video calls',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: false,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('custom_ringtone'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          'accept',
          'Accept',
          titleColor: Colors.green,
          showsUserInterface: true,
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        AndroidNotificationAction(
          'decline',
          'Decline',
          titleColor: Colors.red,
          showsUserInterface: true,
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ],
    );

    NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Incoming Call',
      'Call from $callerId',
      platformChannelSpecifics,
      payload: 'incoming_call',
    );

    // Start timeout timer for unanswered call
    _startCallTimeout();
  }

  // Start timer for auto-disconnect
  void _startCallTimeout() {
    _cancelCallTimeout(); // Cancel any existing timer
    _callTimeoutTimer = Timer(Duration(seconds: 15), () async {
      print('Call timeout - auto disconnecting');
      await endCall();
      await _flutterLocalNotificationsPlugin.cancel(0);
    });
  }

  // Cancel the timeout timer
  void _cancelCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
  }

  void connectToSocket() {
    socket = io.io('http://192.168.1.15:3001', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();
    socket.onConnect((_) {
      print('Connected to server');
      _selfId = DateTime.now().millisecondsSinceEpoch.toString();
      socket.emit('register', _selfId);
    });

    socket.on('userList', (data) {
      setState(() {
        _users = List<String>.from(data)..remove(_selfId);
      });
    });

    socket.on('incomingCall', (data) async {
      setState(() {
        _remoteId = data['from'];
      });
      _incomingOffer = data['offer'];
      await _showIncomingCallNotification(data['from']);
    });

    socket.on('callAnswered', (data) async {
      _cancelCallTimeout(); // Cancel timer when call is answered
      await handleAnswer(data['answer']);
    });

    socket.on('iceCandidate', (data) async {
      await _peerConnection?.addCandidate(RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      ));
    });

    socket.on('callEnded', (_) async {
      _cancelCallTimeout(); // Cancel timer when call ends remotely
      await endCall();
      await _flutterLocalNotificationsPlugin.cancel(0);
    });

    socket.on('remoteMediaStatus', (data) {
      setState(() {
        _remoteVideoOn = data['videoOn'];
        _remoteAudioOn = data['audioOn'];
      });
    });
  }

  Future<void> initWebRTC() async {
    final Map<String, dynamic> config = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(config);
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': _isFrontCamera ? 'user' : 'environment'},
    });
    _localRenderer.srcObject = _localStream;

    _peerConnection?.onIceCandidate = (candidate) {
      if (_remoteId != null) {
        socket.emit('iceCandidate', {
          'to': _remoteId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      }
    };

    _peerConnection?.onAddStream = (stream) {
      _remoteRenderer.srcObject = stream;
      setState(() {});
    };

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    setState(() {});
  }

  Future<void> makeCall(String targetId) async {
    _remoteId = targetId;
    final offer = await _peerConnection?.createOffer({});
    await _peerConnection?.setLocalDescription(offer!);
    socket.emit('callUser', {
      'from': _selfId,
      'to': targetId,
      'offer': offer?.toMap(),
    });
  }

  Future<void> handleOffer(dynamic offer) async {
    await _peerConnection?.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );
    final answer = await _peerConnection?.createAnswer({});
    await _peerConnection?.setLocalDescription(answer!);
    socket.emit('answerCall', {
      'to': _remoteId,
      'answer': answer?.toMap(),
    });
  }

  Future<void> handleAnswer(dynamic answer) async {
    await _peerConnection?.setRemoteDescription(
      RTCSessionDescription(answer['sdp'], answer['type']),
    );
    await _flutterLocalNotificationsPlugin.cancel(0);
  }

  Future<void> endCall() async {
    try {
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) => track.stop());
        await _localStream?.dispose();
        _localStream = null;
      }

      if (_peerConnection != null) {
        await _peerConnection?.close();
        _peerConnection = null;
      }

      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;

      if (_remoteId != null) {
        socket.emit('callEnded', {'to': _remoteId});
      }

      setState(() {
        _remoteId = null;
        _isMuted = false;
        _isVideoOn = true;
        _remoteVideoOn = true;
        _remoteAudioOn = true;
        _isFrontCamera = true;
        _isSwitchingCamera = false;
        _incomingOffer = null;
      });

      await initWebRTC();
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_localStream == null || _peerConnection == null) {
      print('Cannot switch camera: Call not active');
      return;
    }

    try {
      setState(() {
        _isSwitchingCamera = true;
      });

      final videoTrack = _localStream!.getVideoTracks().first;
      final cameras = await Helper.cameras;
      if (cameras.length < 2) {
        print('Only one camera available');
        setState(() {
          _isSwitchingCamera = false;
        });
        return;
      }

      final newStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': _isFrontCamera ? 'environment' : 'user'},
      });

      final newVideoTrack = newStream.getVideoTracks().first;
      _localStream!.removeTrack(videoTrack);
      _localStream!.addTrack(newVideoTrack);
      _localRenderer.srcObject = _localStream;

      final senders = await _peerConnection!.getSenders();
      final videoSender =
      senders.firstWhere((sender) => sender.track?.kind == 'video');
      await videoSender.replaceTrack(newVideoTrack);

      videoTrack.stop();

      setState(() {
        _isFrontCamera = !_isFrontCamera;
        _isSwitchingCamera = false;
      });
    } catch (e) {
      print('Error switching camera: $e');
      setState(() {
        _isSwitchingCamera = false;
      });
    }
  }

  void _toggleCall() {
    if (_remoteId == null && _users.isNotEmpty) {
      makeCall(_users[0]);
    } else {
      endCall();
    }
  }

  void _toggleFullScreen(bool isLocal) {
    setState(() {
      if (isLocal) {
        _isLocalFullScreen = !_isLocalFullScreen;
        _isRemoteFullScreen = !_isLocalFullScreen;
      } else {
        _isRemoteFullScreen = !_isRemoteFullScreen;
        _isLocalFullScreen = !_isLocalFullScreen;
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_localStream != null) {
        _localStream!.getAudioTracks().forEach((track) {
          track.enabled = !_isMuted;
        });
      }
      if (_remoteId != null) {
        socket.emit('mediaStatus', {
          'to': _remoteId,
          'videoOn': _isVideoOn,
          'audioOn': !_isMuted,
        });
      }
    });
  }

  void _toggleVideo() {
    setState(() {
      _isVideoOn = !_isVideoOn;
      if (_localStream != null) {
        _localStream!.getVideoTracks().forEach((track) {
          track.enabled = _isVideoOn;
        });
      }
      if (_remoteId != null) {
        socket.emit('mediaStatus', {
          'to': _remoteId,
          'videoOn': _isVideoOn,
          'audioOn': !_isMuted,
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      if (_remoteId != null) {
        endCall();
      }
      socket.disconnect();
    }
  }

  @override
  void dispose() {
    _cancelCallTimeout();
    WidgetsBinding.instance.removeObserver(this);
    endCall();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    _localStream?.dispose();
    socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            if (!_isRemoteFullScreen)
              Positioned.fill(
                child: GestureDetector(
                  onDoubleTap: () => _toggleFullScreen(true),
                  child: Stack(
                    children: [
                      RTCVideoView(
                        _localRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                      AnimatedOpacity(
                        opacity: _isSwitchingCamera ? 0.0 : 1.0,
                        duration: Duration(milliseconds: 300),
                        child: RTCVideoView(
                          _localRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_remoteRenderer.srcObject != null)
              Positioned(
                top: _isRemoteFullScreen ? 0 : _remoteViewTop,
                left: _isRemoteFullScreen ? 0 : _remoteViewLeft,
                right: _isRemoteFullScreen ? 0 : null,
                bottom: _isRemoteFullScreen ? 0 : null,
                width: _isRemoteFullScreen ? null : 150,
                height: _isRemoteFullScreen ? null : 200,
                child: Stack(
                  children: [
                    GestureDetector(
                      onPanUpdate: _isRemoteFullScreen
                          ? null
                          : (details) {
                        setState(() {
                          _remoteViewTop += details.delta.dy;
                          _remoteViewLeft += details.delta.dx;
                          final screenWidth =
                              MediaQuery.of(context).size.width;
                          final screenHeight =
                              MediaQuery.of(context).size.height;
                          const viewWidth = 150.0;
                          const viewHeight = 200.0;
                          _remoteViewTop = _remoteViewTop.clamp(
                              0.0,
                              screenHeight -
                                  viewHeight -
                                  AppBar().preferredSize.height);
                          _remoteViewLeft = _remoteViewLeft.clamp(
                              0.0, screenWidth - viewWidth);
                        });
                      },
                      onTap: () => _toggleFullScreen(false),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: _isRemoteFullScreen
                              ? null
                              : BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: _isRemoteFullScreen
                              ? BorderRadius.zero
                              : BorderRadius.circular(10),
                          child: RTCVideoView(
                            _remoteRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              _remoteVideoOn
                                  ? Icons.videocam
                                  : Icons.videocam_off,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 4),
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              _remoteAudioOn ? Icons.mic : Icons.mic_off,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (_isRemoteFullScreen && _localRenderer.srcObject != null)
              Positioned(
                top: _remoteViewTop,
                left: _remoteViewLeft,
                width: 150,
                height: 200,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _remoteViewTop += details.delta.dy;
                      _remoteViewLeft += details.delta.dx;
                      final screenWidth = MediaQuery.of(context).size.width;
                      final screenHeight = MediaQuery.of(context).size.height;
                      const viewWidth = 150.0;
                      const viewHeight = 200.0;
                      _remoteViewTop = _remoteViewTop.clamp(
                          0.0,
                          screenHeight - viewHeight - AppBar().preferredSize.height);
                      _remoteViewLeft =
                          _remoteViewLeft.clamp(0.0, screenWidth - viewWidth);
                    });
                  },
                  onTap: () => _toggleFullScreen(true),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          RTCVideoView(
                            _localRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                          AnimatedOpacity(
                            opacity: _isSwitchingCamera ? 0.0 : 1.0,
                            duration: Duration(milliseconds: 300),
                            child: RTCVideoView(
                              _localRenderer,
                              objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: _toggleVideo,
                      child: Container(
                        height: 50,
                        width: 50,
                        margin: EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(100)),
                        ),
                        child: Icon(
                          _isVideoOn ? Icons.videocam : Icons.videocam_off,
                          size: 30,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _toggleCall,
                      child: Container(
                        height: 50,
                        width: 50,
                        margin: EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: _remoteId == null ? Colors.greenAccent : Colors.red,
                          borderRadius: BorderRadius.all(Radius.circular(100)),
                        ),
                        child: Icon(
                          _remoteId == null ? Icons.call : Icons.phone_disabled,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _toggleMute,
                      child: Container(
                        height: 50,
                        width: 50,
                        margin: EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: _isMuted ? Colors.grey : Colors.blue,
                          borderRadius: BorderRadius.all(Radius.circular(100)),
                        ),
                        child: Icon(
                          _isMuted ? Icons.mic_off : Icons.mic,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _isSwitchingCamera ? null : _switchCamera,
                      child: Container(
                        height: 50,
                        width: 50,
                        margin: EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(100)),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.flip_camera_android,
                              size: 30,
                              color: Colors.black,
                            ),
                            if (_isSwitchingCamera)
                              CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
