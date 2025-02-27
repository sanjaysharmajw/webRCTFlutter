// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:webrtc_tutorial/Web_RTC/webrtc_service.dart';
// import 'package:webrtc_tutorial/user_list.dart';
//
// void main() {
//   runApp(
//     ChangeNotifierProvider(
//       create: (context) => WebRTCService(),
//       child: MyApp(),
//     ),
//   );
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//         debugShowCheckedModeBanner: false,
//         home: UserListScreen()
//       //VideoCallScreen(),
//     );
//   }
// }
//
// class VideoCallScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<WebRTCService>(
//       builder: (context, service, child) {
//         return SafeArea(
//           child: Scaffold(
//             body: Stack(
//               children: [
//                 if (!service.isRemoteFullScreen)
//                   Positioned.fill(
//                     child: GestureDetector(
//                       onDoubleTap: () => service.toggleFullScreen(true),
//                       child: Stack(
//                         children: [
//                           RTCVideoView(
//                             service.localRenderer,
//                             objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
//                           ),
//                           AnimatedOpacity(
//                             opacity: service.isSwitchingCamera ? 0.0 : 1.0,
//                             duration: Duration(milliseconds: 300),
//                             child: RTCVideoView(
//                               service.localRenderer,
//                               objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//
//                 if (service.remoteRenderer.srcObject != null)
//                   Positioned(
//                     top: service.isRemoteFullScreen ? 0 : service.remoteViewTop,
//                     left: service.isRemoteFullScreen ? 0 : service.remoteViewLeft,
//                     right: service.isRemoteFullScreen ? 0 : null,
//                     bottom: service.isRemoteFullScreen ? 0 : null,
//                     width: service.isRemoteFullScreen ? null : 150,
//                     height: service.isRemoteFullScreen ? null : 200,
//                     child: Stack(
//                       children: [
//                         GestureDetector(
//                           onPanUpdate: service.isRemoteFullScreen
//                               ? null
//                               : (details) {
//                             final screenWidth = MediaQuery.of(context).size.width;
//                             final screenHeight = MediaQuery.of(context).size.height;
//                             final newTop = (service.remoteViewTop + details.delta.dy)
//                                 .clamp(0.0, screenHeight - 200 - AppBar().preferredSize.height);
//                             final newLeft = (service.remoteViewLeft + details.delta.dx)
//                                 .clamp(0.0, screenWidth - 150);
//                             service.updateRemotePosition(newTop, newLeft);
//                           },
//                           onTap: () => service.toggleFullScreen(false),
//                           child: Container(
//                             decoration: BoxDecoration(
//                               borderRadius: service.isRemoteFullScreen
//                                   ? null
//                                   : BorderRadius.circular(10),
//                             ),
//                             child: ClipRRect(
//                               borderRadius: service.isRemoteFullScreen
//                                   ? BorderRadius.zero
//                                   : BorderRadius.circular(10),
//                               child: RTCVideoView(
//                                 service.remoteRenderer,
//                                 objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
//                               ),
//                             ),
//                           ),
//                         ),
//                         Positioned(
//                           bottom: 8,
//                           right: 8,
//                           child: Row(
//                             children: [
//                               Container(
//                                 padding: EdgeInsets.all(4),
//                                 decoration: BoxDecoration(
//                                   color: Colors.black54,
//                                   borderRadius: BorderRadius.circular(20),
//                                 ),
//                                 child: Icon(
//                                   service.remoteVideoOn ? Icons.videocam : Icons.videocam_off,
//                                   color: Colors.white,
//                                   size: 20,
//                                 ),
//                               ),
//                               SizedBox(width: 4),
//                               Container(
//                                 padding: EdgeInsets.all(4),
//                                 decoration: BoxDecoration(
//                                   color: Colors.black54,
//                                   borderRadius: BorderRadius.circular(20),
//                                 ),
//                                 child: Icon(
//                                   service.remoteAudioOn ? Icons.mic : Icons.mic_off,
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
//
//                 if (service.isRemoteFullScreen && service.localRenderer.srcObject != null)
//                   Positioned(
//                     top: service.remoteViewTop,
//                     left: service.remoteViewLeft,
//                     width: 150,
//                     height: 200,
//                     child: GestureDetector(
//                       onPanUpdate: (details) {
//                         final screenWidth = MediaQuery.of(context).size.width;
//                         final screenHeight = MediaQuery.of(context).size.height;
//                         final newTop = (service.remoteViewTop + details.delta.dy)
//                             .clamp(0.0, screenHeight - 200 - AppBar().preferredSize.height);
//                         final newLeft = (service.remoteViewLeft + details.delta.dx)
//                             .clamp(0.0, screenWidth - 150);
//                         service.updateRemotePosition(newTop, newLeft);
//                       },
//                       onTap: () => service.toggleFullScreen(true),
//                       child: Container(
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: ClipRRect(
//                           borderRadius: BorderRadius.circular(10),
//                           child: Stack(
//                             children: [
//                               RTCVideoView(
//                                 service.localRenderer,
//                                 objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
//                               ),
//                               AnimatedOpacity(
//                                 opacity: service.isSwitchingCamera ? 0.0 : 1.0,
//                                 duration: Duration(milliseconds: 300),
//                                 child: RTCVideoView(
//                                   service.localRenderer,
//                                   objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//
//                 Align(
//                   alignment: Alignment.bottomCenter,
//                   child: Padding(
//                     padding: const EdgeInsets.all(20.0),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         InkWell(
//                           onTap: service.toggleVideo,
//                           child: Container(
//                             height: 50,
//                             width: 50,
//                             margin: EdgeInsets.only(right: 10),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.all(Radius.circular(100)),
//                             ),
//                             child: Icon(
//                               service.isVideoOn ? Icons.videocam : Icons.videocam_off,
//                               size: 30,
//                               color: Colors.black,
//                             ),
//                           ),
//                         ),
//                         InkWell(
//                           onTap: () => service.remoteId == null && service.users.isNotEmpty
//                               ? service.makeCall(service.users[0])
//                               : service.endCall(),
//                           child: Container(
//                             height: 50,
//                             width: 50,
//                             margin: EdgeInsets.only(right: 10),
//                             decoration: BoxDecoration(
//                               color: service.remoteId == null ? Colors.greenAccent : Colors.red,
//                               borderRadius: BorderRadius.all(Radius.circular(100)),
//                             ),
//                             child: Icon(
//                               service.remoteId == null ? Icons.call : Icons.phone_disabled,
//                               size: 30,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                         InkWell(
//                           onTap: service.toggleMute,
//                           child: Container(
//                             height: 50,
//                             width: 50,
//                             margin: EdgeInsets.only(right: 10),
//                             decoration: BoxDecoration(
//                               color: service.isMuted ? Colors.grey : Colors.blue,
//                               borderRadius: BorderRadius.all(Radius.circular(100)),
//                             ),
//                             child: Icon(
//                               service.isMuted ? Icons.mic_off : Icons.mic,
//                               size: 30,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                         InkWell(
//                           onTap: service.isSwitchingCamera ? null : service.switchCamera,
//                           child: Container(
//                             height: 50,
//                             width: 50,
//                             margin: EdgeInsets.only(right: 10),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.all(Radius.circular(100)),
//                             ),
//                             child: Stack(
//                               alignment: Alignment.center,
//                               children: [
//                                 Icon(
//                                   Icons.flip_camera_android,
//                                   size: 30,
//                                   color: Colors.black,
//                                 ),
//                                 if (service.isSwitchingCamera)
//                                   CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                     valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
//                                   ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }