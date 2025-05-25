import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import 'resetpassword.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loginOrSignUp(BuildContext context) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final username = _isSignUp ? _usernameController.text.trim() : '';

    if (email.isEmpty || password.isEmpty || (_isSignUp && username.isEmpty)) {
      _showErrorDialog(context, 'Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String apiUrl = _isSignUp ? 'http://172.20.10.4:3000/register' : 'http://172.20.10.4:3000/login';

      final Map<String, String> body = _isSignUp
          ? {
              'email': email,
              'password': password,
              'username': username,
            }
          : {
              'emailOrUsername': email,
              'password': password,
            };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: const {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == (_isSignUp ? 201 : 200) && responseData['success'] == true) {
        final String usernameToPass = _isSignUp
            ? username
            : responseData['user']['name'] ?? 'User';

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainMenu(username: usernameToPass),
          ),
        );
      } else {
        _showErrorDialog(context, responseData['message'] ?? 'Operation failed');
      }
    } catch (e) {
      _showErrorDialog(context, 'Connection error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _forgotPassword(BuildContext context) {
      Navigator.pushNamed(context, '/resetPassword');
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isSignUp ? 'Sign Up Failed' : 'Login Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(50),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo_brin.png',
                width: 300,
                height: 200,
              ),
              const SizedBox(height: 8),
              const Text(
                  'Mobile Farm Monitoring',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(221, 255, 255, 255),
                    ),
                    textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),

              Text(
                _isSignUp
                    ? 'Register to Mobile Smart Farm Monitoring'
                    : 'Login to Mobile Smart Farm Monitoring',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                  textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.purple),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_isSignUp)
                Column(
                  children: [
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Colors.purple),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.purple),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : () => _loginOrSignUp(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 15),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isSignUp ? 'Sign Up' : 'Login',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                    ),
              ),
              const SizedBox(height: 16),

              if (!_isSignUp)
                  TextButton(
                    onPressed: () => _forgotPassword(context),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                const SizedBox(height: 8),

              TextButton(
                onPressed: () {
                  setState(() {
                    _isSignUp = !_isSignUp;
                    _emailController.clear();
                    _passwordController.clear();
                    _usernameController.clear();
                  });
                },
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Login'
                      : 'Create an account',
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}