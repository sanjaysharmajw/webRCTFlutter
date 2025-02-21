//
// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:socket_io_client/socket_io_client.dart' as io;
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: VideoCallScreen(),
//     );
//   }
// }
//
// class VideoCallScreen extends StatefulWidget {
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
//   // Remote status
//   bool _remoteVideoOn = true;
//   bool _remoteAudioOn = true;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     initRenderers();
//     connectToSocket();
//     initWebRTC();
//   }
//
//   Future<void> initRenderers() async {
//     await _localRenderer.initialize();
//     await _remoteRenderer.initialize();
//   }
//
//   void connectToSocket() {
//     socket = io.io('http://192.168.1.17:3001', <String, dynamic>{
//       'transports': ['websocket'],
//       'autoConnect': false,
//     });
//
//     socket.connect();
//     socket.onConnect((_) {
//       print('Connected to server');
//       _selfId = DateTime.now().millisecondsSinceEpoch.toString();
//       socket.emit('register', _selfId);
//     });
//
//     socket.on('userList', (data) {
//       setState(() {
//         _users = List<String>.from(data)..remove(_selfId);
//       });
//     });
//
//     socket.on('incomingCall', (data) async {
//       setState(() {
//         _remoteId = data['from'];
//       });
//       await handleOffer(data['offer']);
//     });
//
//     socket.on('callAnswered', (data) async {
//       await handleAnswer(data['answer']);
//     });
//
//     socket.on('iceCandidate', (data) async {
//       await _peerConnection?.addCandidate(RTCIceCandidate(
//         data['candidate']['candidate'],
//         data['candidate']['sdpMid'],
//         data['candidate']['sdpMLineIndex'],
//       ));
//     });
//
//     socket.on('callEnded', (_) async {
//       await endCall();
//     });
//
//     // Receive remote media status
//     socket.on('remoteMediaStatus', (data) {
//       setState(() {
//         _remoteVideoOn = data['videoOn'];
//         _remoteAudioOn = data['audioOn'];
//       });
//     });
//   }
//
//   Future<void> initWebRTC() async {
//     final Map<String, dynamic> config = {
//       'iceServers': [
//         {'url': 'stun:stun.l.google.com:19302'},
//       ]
//     };
//
//     _peerConnection = await createPeerConnection(config);
//
//     _localStream = await navigator.mediaDevices.getUserMedia({
//       'audio': true,
//       'video': true,
//     });
//     _localRenderer.srcObject = _localStream;
//
//     _peerConnection?.onIceCandidate = (candidate) {
//       if (_remoteId != null) {
//         socket.emit('iceCandidate', {
//           'to': _remoteId,
//           'candidate': {
//             'candidate': candidate.candidate,
//             'sdpMid': candidate.sdpMid,
//             'sdpMLineIndex': candidate.sdpMLineIndex,
//           },
//         });
//       }
//     };
//
//     _peerConnection?.onAddStream = (stream) {
//       _remoteRenderer.srcObject = stream;
//       setState(() {});
//     };
//
//     _localStream?.getTracks().forEach((track) {
//       _peerConnection?.addTrack(track, _localStream!);
//     });
//
//     setState(() {});
//   }
//
//   Future<void> makeCall(String targetId) async {
//     _remoteId = targetId;
//     final offer = await _peerConnection?.createOffer({});
//     await _peerConnection?.setLocalDescription(offer!);
//     socket.emit('callUser', {
//       'from': _selfId,
//       'to': targetId,
//       'offer': offer?.toMap(),
//     });
//   }
//
//   Future<void> handleOffer(dynamic offer) async {
//     await _peerConnection?.setRemoteDescription(
//       RTCSessionDescription(offer['sdp'], offer['type']),
//     );
//     final answer = await _peerConnection?.createAnswer({});
//     await _peerConnection?.setLocalDescription(answer!);
//     socket.emit('answerCall', {
//       'to': _remoteId,
//       'answer': answer?.toMap(),
//     });
//   }
//
//   Future<void> handleAnswer(dynamic answer) async {
//     await _peerConnection?.setRemoteDescription(
//       RTCSessionDescription(answer['sdp'], answer['type']),
//     );
//   }
//
//   Future<void> endCall() async {
//     try {
//       if (_localStream != null) {
//         _localStream!.getTracks().forEach((track) => track.stop());
//         await _localStream?.dispose();
//         _localStream = null;
//       }
//
//       if (_peerConnection != null) {
//         await _peerConnection?.close();
//         _peerConnection = null;
//       }
//
//       _localRenderer.srcObject = null;
//       _remoteRenderer.srcObject = null;
//
//       if (_remoteId != null) {
//         socket.emit('callEnded', {'to': _remoteId});
//       }
//
//       setState(() {
//         _remoteId = null;
//         _isMuted = false;
//         _isVideoOn = true;
//         _remoteVideoOn = true;
//         _remoteAudioOn = true;
//       });
//
//       await initWebRTC();
//     } catch (e) {
//       print('Error ending call: $e');
//     }
//   }
//
//   void _toggleCall() {
//     if (_remoteId == null && _users.isNotEmpty) {
//       makeCall(_users[0]);
//     } else {
//       endCall();
//     }
//   }
//
//   void _toggleFullScreen(bool isLocal) {
//     setState(() {
//       if (isLocal) {
//         _isLocalFullScreen = !_isLocalFullScreen;
//         _isRemoteFullScreen = !_isLocalFullScreen;
//       } else {
//         _isRemoteFullScreen = !_isRemoteFullScreen;
//         _isLocalFullScreen = !_isLocalFullScreen;
//       }
//     });
//   }
//
//   void _toggleMute() {
//     setState(() {
//       _isMuted = !_isMuted;
//       if (_localStream != null) {
//         _localStream!.getAudioTracks().forEach((track) {
//           track.enabled = !_isMuted;
//         });
//       }
//       // Send updated status to remote peer
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
//     setState(() {
//       _isVideoOn = !_isVideoOn;
//       if (_localStream != null) {
//         _localStream!.getVideoTracks().forEach((track) {
//           track.enabled = _isVideoOn;
//         });
//       }
//       // Send updated status to remote peer
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
//     super.didChangeAppLifecycleState(state);
//     if (state == AppLifecycleState.detached) {
//       if (_remoteId != null) {
//         endCall();
//       }
//       socket.disconnect();
//     }
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     endCall();
//     _localRenderer.dispose();
//     _remoteRenderer.dispose();
//     _peerConnection?.dispose();
//     _localStream?.dispose();
//     socket.disconnect();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Scaffold(
//         body: Stack(
//           children: [
//             // Local Video View (shown when not in fullscreen remote mode)
//             if (!_isRemoteFullScreen)
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
//             // Remote Video View with Status Indicators
//             if (_remoteRenderer.srcObject != null)
//               Positioned(
//                 top: _isRemoteFullScreen ? 0 : _remoteViewTop,
//                 left: _isRemoteFullScreen ? 0 : _remoteViewLeft,
//                 right: _isRemoteFullScreen ? 0 : null,
//                 bottom: _isRemoteFullScreen ? 0 : null,
//                 width: _isRemoteFullScreen ? null : 150,
//                 height: _isRemoteFullScreen ? null : 200,
//                 child: Stack(
//                   children: [
//                     GestureDetector(
//                       onPanUpdate: _isRemoteFullScreen
//                           ? null
//                           : (details) {
//                         setState(() {
//                           _remoteViewTop += details.delta.dy;
//                           _remoteViewLeft += details.delta.dx;
//                           final screenWidth = MediaQuery.of(context).size.width;
//                           final screenHeight = MediaQuery.of(context).size.height;
//                           const viewWidth = 150.0;
//                           const viewHeight = 200.0;
//                           _remoteViewTop = _remoteViewTop.clamp(0.0, screenHeight - viewHeight - AppBar().preferredSize.height);
//                           _remoteViewLeft = _remoteViewLeft.clamp(0.0, screenWidth - viewWidth);
//                         });
//                       },
//                       onTap: () => _toggleFullScreen(false),
//                       child: Container(
//                         decoration: BoxDecoration(
//                           borderRadius: _isRemoteFullScreen ? null : BorderRadius.circular(10),
//                         ),
//                         child: ClipRRect(
//                           borderRadius: _isRemoteFullScreen
//                               ? BorderRadius.zero
//                               : BorderRadius.circular(10),
//                           child: RTCVideoView(
//                             _remoteRenderer,
//                             objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
//                           ),
//                         ),
//                       ),
//                     ),
//                     // Remote Status Indicators
//                     Positioned(
//                       bottom: 8,
//                       right: 8,
//                       child: Row(
//                         children: [
//                           // Remote Video Status
//                           Container(
//                             padding: EdgeInsets.all(4),
//                             decoration: BoxDecoration(
//                               color: Colors.black54,
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                             child: Icon(
//                               _remoteVideoOn ? Icons.videocam : Icons.videocam_off,
//                               color: Colors.white,
//                               size: 20,
//                             ),
//                           ),
//                           SizedBox(width: 4),
//                           // Remote Audio Status
//                           Container(
//                             padding: EdgeInsets.all(4),
//                             decoration: BoxDecoration(
//                               color: Colors.black54,
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                             child: Icon(
//                               _remoteAudioOn ? Icons.mic : Icons.mic_off,
//                               color: Colors.white,
//                               size: 20,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//             // Local Video View (small) when remote is fullscreen
//             if (_isRemoteFullScreen && _localRenderer.srcObject != null)
//               Positioned(
//                 top: _remoteViewTop,
//                 left: _remoteViewLeft,
//                 width: 150,
//                 height: 200,
//                 child: GestureDetector(
//                   onPanUpdate: (details) {
//                     setState(() {
//                       _remoteViewTop += details.delta.dy;
//                       _remoteViewLeft += details.delta.dx;
//                       final screenWidth = MediaQuery.of(context).size.width;
//                       final screenHeight = MediaQuery.of(context).size.height;
//                       const viewWidth = 150.0;
//                       const viewHeight = 200.0;
//                       _remoteViewTop = _remoteViewTop.clamp(
//                           0.0, screenHeight - viewHeight - AppBar().preferredSize.height);
//                       _remoteViewLeft = _remoteViewLeft.clamp(0.0, screenWidth - viewWidth);
//                     });
//                   },
//                   onTap: () => _toggleFullScreen(true),
//                   child: Container(
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: ClipRRect(
//                       borderRadius: BorderRadius.circular(10),
//                       child: RTCVideoView(
//                         _localRenderer,
//                         objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//
//             // Controls
//             Align(
//               alignment: Alignment.bottomCenter,
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     InkWell(
//                       onTap: _toggleVideo,
//                       child: Container(
//                         height: 50,
//                         width: 50,
//                         margin: EdgeInsets.only(right: 10),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.all(Radius.circular(100)),
//                         ),
//                         child: Icon(
//                           _isVideoOn ? Icons.videocam : Icons.videocam_off,
//                           size: 30,
//                           color: Colors.black,
//                         ),
//                       ),
//                     ),
//                     InkWell(
//                       onTap: _toggleCall,
//                       child: Container(
//                         height: 60,
//                         width: 60,
//                         margin: EdgeInsets.only(right: 10),
//                         decoration: BoxDecoration(
//                           color: _remoteId == null ? Colors.greenAccent : Colors.red,
//                           borderRadius: BorderRadius.all(Radius.circular(100)),
//                         ),
//                         child: Icon(
//                           _remoteId == null ? Icons.call : Icons.phone_disabled,
//                           size: 30,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                     InkWell(
//                       onTap: _toggleMute,
//                       child: Container(
//                         height: 50,
//                         width: 50,
//                         margin: EdgeInsets.only(right: 10),
//                         decoration: BoxDecoration(
//                           color: _isMuted ? Colors.grey : Colors.blue,
//                           borderRadius: BorderRadius.all(Radius.circular(100)),
//                         ),
//                         child: Icon(
//                           _isMuted ? Icons.mic_off : Icons.mic,
//                           size: 30,
//                           color: Colors.white,
//                         ),
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