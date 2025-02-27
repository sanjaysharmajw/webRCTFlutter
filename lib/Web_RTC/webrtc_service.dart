import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class WebRTCService with ChangeNotifier {
  late io.Socket socket;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  String? _selfId;
  String? _remoteId;
  List<String> _users = [];

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

  // Getters
  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  String? get remoteId => _remoteId;
  List<String> get users => _users;
  double get remoteViewTop => _remoteViewTop;
  double get remoteViewLeft => _remoteViewLeft;
  bool get isLocalFullScreen => _isLocalFullScreen;
  bool get isRemoteFullScreen => _isRemoteFullScreen;
  bool get isMuted => _isMuted;
  bool get isVideoOn => _isVideoOn;
  bool get isFrontCamera => _isFrontCamera;
  bool get isSwitchingCamera => _isSwitchingCamera;
  bool get remoteVideoOn => _remoteVideoOn;
  bool get remoteAudioOn => _remoteAudioOn;

  WebRTCService() {
    initRenderers();
    connectToSocket();
    initWebRTC();
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    notifyListeners();
  }

  void connectToSocket() {
    socket = io.io('http://192.168.0.103:3001', <String, dynamic>{
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
      _users = List<String>.from(data)..remove(_selfId);
      notifyListeners();
    });

    socket.on('incomingCall', (data) async {
      _remoteId = data['from'];
      await handleOffer(data['offer']);
      notifyListeners();
    });

    socket.on('callAnswered', (data) async {
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
      await endCall();
    });

    socket.on('remoteMediaStatus', (data) {
      _remoteVideoOn = data['videoOn'];
      _remoteAudioOn = data['audioOn'];
      notifyListeners();
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
      notifyListeners();
    };

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    notifyListeners();
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
    notifyListeners();
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

      _remoteId = null;
      _isMuted = false;
      _isVideoOn = true;
      _remoteVideoOn = true;
      _remoteAudioOn = true;
      _isFrontCamera = true;
      _isSwitchingCamera = false;

      await initWebRTC();
      notifyListeners();
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  Future<void> switchCamera() async {
    if (_localStream == null || _peerConnection == null) {
      print('Cannot switch camera: Call not active');
      return;
    }

    try {
      _isSwitchingCamera = true;
      notifyListeners();

      final videoTrack = _localStream!.getVideoTracks().first;
      final cameras = await Helper.cameras;
      if (cameras.length < 2) {
        print('Only one camera available');
        _isSwitchingCamera = false;
        notifyListeners();
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
      final videoSender = senders.firstWhere((sender) => sender.track?.kind == 'video');
      await videoSender.replaceTrack(newVideoTrack);

      videoTrack.stop();

      _isFrontCamera = !_isFrontCamera;
      _isSwitchingCamera = false;
      notifyListeners();
    } catch (e) {
      print('Error switching camera: $e');
      _isSwitchingCamera = false;
      notifyListeners();
    }
  }

  void updateRemotePosition(double top, double left) {
    _remoteViewTop = top;
    _remoteViewLeft = left;
    notifyListeners();
  }

  void toggleFullScreen(bool isLocal) {
    if (isLocal) {
      _isLocalFullScreen = !_isLocalFullScreen;
      _isRemoteFullScreen = !_isLocalFullScreen;
    } else {
      _isRemoteFullScreen = !_isRemoteFullScreen;
      _isLocalFullScreen = !_isLocalFullScreen;
    }
    notifyListeners();
  }

  void toggleMute() {
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
    notifyListeners();
  }

  void toggleVideo() {
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
    notifyListeners();
  }

  void dispose() {
    super.dispose();
    endCall();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    _localStream?.dispose();
    socket.disconnect();
  }
}