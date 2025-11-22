import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/tecnico_controller.dart'; 

class TecnicoScreen extends StatelessWidget {
  const TecnicoScreen({super.key});

  final color = Colors.indigo;

  // Opciones de filtro de estado (int? para "Todos")
  final Map<int?, String> statusOptions = const {
    null: 'Todos los Estados',
    1: 'Pendientes',
    2: 'Completados',
    3: 'Recibidos',
  };

  // Opciones de filtro de rango de fecha (String)
  final Map<String, String> dateRangeOptions = const {
    'today': 'Hoy',
    'last48h': 'Ayer y Hoy', 
    'last7d': 'Última Semana', 
  };


  // --- WIDGET DE BARRA DE FILTROS ---
  Widget _buildFilterBar(BuildContext context, TecnicoController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // FILTRO POR ESTADO
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: controller.color.shade400, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: controller.statusFilter,
                  hint: const Text('Filtrar por Estado'),
                  isExpanded: true,
                  icon: Icon(Icons.filter_list, color: controller.color.shade700),
                  items: statusOptions.entries.map((entry) {
                    return DropdownMenuItem<int?>(
                      value: entry.key,
                      child: Text(entry.value, style: TextStyle(
                        color: entry.key != null ? controller.getStatusColor(entry.key!) : Colors.black87,
                        fontWeight: entry.key == controller.statusFilter ? FontWeight.bold : FontWeight.normal,
                      )),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    controller.setStatusFilter(newValue);
                  },
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 10),

          // FILTRO POR FECHA
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: controller.color.shade400, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: controller.dateRangeFilter,
                  hint: const Text('Rango de Fecha'),
                  isExpanded: true,
                  icon: Icon(Icons.calendar_today, color: controller.color.shade700),
                  items: dateRangeOptions.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      controller.setDateRangeFilter(newValue);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // --- MODAL PARA LEER Y EDITAR REPORTE ---
  Future<void> _showReporteModal(
    BuildContext context, 
    TecnicoController controller, 
    Map<String, dynamic> serviceData,
  ) async {
    final serviceId = serviceData['id_servicio'] as int;
    final descripcion = serviceData['descripcion']?.toString() ?? 'Servicio';
    final TextEditingController textController = TextEditingController(
      text: serviceData['reporte']?.toString() ?? '',
    );

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Reporte de Tarea #$serviceId', style: TextStyle(color: controller.color)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Detalle: $descripcion', 
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                const Text('Edite o ingrese su reporte:', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: textController,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: 'Reporte del Servicio',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ListenableBuilder(
              listenable: controller,
              builder: (context, child) {
                final isSaving = controller.isUpdating;
                return ElevatedButton.icon(
                  icon: isSaving
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(isSaving ? 'Guardando...' : 'Guardar Reporte'),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final success = await controller.updateReporte(
                            serviceId, 
                            textController.text,
                          );
                          if (success) {
                            Navigator.of(dialogContext).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fallo al guardar reporte. Intente de nuevo.'), backgroundColor: Colors.red),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: controller.color.shade700,
                    foregroundColor: Colors.white,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? tecnicoCedula = ModalRoute.of(context)?.settings.arguments as String?;

    if (tecnicoCedula == null) {
      return const Scaffold(
        body: Center(child: Text('Error: Cédula del técnico no recibida. Vuelva al login.')),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        final controller = TecnicoController();
        controller.initialize(tecnicoCedula); 
        return controller;
      },
      child: Consumer<TecnicoController>(
        builder: (context, controller, child) {
          if (controller.tecnicoCedula == null) {
            return const Scaffold(
              body: Center(child: Text('Error de inicialización del técnico.')),
            );
          }
          
          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Técnico ${controller.tecnicoCedula!}: Servicios',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              backgroundColor: color.shade800,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () => controller.logout(context),
                  tooltip: 'Cerrar Sesión',
                ),
              ],
            ),
            
            body: _buildBody(context, controller, color),
            
            floatingActionButton: _buildFloatingActionButtons(context, controller, color),
          );
        },
      ),
    );
  }

  // --- MÉTODOS AUXILIARES DE LA UI ---

  Widget _buildBody(BuildContext context, TecnicoController controller, Color color) {
    if (controller.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.handyman, size: 80, color: const Color(0xFF003366)),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            const Text(
              'Cargando servicios...',
              style: TextStyle(color: Color(0xFF003366)),
            ),
          ],
        ),
      );
    }

