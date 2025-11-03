import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/login_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cedulaController = TextEditingController();

    return Consumer<LoginController>(
      builder: (context, controller, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'App Servicio Tecnico',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            elevation: 1,
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Image.asset(
                      'assets/app_logo.jpg',
                      height: 150,
                      width: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 40),

                  // Campo de entrada para la Cédula
                  TextFormField(
                    controller: cedulaController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Cédula de Identidad',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onFieldSubmitted: (_) =>
                        _performLogin(context, controller, cedulaController),
                  ),
                  const SizedBox(height: 30),

                  // Botón de Ingreso
                  _buildLoginButton(context, controller, cedulaController),

                  // Mensaje de Error (usa el estado del controller)
                  if (controller.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Text(
                        controller.errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Función que contiene la lógica de llamada al Controller y la navegación.
  void _performLogin(
    BuildContext context,
    LoginController controller,
    TextEditingController cedulaController,
  ) async {
    final routeName = await controller.handleLogin(
      cedulaController.text.trim(),
    );

    if (routeName != null) {

      Navigator.of(context).pushReplacementNamed(
        routeName,
        arguments: controller.cedulaArgument, 
      );
    }
  }

  Widget _buildLoginButton(
    BuildContext context,
    LoginController controller,
    TextEditingController cedulaController,
  ) {
    return ElevatedButton(
      onPressed: controller.isLoading
          ? null
          : () => _performLogin(context, controller, cedulaController),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        elevation: 5,
      ),
      child: controller.isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
          : const Text(
              'INGRESAR',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
    );
  }
}
