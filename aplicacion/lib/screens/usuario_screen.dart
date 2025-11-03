import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/usuario_controller.dart'; 

class UsuarioScreen extends StatelessWidget {
  const UsuarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? cedulaArg = ModalRoute.of(context)?.settings.arguments as String?;
    
    if (cedulaArg == null) {
      return const Scaffold(
        body: Center(child: Text('Error: Cédula de usuario no recibida. Vuelva a iniciar sesión.')),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        final controller = UsuarioController();
        controller.loadUserData(cedulaArg); 
        return controller;
      },
      child: Consumer<UsuarioController>(
        builder: (context, controller, child) {
          final TextEditingController descripcionController = TextEditingController();
          final _formKey = GlobalKey<FormState>();
          final color = const Color(0xFF003366);

          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Solicitud de Servicio',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              backgroundColor: color,
              automaticallyImplyLeading: false,
              actions: [
                // Botón de cerrar sesión, usando la lógica del Controller
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () => controller.logout(context),
                  tooltip: 'Cerrar Sesión',
                ),
              ],
            ),
            body: (controller.isLoading && controller.userData == null && controller.errorMessage == null)
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(context, controller, _formKey, color, descripcionController, cedulaArg),
          );
        },
      ),
    );
  }
  
  Widget _buildContent(
    BuildContext context, 
    UsuarioController controller,
    GlobalKey<FormState> formKey, 
    Color color,
    TextEditingController descripcionController,
    String cedulaUsuario, 
  ) {
    // Manejo de la acción de envío
    void handleInsertService() async {
      controller.clearError();
      if (!formKey.currentState!.validate()) {
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardando servicio...')),
      );

      // 5. Llamada a la lógica del Controller, usando la cédula directamente
      final success = await controller.insertService(
        descripcion: descripcionController.text, 
        cedulaUsuario: cedulaUsuario,
      );

      // Manejo de la respuesta
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Servicio creado con éxito para ${controller.userData?.nombre ?? "el usuario"}.'),
            backgroundColor: Colors.green,
          ),
        );
        descripcionController.clear();
      } else if (controller.errorMessage != null) {
        // Mostramos el error del Controller en un SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(controller.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (controller.errorMessage != null && controller.userData == null) {
       return Center(
         child: Padding(
           padding: const EdgeInsets.all(20.0),
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
               const SizedBox(height: 10),
               Text(
                 'Error al cargar la información del usuario:',
                 style: TextStyle(fontSize: 18, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 5),
               Text(
                 controller.errorMessage!,
                 style: const TextStyle(fontSize: 16),
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 20),
               // Opción para cerrar sesión si los datos no cargan
               TextButton.icon(
                  onPressed: () => controller.logout(context),
                  icon: const Icon(Icons.logout, color: Colors.grey),
                  label: const Text('Volver al Login', style: TextStyle(fontSize: 16, color: Colors.grey)),
               ),
             ],
           ),
         ),
       );
    }


    // Contenido principal del formulario
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(Icons.person_add_alt_1, size: 80, color: color),
            const SizedBox(height: 10),
            Text(
              // 6. Vista simplificada, mostrando solo el nombre
              'Bienvenido, ${controller.userData?.nombre ?? 'Usuario'}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color, 
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            const Text(
              'Registro de Solicitudes',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E3A8A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Campo de Descripción del Servicio
            TextFormField(
              controller: descripcionController,
              decoration: InputDecoration(
                labelText: 'Descripción del Servicio',
                hintText: 'Describa su problema e indique su departamento...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.description, color: color),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, ingrese una descripción del servicio.';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Información sobre el estado inicial
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.timer, color: color),
              title: const Text('Estado Inicial:'),
              trailing: Text(
                '${controller.initialStatus} (Pendiente)',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ),

            const SizedBox(height: 40),

            // Botón de Envío (Deshabilitado durante la carga)
            ElevatedButton.icon(
              onPressed: controller.isLoading ? null : handleInsertService,
              icon: controller.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: Text(
                controller.isLoading ? 'Enviando...' : 'Solicitar Servicio',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}