import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';

class Otp extends StatefulWidget {
  const Otp({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  final String phoneNumber;
  final String verificationId;

  @override
  State<Otp> createState() => _OtpState();
}

class _OtpState extends State<Otp> {
  String? otpCode; 
  bool isLoading = false; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Container(
      decoration: _buildGradientDecoration(context),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildContent(context),
        ),
      ),
    );
  }

  BoxDecoration _buildGradientDecoration(BuildContext context) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Theme.of(context).colorScheme.shadow,
          Theme.of(context).colorScheme.surfaceContainerHigh,
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTitle(),
        const SizedBox(height: 24),
        _buildOtpTextField(context),
        const SizedBox(height: 24),
        _buildSubmitButton(context),
      ],
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Enter OTP',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildOtpTextField(BuildContext context) {
    return OtpTextField(
      numberOfFields: 6,
      showFieldAsBox: false,
      focusedBorderColor: Theme.of(context).colorScheme.primary,
      onSubmit: (String verificationCode) {
        otpCode = verificationCode; 
        FocusScope.of(context).unfocus();
      },
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : () => _verifyOtpAndSignIn(context),  
        style: _buildButtonStyle(context),
        child: isLoading ? _buildLoadingIndicator() : const Text('Submit'),
      ),
    );
  }

  ButtonStyle _buildButtonStyle(BuildContext context) {
    return ElevatedButton.styleFrom(
      elevation: 5,
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.7),
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
    );
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Future<void> _verifyOtpAndSignIn(BuildContext context) async {
    if (isLoading) return;
    setState(() => isLoading = true);

    if (otpCode == null || otpCode!.length != 6) {
      _showSnackBar(context, 'Please enter a valid 6-digit OTP', isError: true);
      setState(() => isLoading = false);
      return;
    }

    try {
      await _signInWithCredential();
      Navigator.of(context).pop(); 
    } on FirebaseAuthException catch (e) {
      _showSnackBar(context, 'Error: ${e.message ?? 'Invalid OTP'}', isError: true);
    } catch (e) {
      _showSnackBar(context, 'Error: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _signInWithCredential() async {
    final credential = PhoneAuthProvider.credential(
      verificationId: widget.verificationId,
      smsCode: otpCode!,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }
}