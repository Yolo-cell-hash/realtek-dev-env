import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:vdb_realtek/providers/user_provider.dart';
import 'package:vdb_realtek/screens/property_onboarding.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    void _sendOtp() {
      if (_phoneController.text.length == 10) {
        // Set userId in provider instead of local variable
        context.read<UserProvider>().setUserId(_phoneController.text);
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent successfully!',
                style: TextStyle(color: Colors.white, fontFamily: "GEG")),
            backgroundColor: theme.colorScheme.primary,
          ),
        );
      }
    }

    void _verifyOtp() {
      if (_otpController.text == "123456") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logging in...',
                style: TextStyle(color: Colors.white, fontFamily: 'GEG')),
            backgroundColor: theme.colorScheme.primary,
          ),
        );
        print("OTP Verified Successfully");
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PropertyOnboarding()),
        );
      }
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  color: theme.colorScheme.secondary,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Login',
                          style: TextStyle(
                              fontSize: 30.0,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'GEG-Bold',
                              color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextFormField(
                            style: const TextStyle(color: Colors.black),
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(15),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              hintText: 'Enter your phone number',
                              labelStyle: const TextStyle(color: Colors.black),
                              prefixIcon: Icon(Icons.phone,
                                  color: theme.colorScheme.primary),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              if (value.length < 10) {
                                return 'Enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _sendOtp,
                            child: const Text('Send OTP'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Visibility(
                          visible: _otpSent,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextFormField(
                              style: const TextStyle(color: Colors.black),
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              enabled: _otpSent,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: InputDecoration(
                                labelText: 'OTP',
                                hintText: 'Enter 6-digit OTP',
                                labelStyle:
                                const TextStyle(color: Colors.black),
                                prefixIcon: Icon(Icons.lock_outline,
                                    color: theme.colorScheme.primary),
                                border: const OutlineInputBorder(),
                                filled: !_otpSent,
                                fillColor: Colors.grey.shade200,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter the OTP';
                                }
                                if (value.length < 6) {
                                  return 'OTP must be 6 digits';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Visibility(
                          visible: _otpSent,
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _otpSent ? _verifyOtp : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Login',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white)),
                            ),
                          ),
                        ),
                        Visibility(
                            visible: _otpSent,
                            child: const SizedBox(height: 20)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
