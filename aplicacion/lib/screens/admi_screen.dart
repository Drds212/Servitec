import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/admi_controller.dart'; 

class AdminScreen extends StatelessWidget {
  static const String routeName = '/admin';
  final String adminCedula;

  const AdminScreen({Key? key, required this.adminCedula}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return ChangeNotifierProvider(

      create: (_) => AdminController(),
      child: Consumer<AdminController>(
        builder: (context, controller, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Gestion de Servicios', style: TextStyle(color: Colors.white),),
              backgroundColor: const Color(0xFF003366),

              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white,),
                  onPressed: controller.isLoading ? null : () => controller.fetchData(),
                  tooltip: 'Recargar Datos',
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white,),
                  onPressed: () => controller.logout(context),
                  tooltip: 'Cerrar Sesión',
                ),
              ],
            ),
            body: Column(
              children: [
                _buildFilterBar(controller),
                

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildBody(context, controller),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  Widget _buildFilterBar(AdminController controller) {
    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), 
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Expanded(child: _buildDateFilterDropdown(controller)),
          const SizedBox(width: 8), 
          Expanded(child: _buildStatusFilterDropdown(controller)),
        ],
      ),
    );
  }


  Widget _buildDateFilterDropdown(AdminController controller) {

    final Map<DateTimeFilter, String> dateFilterOptions = {
      DateTimeFilter.none: 'Todas',
      DateTimeFilter.today: 'Hoy',
      DateTimeFilter.yesterday: 'Ayer',
      DateTimeFilter.lastWeek: 'Semana Anterior',
    };

    return DropdownButtonFormField<DateTimeFilter>(
      initialValue: controller.dateFilter,
      icon: const Icon(Icons.calendar_month, color: Color(0xFF003366)),
      decoration: InputDecoration(

        labelText: 'Filtrar Fecha', 
        labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
      ),
      items: dateFilterOptions.entries.map((entry) {
        return DropdownMenuItem<DateTimeFilter>(
          value: entry.key,
          child: Text(entry.value),
        );
      }).toList(),
      onChanged: (DateTimeFilter? newValue) {
        if (newValue != null) {
          controller.setDateFilter(newValue);
        }
      },
    );
  }

  Widget _buildStatusFilterDropdown(AdminController controller) {
    return DropdownButtonFormField<int?>(
      initialValue: controller.statusFilter,
      icon: const Icon(Icons.filter_list, color: Color(0xFF003366)),
      decoration: InputDecoration(
        labelText: 'Filtrar Estado', 
        labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todos'),
        ),
        const DropdownMenuItem<int>(
          value: 1,
          child: Text('Pendientes'),
        ),
        const DropdownMenuItem<int>(
          value: 2,
          child: Text('Completados'),
        ),
        const DropdownMenuItem<int>(
          value: 3,
          child: Text('Recibidos'),
        ),
      ],
      onChanged: (int? newValue) {
        controller.setStatusFilter(newValue);
      },
    );
  }


  Widget _buildBody(BuildContext context, AdminController controller) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null) {
      return Center(
        child: Text(
          'Error: ${controller.errorMessage}',
          style: const TextStyle(color: Colors.red, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (controller.allServicios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 10),
            Text(
              controller.statusFilter == null && controller.dateFilter == DateTimeFilter.none
                  ? 'No hay servicios registrados en la base de datos.'
                  : 'No hay servicios que coincidan con los filtros seleccionados.',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Recargar'),
              onPressed: controller.isLoading ? null : () => controller.fetchData(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: controller.allServicios.length,
      itemBuilder: (context, index) {
        final servicio = controller.allServicios[index];
        return ServiceCard(
          servicio: servicio,
          controller: controller,
        );
      },
    );
  }
}



class ServiceCard extends StatelessWidget {
  final Map<String, dynamic> servicio;
  final AdminController controller;

  const ServiceCard({
    Key? key,
    required this.servicio,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = controller.getStatusColor(servicio['estado'] as int? ?? 0);
    final statusName = controller.getStatusName(servicio['estado'] as int? ?? 0);
    final isAssigned = servicio['tecnico'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ID y Estado
                Text(
                  'Servicio #${servicio['id_servicio']}',
                  style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusName,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailRow('Usuario Solicitante:', servicio['usuario_nombre'] ?? 'N/A'),
            _buildDetailRow(
              'Descripción:', 
              servicio['descripcion'] ?? 'Sin descripción',
              isDescription: true,
            ),
            _buildDetailRow(
              'Fecha Creación:', 
              (servicio['fecha'] is DateTime 
                  ? _formatDate(servicio['fecha']) 
                  : 'N/A'),
            ),
            
            _buildDetailRow(
              'Técnico Asignado:', 
              servicio['tecnico_nombre'] ?? 'No Asignado',
              isBold: true,
              color: isAssigned ? Colors.green.shade700 : Colors.red.shade700,
            ),
            
            if (servicio['estado'] == 2) 
              _buildDetailRow(
                'Fecha Culminación:', 
                (servicio['fecha_culminado'] is DateTime 
                    ? _formatDate(servicio['fecha_culminado']) 
                    : 'N/A'),
              ),

            const SizedBox(height: 15),
            
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: Icon(isAssigned ? Icons.edit : Icons.person_add, size: 18),
                label: Text(isAssigned ? 'Reasignar' : 'Asignar Técnico'),
                onPressed: controller.isUpdating 
                    ? null 
                    : () => _showAssignDialog(context, servicio, controller),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAssigned ? Colors.orange.shade700 : Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label, 
    String value, 
    {
      bool isBold = false, 
      Color? color, 
      bool isDescription = false,
    }
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: isDescription ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black87,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }


  void _showAssignDialog(BuildContext context, Map<String, dynamic> servicio, AdminController controller) {

    String? initialTecnicoCedula;
    final tecnicoData = servicio['tecnico'];

    // 1. Intenta obtener el técnico actual (para reasignar)
    if (tecnicoData != null && tecnicoData is Map) {
      initialTecnicoCedula = tecnicoData['cedula']?.toString();
    }
    
    // ⭐ CORRECCIÓN CLAVE: Si es una ASIGNACIÓN nueva, preselecciona el primer técnico
    if (initialTecnicoCedula == null && controller.allTecnicos.isNotEmpty) {
      initialTecnicoCedula = controller.allTecnicos.first.cedula; 
    }
    
    String? selectedTecnicoCedula = initialTecnicoCedula; 

    if (controller.allTecnicos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay técnicos disponibles para asignar. Asegúrese de que hay usuarios con rol 1.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Asignar Técnico a #${servicio['id_servicio']}'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Seleccione un Técnico',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                ),
                // Asegura que el valor inicial sea el preseleccionado (o nulo si no hay técnicos)
                value: selectedTecnicoCedula, 
                hint: const Text('Técnicos Disponibles'),
                items: controller.allTecnicos.map((tecnico) {
                  return DropdownMenuItem<String>(
                    value: tecnico.cedula, 
                    child: Text('${tecnico.nombre} ${tecnico.cedula}'),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedTecnicoCedula = newValue;
                  });
                },
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Asignar'),
              // El botón se habilita si selectedTecnicoCedula NO es null
              onPressed: selectedTecnicoCedula == null || controller.isUpdating
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                      controller.assignTecnico(
                        servicio['id_servicio'],
                        selectedTecnicoCedula!,
                        context,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}