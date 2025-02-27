

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart'as http;
import 'package:flutter/material.dart';
import 'package:webrtc_tutorial/models.dart';


class UserController extends ChangeNotifier{

  var isLoading = true;
  var getUserData = <Data>[];



  Map<String, String> get authHeader => {
    HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
  };

  Future<dynamic> getUserApi() async {
    try {
      final response = await http.get(Uri.parse("https://reqres.in/api/users?page=2"),
          headers: authHeader);
      Map<String, dynamic> responseBody = json.decode(response.body);
      debugPrint("getUserApi");
      debugPrint(response.body);
      if (response.statusCode == 200) {
        isLoading = false;
        Models model = Models.fromJson(responseBody);
        getUserData = model.data!;
        notifyListeners();
      }
    }
    on TimeoutException catch (e) {
      isLoading = false;
      notifyListeners();
    } on SocketException catch (e) {
      isLoading = false;
      notifyListeners();
    } on Error catch (e) {
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
    }

    return null;
  }

}