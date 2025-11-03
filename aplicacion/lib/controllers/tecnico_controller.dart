import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_client.dart'; 

class TecnicoController extends ChangeNotifier {
  String? _tecnicoCedula;
  String? get tecnicoCedula => _tecnicoCedula; 

  final String tableName = 'Servicio';
  final String updateTableName = 'Servicio';
  final int newStatus = 2;
  final int receivedStatus = 3;
  final int pendingStatus = 1; 
  final String statusColumnName = 'estado';
  final String reporteColumnName = 'reporte'; 
  final color = Colors.indigo; 

  int? _statusFilter;
  int? get statusFilter => _statusFilter;
  

  String _dateRangeFilter = 'today';
  String get dateRangeFilter => _dateRangeFilter;



  List<Map<String, dynamic>> _serviciosHoy = [];
  List<Map<String, dynamic>> get serviciosHoy => _serviciosHoy;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isUpdating = false;
  bool get isUpdating => _isUpdating;
  
  TecnicoController(); 

  //Metodos para manejar el estado
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setIsUpdating(bool value) {
    _isUpdating = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  Future<void> initialize(String cedula) async {
    if (_tecnicoCedula == cedula && _serviciosHoy.isNotEmpty && !_isLoading) {
      return; 
    }
    _tecnicoCedula = cedula;
    await fetchData(); 
  }


  void _calculateDateRangeForSupabase(
    String range, 
    Function(String start, String end) onCalculated
  ) {
    final now = DateTime.now();
    DateTime startOfPeriodLocal;

    switch (range) {
      case 'last48h':

        final yesterday = now.subtract(const Duration(days: 1));
        startOfPeriodLocal = DateTime(yesterday.year, yesterday.month, yesterday.day);
        break;
      case 'last7d':

        final lastWeek = now.subtract(const Duration(days: 6)); 
        startOfPeriodLocal = DateTime(lastWeek.year, lastWeek.month, lastWeek.day);
        break;
      case 'today':
      default:

        startOfPeriodLocal = DateTime(now.year, now.month, now.day);
        break;
    }
    

    final endOfTomorrowLocal = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    final startFilter = startOfPeriodLocal.toUtc().toIso8601String();
    final endFilter = endOfTomorrowLocal.toUtc().toIso8601String();
    
    onCalculated(startFilter, endFilter);
  }

  Future<void> fetchData() async {
    _setLoading(true);
    _setError(null);

    if (_tecnicoCedula == null) {
      _setError('Error: La cédula del técnico no ha sido inicializada.');
      _setLoading(false);
      return;
    }
    
    String startFilterUTC = '';
    String endFilterUTC = '';

    _calculateDateRangeForSupabase(_dateRangeFilter, (start, end) {
      startFilterUTC = start;
      endFilterUTC = end;
    });

    try {
      var query = supabase
          .from(tableName)
          .select()
          .gte('fecha', startFilterUTC)
          .lt('fecha', endFilterUTC)
          .eq('tecnico', _tecnicoCedula!); 
      
      if (_statusFilter != null) {
        query = query.eq(statusColumnName, _statusFilter!);
      }

      final List<Map<String, dynamic>> response = await query.order('fecha', ascending: true);
      
      _serviciosHoy = response.map((row) {
        if (row['fecha'] is String) {
          row['fecha'] = DateTime.parse(row['fecha']).toLocal(); 
        }
        return row;
      }).toList();

      print('DEBUG: Consulta exitosa. Encontrados ${_serviciosHoy.length} servicios para el filtro.');

    } on PostgrestException catch (e) {
      _setError('Fallo al cargar datos: ${e.message}');
      print('ERROR SUPABASE: ${e.message}'); // Log de error de Supabase
    } catch (e) {
      _setError('Fallo desconocido al cargar datos: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Metodos para cambiar filtros
  void setStatusFilter(int? status) {
    if (_statusFilter != status) {
      _statusFilter = status;
      fetchData();
    }
  }

  void setDateRangeFilter(String range) {
    if (_dateRangeFilter != range) {
      _dateRangeFilter = range;
      fetchData();
    }
  }
  
  //Función para actualizar el estado del servicio
  Future<void> updateServiceStatus(int serviceId, int targetStatus, BuildContext context) async {
    if (_tecnicoCedula == null || _tecnicoCedula!.isEmpty) {
      _setError('Error: Cédula del Técnico no disponible.');
      return;
    }

    _setIsUpdating(true);

    final statusName = targetStatus == newStatus 
        ? 'COMPLETADO' 
        : targetStatus == receivedStatus 
          ? 'RECIBIDO' 
          : 'DESCONOCIDO';
    final statusColor = getStatusColor(targetStatus);

    try {
      final updateData = {
        statusColumnName: targetStatus, 
        'tecnico': _tecnicoCedula,
      };

      if (targetStatus == newStatus) {
        updateData['fecha_culminado'] = DateTime.now().toLocal().toIso8601String();
      } else {
        updateData['fecha_culminado'] = null; 
      }

      await supabase
          .from(updateTableName)
          .update(updateData)
          .eq('id_servicio', serviceId)
          .eq('tecnico', _tecnicoCedula!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Servicio ID $serviceId actualizado a $statusName.'),
          backgroundColor: statusColor,
        ),
      );

      // Recarga los datos 
      await fetchData(); 

    } on PostgrestException catch (e) {
      _setError('Error al actualizar: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar estado a $statusName: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      _setError('Error desconocido al intentar actualizar el estado.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error desconocido al intentar actualizar el estado.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _setIsUpdating(false);
    }
  }
  
  //Función para actualizar el campo reporte
  Future<bool> updateReporte(int serviceId, String reporteContent) async {
    _setIsUpdating(true);
    bool success = false;
    _setError(null);

    try {
      final updateData = {
        reporteColumnName: reporteContent,
      };

      await supabase
          .from(updateTableName)
          .update(updateData)
          .eq('id_servicio', serviceId);
      
      // Actualizamos la lista localmente 
      final index = _serviciosHoy.indexWhere((s) => s['id_servicio'] == serviceId);
      if (index != -1) {
        _serviciosHoy[index]['reporte'] = reporteContent;
        notifyListeners();
      }

      print('DEBUG: Reporte actualizado para servicio ID: $serviceId');
      success = true;

    } on PostgrestException catch (e) {
      _setError('Error al guardar el reporte: ${e.message}');
      print('ERROR SUPABASE (Reporte): ${e.message}');
    } catch (e) {
      _setError('Error desconocido al guardar el reporte.');
    } finally {
      _setIsUpdating(false);
    }
    return success;
  }


  //color del estado
  Color getStatusColor(int estado) {
    switch (estado) {
      case 1:
        return Colors.amber.shade700;
      case 2:
        return Colors.green.shade600;
      case 3:
        return Colors.blue.shade600; 
      default:
        return Colors.grey;
    }
  }
  
  //Función de Logout
  void logout(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/');
  }
}