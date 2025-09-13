// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, complete todos los campos')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // --- LÓGICA DE LOGIN CON FIREBASE ---
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Obtener la instancia singleton de FirebaseAuth
      final auth = FirebaseAuth.instance;

      // Intentar hacer sign in
      final result = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      final user = result.user;
      if (user != null) {
        // Usuario autenticado correctamente
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              username: user.email ?? 'Usuario',
            ),
          ),
        );
      } else {
        // Este caso no debería ocurrir normalmente
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de autenticación')),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Ocurrió un error al iniciar sesión.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'Correo o contraseña incorrectos.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }

    if (mounted)
      setState(() {
        _isLoading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    // UI similar, pero con Correo en lugar de Usuario
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              // Aquí puedes poner tu logo o un ícono
              const Icon(Icons.shield_outlined, size: 80),
              const SizedBox(height: 20),
              Text('Control de Fiscalización',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock_outline)),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Iniciar Sesión'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const RegistrationScreen())),
                child: const Text('¿No tienes una cuenta? Regístrate'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
