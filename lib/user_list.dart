import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webrtc_tutorial/VideoCalling.dart';
import 'package:webrtc_tutorial/Web_RTC/webrtc_service.dart';
import 'package:webrtc_tutorial/main.dart';
import 'package:webrtc_tutorial/user_controller.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {



  @override
  Widget build(BuildContext context) {
    final userController = Provider.of<WebRTCService>(context);

    return SafeArea(child: Scaffold(
      appBar: AppBar(title: Text("data"),),
      body: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: userController.users.length,
                itemBuilder: (BuildContext context, int index) {
                  return InkWell(
                    onTap: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) =>  VideoCallScreen()),
                      );
                      userController.makeCall(userController.users[index]);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Container(
                        height: 50,
                        color: Colors.red,
                        child: Center(child: Text(userController.users[index].toString())),
                      ),
                    ),
                  );
                }
            )
          ],
        )

    ));
  }
}
