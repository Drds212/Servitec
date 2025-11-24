import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../controllers/usuario_controller.dart'; 

// Las constantes de estado (asumo que están definidas en otro archivo, 
// las mantengo aquí como referencia, aunque no son necesarias para la corrección de la UI)
const serviceStatusPending = 1;
const serviceStatusCompleted = 2;
const userCompletionConfirmed = 2; // Asumo que el valor 2 significa confirmado por el usuario

// 1. Clase principal Stateless: Se encarga de obtener argumentos y proveer el Controller.
class UsuarioScreen extends StatelessWidget {
  const UsuarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtener la cédula de los argumentos de la ruta
    final String? cedulaArg =
        ModalRoute.of(context)?.settings.arguments as String?;

    if (cedulaArg == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Error: Cédula de usuario no recibida. Vuelva a iniciar sesión.',
          ),
        ),
      );
    }

    // 2. Se asegura que el Controller y la carga inicial de datos sucedan SOLO UNA VEZ
    // antes de que se construya el resto de la UI.
    return ChangeNotifierProvider(
      create: (context) {
        final controller = UsuarioController();
        // Carga los datos y servicios al crear el Controller.
        controller.loadUserData(cedulaArg);
        controller.fetchUserServices(cedulaArg);
        return controller;
      },
      // 3. Pasa la cédula al widget que contiene la lógica de la UI y las pestañas.
      child: _UsuarioScreenContent(cedulaUsuario: cedulaArg),
    );
  }
}


// 4. Widget Stateful (privado): Se encarga de la UI, el TabController y la interacción.
class _UsuarioScreenContent extends StatefulWidget {
  final String cedulaUsuario;
  
  const _UsuarioScreenContent({required this.cedulaUsuario});

  @override
  State<_UsuarioScreenContent> createState() => _UsuarioScreenContentState();
}

class _UsuarioScreenContentState extends State<_UsuarioScreenContent>
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  final TextEditingController _descripcionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final color = const Color(0xFF003366);

  // NUEVO ESTADO: ID del servicio que se está confirmando actualmente
  int? _confirmingServiceId;

  @override
  void initState() {
    super.initState();
    // Inicialización del TabController
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  // Helper para formatear la fecha TEXT/ISO8601 a un formato legible
  String _formatDate(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      return DateFormat('dd MMM yyyy HH:mm').format(dateTime);
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  // Diálogo de confirmación para el usuario (MANTENIDO)
  Future<bool?> _showConfirmDialog(BuildContext context, int serviceId) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Atención del Servicio'),
          content: Text(
              '¿Desea marcar el servicio ID $serviceId como "Atendido"? Esto indica que el servicio ya fue revisado por un técnico y el problema está resuelto.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Confirmar Atención'),
            ),
          ],
        );
      },
    );
  }

  // --- WIDGETS DE PESTAÑAS ---

  Widget _buildFormTab(UsuarioController controller) {
    void handleInsertService() async {
      controller.clearError();
      if (!_formKey.currentState!.validate()) {
        return;
      }

      // Muestra SnackBar mientras se procesa
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [CircularProgressIndicator(color: Colors.white), SizedBox(width: 10), Text('Guardando servicio...')]),
        duration: Duration(seconds: 15),
        backgroundColor: Color(0xFF1E3A8A),
      ));

      final success = await controller.insertService(
        descripcion: _descripcionController.text,
        cedulaUsuario: widget.cedulaUsuario,
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Servicio creado con éxito para ${controller.userData?.nombre ?? "el usuario"}.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _descripcionController.clear();
        _tabController.animateTo(1); // Mover a la pestaña de historial
      } else if (controller.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(controller.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    final userData = controller.userData;

    // Manejo de Error de Carga Inicial
    if (controller.errorMessage != null && userData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
              const SizedBox(height: 10),
              Text('Error al cargar datos: ${controller.errorMessage!}'),
              TextButton.icon(
                onPressed: () => controller.logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Volver al Login'),
              ),
            ],
          ),
        ),
      );
    }


    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Información de Bienvenida/Perfil
            Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenido, ${userData?.nombre ?? 'Usuario'}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    'Depto: ${userData?.departamento ?? 'Cargando...'} | Cédula: ${userData?.cedula ?? widget.cedulaUsuario}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Registro de Solicitudes',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E3A8A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Campo de Descripción del Servicio
            TextFormField(
              controller: _descripcionController,
              decoration: InputDecoration(
                labelText: 'Descripción del Servicio',
                hintText: 'Describa su problema...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: Icon(Icons.description, color: color),
              ),
              maxLines: 4,
              maxLength: 80,
              validator: (value) {
                if (value == null || value.isEmpty || value.trim().length < 5) {
                  return 'Por favor, ingrese una descripción del servicio (mín. 5 caracteres).';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Información sobre el estado inicial
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.timer, color: Colors.orange.shade700),
              title: const Text('Estado Inicial:'),
              trailing: Text(
                '$serviceStatusPending (Pendiente de inicio)',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700),
              ),
            ),

            const SizedBox(height: 40),

            ElevatedButton.icon(
              onPressed: controller.isLoading ? null : handleInsertService,
              icon: controller.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                controller.isLoading ? 'Enviando...' : 'Solicitar Servicio',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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

  Widget _buildHistoryTab(UsuarioController controller) {
    if (controller.isServicesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.userServices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text(
              'Aún no tienes solicitudes de servicio.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.add_circle),
              label: const Text('Crear Nuevo Servicio'),
            ),
          ],
        ),
      );
    }
    
    // Bandera para saber si el botón de confirmación de ESTE servicio está cargando
    bool isServiceConfirming(int serviceId) => _confirmingServiceId == serviceId;


    return RefreshIndicator(
      onRefresh: () async {
        await controller.fetchUserServices(widget.cedulaUsuario);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: controller.userServices.length,
        itemBuilder: (context, index) {
          final service = controller.userServices[index];

          // 2. Estados del técnico (columna 'estado')
          String systemStatusText = '';
          Color systemStatusColor;
          switch (service.estado) {
            case serviceStatusPending:
              systemStatusText = 'PENDIENTE (Técnico)';
              systemStatusColor = Colors.orange.shade700;
              break;
            case serviceStatusCompleted:
              systemStatusText = 'FINALIZADO (Técnico)';
              systemStatusColor = Colors.lightBlue.shade700;
              break;
            default:
              systemStatusText = 'EN PROGRESO...';
              systemStatusColor = Colors.indigo.shade700;
          }

          // 3. Estado del usuario (columna 'completado_usuario')
          final isConfirmedByUser =
              service.completadoUsuario == userCompletionConfirmed;
          String userConfirmationText = isConfirmedByUser
              ? 'ATENDIDO (Confirmado por Usuario)'
              : 'Pendiente de Confirmación';
          Color userConfirmationColor =
              isConfirmedByUser ? Colors.teal.shade700 : Colors.red.shade700;

          // El botón de confirmación solo se muestra si:
          // 1. El técnico ha completado el servicio (estado = 2)
          // 2. El usuario AÚN NO ha confirmado la atención (completado_usuario = 1)
          final showConfirmationButton =
              service.estado == serviceStatusCompleted && !isConfirmedByUser;

          // Bandera de carga local para el servicio actual
          final isCurrentServiceLoading = isServiceConfirming(service.id);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                  color: isConfirmedByUser
                      ? Colors.teal.shade200
                      : systemStatusColor.withOpacity(0.3),
                  width: 1),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(10),
              leading: CircleAvatar(
                backgroundColor: isConfirmedByUser
                    ? Colors.teal.withOpacity(0.15)
                    : systemStatusColor.withOpacity(0.15),
                child: Icon(
                  isConfirmedByUser
                      ? Icons.check_circle_outline
                      : Icons.pending_actions,
                  color: isConfirmedByUser ? Colors.teal : systemStatusColor,
                ),
              ),
              title: Text(
                'ID ${service.id}: ${service.descripcion}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fecha: ${_formatDate(service.fecha)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  // Estado del Técnico/Sistema
                  Row(
                    children: [
                      Icon(Icons.engineering, size: 14, color: systemStatusColor),
                      const SizedBox(width: 5),
                      // <--- CORRECCIÓN APLICADA AQUÍ: Envolver el Text en Expanded
                      Expanded(
                        child: Text(
                          'Técnico: $systemStatusText',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: systemStatusColor),
                        ),
                      ),
                      // CORRECCIÓN APLICADA AQUÍ --->
                    ],
                  ),
                  // Estado del Usuario (Recepción)
                  Row(
                    children: [
                      Icon(
                          isConfirmedByUser
                              ? Icons.verified_user
                              : Icons.warning_amber,
                          size: 14,
                          color: userConfirmationColor),
                      const SizedBox(width: 5),
                      // <--- CORRECCIÓN APLICADA AQUÍ: Envolver el Text en Expanded
                      Expanded(
                        child: Text(
                          'Usuario: $userConfirmationText',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: userConfirmationColor),
                        ),
                      ),
                      // CORRECCIÓN APLICADA AQUÍ --->
                    ],
                  ),
                ],
              ),
              trailing: showConfirmationButton
                  ? IconButton(
                      icon: isCurrentServiceLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Icon(Icons.check_box, color: Colors.green),
                      tooltip: 'Confirmar Atención (Marcar como Atendido)',
                      // Se deshabilita si CUALQUIER servicio está cargando, o solo este servicio
                      onPressed: isCurrentServiceLoading 
                          ? null
                          : () async {
                              final confirmed =
                                  await _showConfirmDialog(context, service.id);
                              if (confirmed == true) {
                                // 1. INICIAR CARGA (reconstruye el widget para mostrar el spinner)
                                setState(() {
                                  _confirmingServiceId = service.id;
                                });

                                // Llamada al método de confirmación del usuario
                                final success = await controller
                                    .markServiceAsCompletedByUser(
                                        service.id, widget.cedulaUsuario);
                                
                                // 2. FINALIZAR CARGA (reconstruye el widget para ocultar el spinner)
                                setState(() {
                                  _confirmingServiceId = null;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success
                                        ? '¡Servicio ID ${service.id} confirmado con éxito como Atendido!'
                                        : 'Error al confirmar: ${controller.errorMessage}'),
                                    backgroundColor:
                                        success ? Colors.teal : Colors.red,
                                  ),
                                );
                              }
                            },
                    )
                  : (isConfirmedByUser
                      ? const Icon(Icons.done_all, color: Colors.teal)
                      : null), // Icono si ya está confirmado
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET PRINCIPAL DEL CONTENIDO ---

  @override
  Widget build(BuildContext context) {
    // 5. El Consumer accede al Controller que ya fue creado y cargado por el padre (UsuarioScreen)
    return Consumer<UsuarioController>(
      builder: (context, controller, child) {
        // Indicador de Carga Inicial del Perfil (userData es null)
        if (controller.isLoading && controller.userData == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Si hay error de carga, se muestra el mensaje de error completo
        if (controller.errorMessage != null && controller.userData == null) {
            // Se usa el _buildFormTab para reutilizar la lógica del error
            return Scaffold(
              appBar: AppBar(title: const Text('Error de Carga'), backgroundColor: color),
              body: _buildFormTab(controller), 
            );
        }

        // Estructura con TabBar para las dos vistas
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Portal de Servicios',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: color,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () => controller.logout(context),
                tooltip: 'Cerrar Sesión',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(icon: Icon(Icons.add_box), text: 'Solicitar'),
                Tab(icon: Icon(Icons.history), text: 'Historial'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Pestaña 1: Solicitud de Servicio
              _buildFormTab(controller),

              // Pestaña 2: Historial de Servicios
              _buildHistoryTab(controller),
            ],
          ),
        );
      },
    );
  }
}