    if (controller.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.error_outline, size: 80, color: Colors.red.shade700),
              const SizedBox(height: 20),
              Text(
                'Error al cargar datos:\n${controller.errorMessage}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.red.shade900),
              ),
            ],
          ),
        ),
      );
    }

    final dataList = controller.serviciosHoy;

    return Column(
      children: [
        // 1. Barra de Filtros
        _buildFilterBar(context, controller),

        // 2. Mensaje si la lista está vacía
        if (dataList.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: const Color(0xFF003366)),
                  const SizedBox(height: 20),
                  const Text(
                    'No hay tareas que coincidan con los filtros seleccionados.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Color(0xFF003366)),
                  ),
                ],
              ),
            ),
          )
        else
        // 3. Lista de Servicios (envuelta en Expanded)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: dataList.length,
              itemBuilder: (context, index) {
                final row = dataList[index];

                final serviceId = row['id_servicio'];
                final id = row['id_servicio']?.toString() ?? 'N/A';
                final title = row['descripcion']?.toString() ?? 'Sin Descripción';
                final departament = row['departamento']?.toString() ?? 'Sin Descripción';
                final estadoInt = row['estado'] as int? ?? 0;
                
                String estadoTexto = statusOptions[estadoInt] ?? 'Desconocido';
                
                if (serviceId == null || serviceId is! int) {
                  return Card(
                    child: ListTile(
                      title: Text('Error: ID de Servicio no válido para la Tarea $id'),
                      subtitle: const Text('Verifique la columna "id_servicio".'),
                    ),
                  );
                }

                final isServiceUpdating = controller.isUpdating; 
                
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: ListTile(
                    
                    onTap: () {
                      if (!controller.isUpdating) {
                        _showReporteModal(context, controller, row);
                      }
                    },
                    leading: CircleAvatar(
                      backgroundColor: controller.getStatusColor(estadoInt),
                      child: Text(id, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, )),
                    subtitle:Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children:<Widget> [
                      Text('Estado: $estadoTexto'),
                      Text('Departamento: $departament')
                    ],
                    ),
                    
                    // Contenedor de opciones de estado (Completado/Recibido)
                    trailing: PopupMenuButton<int>(
                      icon: isServiceUpdating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.more_vert, color: controller.color),
                      tooltip: 'Cambiar Estado',
                      onSelected: (int targetStatus) {
                        if (serviceId != null) {
                          controller.updateServiceStatus(serviceId, targetStatus, context);
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
                        PopupMenuItem<int>(
                          value: 2,
                          enabled: estadoInt != 2,
                          child: Row(
                            children: [
                              Icon(Icons.done_all, color: controller.getStatusColor(2)),
                              const SizedBox(width: 8),
                              const Text('Completado'),
                            ],
                          ),
                        ),
                        /*PopupMenuItem<int>(
                          value: 3,
                          enabled: estadoInt != 3,
                          child: Row(
                            children: [
                              Icon(Icons.inventory, color: controller.getStatusColor(3)),
                              const SizedBox(width: 8),
                              const Text('Recibido (3)'),
                            ],
                          ),
                        ),*/
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // Botones flotantes
  Widget _buildFloatingActionButtons(BuildContext context, TecnicoController controller, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: "refreshBtn",
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
          onPressed: () {
            controller.fetchData();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Datos recargados.')),
            );
          },
          child: const Icon(Icons.refresh),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
