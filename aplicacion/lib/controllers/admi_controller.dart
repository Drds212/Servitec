import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_client.dart'; 

enum DateTimeFilter {
  none,
  today,
  yesterday,
  lastWeek,
}

class AdminController extends ChangeNotifier {

  final String tableName = 'Servicio';
  final String usuarioTableName = 'Usuario';
  final int pendingStatus = 1;
  final int completedStatus = 2;
  final int receivedStatus = 3;


  List<Map<String, dynamic>> _allServicios = [];
  List<Map<String, dynamic>> get allServicios => _allServicios;

  List<UserData> _allTecnicos = [];
  List<UserData> get allTecnicos => _allTecnicos;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isUpdating = false;
  bool get isUpdating => _isUpdating;


  int? _statusFilter;
  int? get statusFilter => _statusFilter;

  DateTimeFilter _dateFilter = DateTimeFilter.none;
  DateTimeFilter get dateFilter => _dateFilter;


  AdminController() {
    fetchData(); 
  }

  //Establece el estado de carga 
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  //Establece el estado de actualizacion
  void _setIsUpdating(bool value) {
    _isUpdating = value;
    notifyListeners();
  }
  //Establece el mensaje de error 
  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }
  //Establece el estatus del filtro
  void setStatusFilter(int? status) {
    if (_statusFilter != status) {
      _statusFilter = status;
      fetchData(); 
    }
  }

  // Establece el filtrado de fecha 
  void setDateFilter(DateTimeFilter filter) {
    if (_dateFilter != filter) {
      _dateFilter = filter;
      fetchData();
    }
  }
  
  //Calcula la fecha de inicio para el filtro.
  DateTime _getStartDate(DateTimeFilter filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (filter) {
      case DateTimeFilter.today:
        return today;
      case DateTimeFilter.yesterday:
        // Desde el inicio de ayer hasta el final de hoy (filtrado por la consulta de Supabase)
        return today.subtract(const Duration(days: 1));
      case DateTimeFilter.lastWeek:
        // Hace 7 días (inicio del día)
        return today.subtract(const Duration(days: 7));
      case DateTimeFilter.none:
      default:
        // Sin filtro de fecha
        return DateTime.fromMillisecondsSinceEpoch(0); 
    }
  }

  Future<void> fetchTecnicos() async {
    try {
      final response = await supabase
          .from(usuarioTableName)
          .select('cedula, nombre')
          .eq('rol', 1)
          .order('nombre', ascending: true);

      _allTecnicos = response.map((row) => UserData(
        cedula: row['cedula'].toString(), 
        nombre: row['nombre'] as String? ?? 'N/A'
      )).toList();
      notifyListeners();

    } on PostgrestException catch (e) {
      print('ERROR SUPABASE (Tecnicos): ${e.message}');
    } catch (e) {
      print('Error desconocido al cargar técnicos: ${e.toString()}');
    }
  }


  Future<void> fetchData() async {
    _setLoading(true);
    _setError(null);
    

    if (_allTecnicos.isEmpty) {
      await fetchTecnicos();
    }

    try {

      var query = supabase
          .from(tableName)

          .select('*, usuario(nombre), tecnico(nombre, cedula)'); 
      

      if (_statusFilter != null) {
        query = query.eq('estado', _statusFilter!);
      }

      //filtrado de fechas 
      if (_dateFilter != DateTimeFilter.none) {
        final startDate = _getStartDate(_dateFilter);
        final startDateString = startDate.toIso8601String(); 

        query = query.gte('fecha', startDateString);
      }


      final List<Map<String, dynamic>> response = await query.order('fecha', ascending: false);
      

      _allServicios = response.map((row) {

        if (row['fecha'] is String) {
          row['fecha'] = DateTime.parse(row['fecha']).toLocal(); 
        }
        if (row['fecha_culminado'] is String && row['fecha_culminado'] != null) {
          row['fecha_culminado'] = DateTime.parse(row['fecha_culminado']).toLocal(); 
        }
        row['usuario_nombre'] = row['usuario'] != null ? row['usuario']['nombre'] : 'N/A';
        row['tecnico_nombre'] = row['tecnico'] != null ? row['tecnico']['nombre'] : 'No Asignado';
        
        return row;
      }).toList();

      print('DEBUG: Consulta de Admin exitosa. Encontrados ${_allServicios.length} servicios.');

    } on PostgrestException catch (e) {
      _setError('Fallo al cargar datos de servicios: ${e.message}');
      print('ERROR SUPABASE (Admin): ${e.message}'); 
    } catch (e) {
      _setError('Fallo desconocido al cargar datos: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }
    //Asignacion de tecnico
  Future<void> assignTecnico(int serviceId, String tecnicoCedula, BuildContext context) async {
    _setIsUpdating(true);
    _setError(null);

    try {
      final tecnicoData = _allTecnicos.firstWhere((t) => t.cedula == tecnicoCedula);
      final tecnicoNombre = tecnicoData.nombre;

      final updateData = {
        'tecnico': tecnicoCedula,
      };

      await supabase
          .from(tableName)
          .update(updateData)
          .eq('id_servicio', serviceId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Servicio ID $serviceId asignado a $tecnicoNombre.'),
          backgroundColor: Colors.indigo,
        ),
      );

      await fetchData(); 

    } on PostgrestException catch (e) {
      _setError('Error al asignar técnico: ${e.message}');
    } catch (e) {
      _setError('Error inesperado al asignar técnico.');
    } finally {
      _setIsUpdating(false);
    }
  }
  
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
  

  String getStatusName(int estado) {
    switch (estado) {
      case 1:
        return 'PENDIENTE';
      case 2:
        return 'COMPLETADO';
      case 3:
        return 'RECIBIDO';
      default:
        return 'DESCONOCIDO';
    }
  }

  void logout(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/');
  }
}

class UserData {
  final String nombre;
  final String cedula;

  UserData({required this.nombre, required this.cedula});
}