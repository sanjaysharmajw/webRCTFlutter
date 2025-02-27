// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:socket_io_client/socket_io_client.dart' as io;
//
// class VideoCallScreen extends StatefulWidget {
//   final String id;
//   const VideoCallScreen({super.key, required this.id});
//
//   @override
//   _VideoCallScreenState createState() => _VideoCallScreenState();
// }
//
// class _VideoCallScreenState extends State<VideoCallScreen> with WidgetsBindingObserver {
//   late io.Socket socket;
//   final _localRenderer = RTCVideoRenderer();
//   final _remoteRenderer = RTCVideoRenderer();
//   RTCPeerConnection? _peerConnection;
//   MediaStream? _localStream;
//   String? _selfId;
//   String? _remoteId;
//   List<String> _users = [];
//
//   double _remoteViewTop = 8.0;
//   double _remoteViewLeft = 8.0;
//   bool _isLocalFullScreen = true;
//   bool _isRemoteFullScreen = false;
//   bool _isMuted = false;
//   bool _isVideoOn = true;
//   bool _isFrontCamera = true;
//   bool _isSwitchingCamera = false;
//   bool _remoteVideoOn = true;
//   bool _remoteAudioOn = true;
//   bool _isInitialized = false;
//   bool _isConnecting = false;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _initialize();
//   }
//
//   Future<void> _initialize() async {
//     try {
//       setState(() => _isConnecting = true);
//       await initRenderers();
//       await connectToSocket();
//       await initWebRTC();
//       setState(() {
//         _isInitialized = true;
//         _isConnecting = false;
//       });
//     } catch (e) {
//       print('Initialization error: $e');
//       setState(() => _isConnecting = false);
//     }
//   }
//
//   Future<void> initRenderers() async {
//     try {
//       await Future.wait([
//         _localRenderer.initialize(),
//         _remoteRenderer.initialize(),
//       ]);
//     } catch (e) {
//       print('Renderer initialization error: $e');
//       rethrow;
//     }
//   }
//
//   Future<void> connectToSocket() async {
//     socket = io.io('http://192.168.1.17:3001', <String, dynamic>{
//       'transports': ['websocket'],
//       'autoConnect': false,
//       'reconnection': true,//Added reconnection
//       'reconnectionAttempts': 5,//Added reconnection attempts
//     });
//
//     socket.connect();
//
//     socket.onConnect((_) {
//       print('Connected to socket server');
//       _selfId = DateTime.now().millisecondsSinceEpoch.toString();
//       socket.emit('register', _selfId);
//     });
//
//     socket.onConnectError((data) => print('Connect error: $data'));
//     socket.onError((data) => print('Socket error: $data'));
//
//     socket.on('userList', (data) {
//       if (mounted && data != null) {
//         setState(() {
//           _users = List<String>.from(data)..remove(_selfId);
//         });
//       }
//     });
//
//     socket.on('incomingCall', (data) async {
//       if (mounted && data != null && data['from'] != null && data['offer'] != null) {
//         setState(() => _remoteId = data['from']);
//         await handleOffer(data['offer']);
//       }
//     });
//
//     socket.on('callAnswered', (data) async {
//       if (data != null && data['answer'] != null) {
//         await handleAnswer(data['answer']);
//       }
//     });
//
//     socket.on('iceCandidate', (data) async {
//       if (data != null && data['candidate'] != null && _peerConnection != null) {
//         await _peerConnection!.addCandidate(RTCIceCandidate(
//           data['candidate']['candidate'],
//           data['candidate']['sdpMid'],
//           data['candidate']['sdpMLineIndex'],
//         ));
//       }
//     });
//
//     socket.on('callEnded', (_) async {
//       await endCall();
//     });
//
//     socket.on('remoteMediaStatus', (data) {
//       if (mounted && data != null) {
//         setState(() {
//           _remoteVideoOn = data['videoOn'] ?? true;
//           _remoteAudioOn = data['audioOn'] ?? true;
//         });
//       }
//     });
//   }
//
//   Future<void> initWebRTC() async {
//     try {
//       final Map<String, dynamic> config = {
//         'iceServers': [
//           {'urls': 'stun:stun.l.google.com:19302'},
//         ],
//         'sdpSemantics': 'unified-plan', // Added for better compatibility
//       };
//
//       _peerConnection = await createPeerConnection(config);
//
//       _peerConnection?.onConnectionState = (state) {
//         print('Connection state: $state');
//         if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
//           endCall();
//         }
//       };
//
//       _localStream = await navigator.mediaDevices.getUserMedia({
//         'audio': true,
//         'video': {
//           'facingMode': _isFrontCamera ? 'user' : 'environment',
//           'mandatory': {
//             'minWidth': '640',
//             'minHeight': '480',
//           },
//         },
//       });
//
//       _localRenderer.srcObject = _localStream;
//
//       _peerConnection?.onIceCandidate = (candidate) {
//         if (_remoteId != null && candidate != null) {
//           socket.emit('iceCandidate', {
//             'to': _remoteId,
//             'candidate': {
//               'candidate': candidate.candidate,
//               'sdpMid': candidate.sdpMid,
//               'sdpMLineIndex': candidate.sdpMLineIndex,
//             },
//           });
//         }
//       };
//
//       _peerConnection?.onTrack = (event) {
//         if (mounted && event.streams.isNotEmpty) {
//           setState(() {
//             _remoteRenderer.srcObject = event.streams[0];
//           });
//         }
//       };
//
//       _localStream?.getTracks().forEach((track) async {
//         await _peerConnection?.addTrack(track, _localStream!);
//       });
//
//     } catch (e) {
//       print('WebRTC initialization error: $e');
//       rethrow;
//     }
//   }
//
//   Future<void> makeCall(String targetId) async {
//     if (_peerConnection == null || _selfId == null) {
//       print('Cannot make call: Not initialized');
//       return;
//     }
//     try {
//       setState(() => _isConnecting = true);
//       _remoteId = targetId;
//       final offer = await _peerConnection!.createOffer({});
//       await _peerConnection!.setLocalDescription(offer);
//       socket.emit('callUser', {
//         'from': _selfId,
//         'to': targetId,
//         'offer': offer.toMap(),
//       });
//       setState(() => _isConnecting = false);
//     } catch (e) {
//       print('Error making call: $e');
//       setState(() => _isConnecting = false);
//     }
//   }
//
//   Future<void> handleOffer(dynamic offer) async {
//     if (_peerConnection == null || offer == null) return;
//     try {
//       await _peerConnection!.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['type']));
//       final answer = await _peerConnection!.createAnswer({});
//       await _peerConnection!.setLocalDescription(answer);
//       socket.emit('answerCall', {
//         'to': _remoteId,
//         'answer': answer.toMap(),
//       });
//     } catch (e) {
//       print('Error handling offer: $e');
//     }
//   }
//
//   Future<void> handleAnswer(dynamic answer) async {
//     if (_peerConnection == null || answer == null) return;
//     try {
//       await _peerConnection!.setRemoteDescription(RTCSessionDescription(answer['sdp'], answer['type']));
//     } catch (e) {
//       print('Error handling answer: $e');
//     }
//   }
//
//   Future<void> endCall() async {
//     try {
//       if (_localStream != null) {
//         _localStream!.getTracks().forEach((track) => track.stop());
//         await _localStream!.dispose();
//       }
//       await _peerConnection?.close();
//
//       if (mounted) {
//         setState(() {
//           _localStream = null;
//           _peerConnection = null;
//           _localRenderer.srcObject = null;
//           _remoteRenderer.srcObject = null;
//           _remoteId = null;
//           _isMuted = false;
//           _isVideoOn = true;
//           _remoteVideoOn = true;
//           _remoteAudioOn = true;
//           _isFrontCamera = true;
//           _isSwitchingCamera = false;
//         });
//       }
//
//       if (_remoteId != null) {
//         socket.emit('callEnded', {'to': _remoteId});
//       }
//
//       await initWebRTC();
//     } catch (e) {
//       print('Error ending call: $e');
//     }
//   }
//
//   Future<void> _switchCamera() async {
//     if (_localStream == null || _peerConnection == null) return;
//
//     setState(() => _isSwitchingCamera = true);
//     try {
//       final cameras = await Helper.cameras;
//       if (cameras.length < 2) {
//         print('Only one camera available');
//         setState(() => _isSwitchingCamera = false);
//         return;
//       }
//
//       final newStream = await navigator.mediaDevices.getUserMedia({
//         'audio': true,
//         'video': {'facingMode': _isFrontCamera ? 'environment' : 'user'},
//       });
//
//       final newVideoTrack = newStream.getVideoTracks().first;
//       final oldVideoTrack = _localStream!.getVideoTracks().first;
//
//       await _localStream!.removeTrack(oldVideoTrack);
//       await _localStream!.addTrack(newVideoTrack);
//       _localRenderer.srcObject = _localStream;
//
//       final senders = await _peerConnection!.getSenders();
//       final videoSender = senders.firstWhere((sender) => sender.track?.kind == 'video');
//       await videoSender.replaceTrack(newVideoTrack);
//
//       oldVideoTrack.stop();
//
//       setState(() {
//         _isFrontCamera = !_isFrontCamera;
//         _isSwitchingCamera = false;
//       });
//     } catch (e) {
//       print('Error switching camera: $e');
//       setState(() => _isSwitchingCamera = false);
//     }
//   }
//
//   void _toggleCall() {
//     if (_isConnecting) return;
//     if (_remoteId == null && widget.id.isNotEmpty) {
//       makeCall(widget.id);
//     } else {
//       endCall();
//     }
//   }
//
//   void _toggleFullScreen(bool isLocal) {
//     if (mounted) {
//       setState(() {
//         _isLocalFullScreen = isLocal ? !_isLocalFullScreen : _isLocalFullScreen;
//         _isRemoteFullScreen = !isLocal ? !_isRemoteFullScreen : _isRemoteFullScreen;
//       });
//     }
//   }
//
//   void _toggleMute() {
//     if (_localStream == null || !mounted) return;
//     setState(() {
//       _isMuted = !_isMuted;
//       _localStream!.getAudioTracks().forEach((track) => track.enabled = !_isMuted);
//       if (_remoteId != null) {
//         socket.emit('mediaStatus', {
//           'to': _remoteId,
//           'videoOn': _isVideoOn,
//           'audioOn': !_isMuted,
//         });
//       }
//     });
//   }
//
//   void _toggleVideo() {
//     if (_localStream == null || !mounted) return;
//     setState(() {
//       _isVideoOn = !_isVideoOn;
//       _localStream!.getVideoTracks().forEach((track) => track.enabled = _isVideoOn);
//       if (_remoteId != null) {
//         socket.emit('mediaStatus', {
//           'to': _remoteId,
//           'videoOn': _isVideoOn,
//           'audioOn': !_isMuted,
//         });
//       }
//     });
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.detached && _remoteId != null) {
//       endCall();
//       socket.disconnect();
//     }
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _localRenderer.srcObject = null;
//     _remoteRenderer.srcObject = null;
//     _localStream?.dispose();
//     _peerConnection?.close();
//     socket.disconnect();
//     _localRenderer.dispose();
//     _remoteRenderer.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Scaffold(
//         body: _isConnecting || !_isInitialized
//             ? const Center(child: CircularProgressIndicator())
//             : Stack(
//           children: [
//             if (!_isRemoteFullScreen && _localRenderer.srcObject != null)
//               Positioned.fill(
//                 child: GestureDetector(
//                   onDoubleTap: () => _toggleFullScreen(true),
//                   child: RTCVideoView(
//                     _localRenderer,
//                     objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
//                   ),
//                 ),
//               ),
//
//             if (_remoteRenderer.srcObject != null)
//               Positioned(
//                 top: _isRemoteFullScreen ? 0 : _remoteViewTop,
//                 left: _isRemoteFullScreen ? 0 : _remoteViewLeft,
//                 right: _isRemoteFullScreen ? 0 : null,
//                 bottom: _isRemoteFullScreen ? 0 : null,
//                 width: _isRemoteFullScreen ? null : 150,
//                 height: _isRemoteFullScreen ? null : 200,
//                 child: GestureDetector(
//                   onPanUpdate: _isRemoteFullScreen
//                       ? null
//                       : (details) {
//                     setState(() {
//                       _remoteViewTop = (_remoteViewTop + details.delta.dy).clamp(
//                         0.0,
//                         MediaQuery.of(context).size.height - 200,
//                       );
//                       _remoteViewLeft = (_remoteViewLeft + details.delta.dx).clamp(
//                         0.0,
//                         MediaQuery.of(context).size.width - 150,
//                       );
//                     });
//                   },
//                   onDoubleTap: () => _toggleFullScreen(false),
//                   child: Container(
//                     decoration: BoxDecoration(
//                       borderRadius: _isRemoteFullScreen ? null : BorderRadius.circular(10),
//                     ),
//                     child: Stack(
//                       children: [
//                         RTCVideoView(
//                           _remoteRenderer,
//                           objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
//                         ),
//                         Positioned(
//                           bottom: 8,
//                           right: 8,
//                           child: Row(
//                             children: [
//                               Container(
//                                 padding: const EdgeInsets.all(4),
//                                 decoration: BoxDecoration(
//                                   color: Colors.black54,
//                                   borderRadius: BorderRadius.circular(20),
//                                 ),
//                                 child: Icon(
//                                   _remoteVideoOn ? Icons.videocam : Icons.videocam_off,
//                                   color: Colors.white,
//                                   size: 20,
//                                 ),
//                               ),
//                               const SizedBox(width: 4),
//                               Container(
//                                 padding: const EdgeInsets.all(4),
//                                 decoration: BoxDecoration(
//                                   color: Colors.black54,
//                                   borderRadius: BorderRadius.circular(20),
//                                 ),
//                                 child: Icon(
//                                   _remoteAudioOn ? Icons.mic : Icons.mic_off,
//                                   color: Colors.white,
//                                   size: 20,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//
//             if (_isRemoteFullScreen && _localRenderer.srcObject != null)
//               Positioned(
//                 top: _remoteViewTop,
//                 left: _remoteViewLeft,
//                 width: 150,
//                 height: 200,
//                 child: GestureDetector(
//                   onPanUpdate: (details) {
//                     setState(() {
//                       _remoteViewTop = (_remoteViewTop + details.delta.dy).clamp(
//                         0.0,
//                         MediaQuery.of(context).size.height - 200,
//                       );
//                       _remoteViewLeft = (_remoteViewLeft + details.delta.dx).clamp(
//                         0.0,
//                         MediaQuery.of(context).size.width - 150,
//                       );
//                     });
//                   },
//                   onDoubleTap: () => _toggleFullScreen(true),
//                   child: Container(
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: RTCVideoView(
//                       _localRenderer,
//                       objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
//                     ),
//                   ),
//                 ),
//               ),
//
//             Align(
//               alignment: Alignment.bottomCenter,
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     IconButton(
//                       onPressed: _toggleVideo,
//                       icon: Icon(_isVideoOn ? Icons.videocam : Icons.videocam_off),
//                       iconSize: 30,
//                       color: Colors.white,
//                       padding: const EdgeInsets.all(10),
//                       style: ButtonStyle(
//                         backgroundColor: MaterialStateProperty.all(Colors.black54),
//                         shape: MaterialStateProperty.all(const CircleBorder()),
//                       ),
//                     ),
//                     IconButton(
//                       onPressed: _toggleCall,
//                       icon: Icon(_remoteId == null ? Icons.call : Icons.call_end),
//                       iconSize: 30,
//                       color: Colors.white,
//                       padding: const EdgeInsets.all(15),
//                       style: ButtonStyle(
//                         backgroundColor: MaterialStateProperty.all(
//                           _remoteId == null ? Colors.green : Colors.red,
//                         ),
//                         shape: MaterialStateProperty.all(const CircleBorder()),
//                       ),
//                     ),
//                     IconButton(
//                       onPressed: _toggleMute,
//                       icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
//                       iconSize: 30,
//                       color: Colors.white,
//                       padding: const EdgeInsets.all(10),
//                       style: ButtonStyle(
//                         backgroundColor: MaterialStateProperty.all(
//                           _isMuted ? Colors.grey : Colors.blue,
//                         ),
//                         shape: MaterialStateProperty.all(const CircleBorder()),
//                       ),
//                     ),
//                     IconButton(
//                       onPressed: _isSwitchingCamera ? null : _switchCamera,
//                       icon: Stack(
//                         alignment: Alignment.center,
//                         children: [
//                           const Icon(Icons.flip_camera_android),
//                           if (_isSwitchingCamera)
//                             const CircularProgressIndicator(
//                               strokeWidth: 2,
//                               valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                             ),
//                         ],
//                       ),
//                       iconSize: 30,
//                       color: Colors.white,
//                       padding: const EdgeInsets.all(10),
//                       style: ButtonStyle(
//                         backgroundColor: MaterialStateProperty.all(Colors.black54),
//                         shape: MaterialStateProperty.all(const CircleBorder()),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }