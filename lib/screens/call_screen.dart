import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CallPage extends StatefulWidget {
  final String callID;

  const CallPage({
    super.key,
    required this.callID,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  String? _userId;
  String? _userName;
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final userId = user.uid;
      String? userName = user.phoneNumber;

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.phoneNumber)
            .get();
        userName = userDoc.data()?['username'] as String? ?? userName;
      } catch (e) {
        debugPrint('Error fetching username: $e');
      }

      setState(() {
        _userId = userId;
        _userName = userName;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userId == null || _userName == null) {
      return const Center(
          child:
              Text("Error: Could not fetch user data.")); // Handle error case
    }

    return ZegoUIKitPrebuiltCall(
      appID: 1654110687,
      appSign:
          'c374f3f05b5e1b02989a10888195677fa3497a989a50784c728868e3cf30c166',
      userID: _userId!,
      userName: _userName!,
      callID: widget.callID,
      config: ZegoUIKitPrebuiltCallConfig.groupVideoCall(),
    );
  }
}
