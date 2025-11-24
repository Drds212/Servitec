import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_client.dart';

// Acceso al cliente de Supabase
final supabase = Supabase.instance.client; 

// --- CONSTANTES DE ESTADO ---
// Estado de la solicitud (gestión interna/técnico - columna 'estado')
const int serviceStatusPending = 1; // Pendiente de inicio
const int serviceStatusCompleted = 2; // Completado por técnico
const int serviceStatusReceived = 3; // Estado Recibido (si aplica)

// Estado de confirmación del USUARIO (la nueva columna: 'completado_usuario')
const int userCompletionPending = 1; // Pendiente de confirmación del usuario
const int userCompletionConfirmed = 2; // Confirmado por el usuario (Atendido)


// --- MODELOS DE DATOS ---

class Service {
  final int id;
  final String descripcion;
  final int estado; // Estado del servicio (por técnico/sistema)
  final String fecha;
  final int usuarioCedula;
  final int? completadoUsuario; // NUEVO: Estado de confirmación del usuario

  Service({
    required this.id,
    required this.descripcion,
    required this.estado,
    required this.fecha,
    required this.usuarioCedula,
    this.completadoUsuario, 
  });

  // Mapeo de la respuesta de Supabase (JSON) a objeto Dart
  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      // CRÍTICO: Usar el nombre de columna confirmado 'id_servicio'
      id: json['id_servicio'] as int, 
      descripcion: json['descripcion'] as String,
      estado: json['estado'] as int,
      fecha: json['fecha'] as String,
      // Manejo de tipo para la cédula
      usuarioCedula: json['usuario'] is String 
          ? int.tryParse(json['usuario'] as String) ?? 0 
          : json['usuario'] as int,
      completadoUsuario: json['completado_usuario'] as int?, // Nuevo campo
    );
  }
}

class UserData {
  final String nombre;
  final String cedula;
  final String departamento;

  UserData({
    required this.nombre,
    required this.cedula,
    required this.departamento,
  });
}

// --- CONTROLADOR DE ESTADO ---

class UsuarioController extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  UserData? _userData;

  // Estado para la gestión de servicios
  List<Service> _userServices = [];
  bool _isServicesLoading = false;

  static const String tableName = 'Servicio';
  
  // Usamos la constante global para el estado inicial
  final int initialStatus = serviceStatusPending; 

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserData? get userData => _userData;

  List<Service> get userServices => _userServices;
  bool get isServicesLoading => _isServicesLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setServicesLoading(bool value) {
    _isServicesLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  // Carga la información del perfil del usuario
  Future<void> loadUserData(String cedula) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await supabase
          .from('Usuario')
          .select('nombre, cedula, departamento')
          .eq('cedula', cedula.trim())
          .single();

      _userData = UserData(
        nombre: response['nombre'].toString(), 
        cedula: response['cedula'].toString(),
        departamento: response['departamento'].toString(),
      );
    } on PostgrestException catch (e) {
      _setError('Error al cargar datos del usuario: ${e.message}');
      debugPrint('Error de Supabase (SELECT User): ${e.message}');
    } catch (e) {
      _setError('Error desconocido al cargar datos del usuario: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Redirecciona y limpia el estado de sesión (simplificado para el demo)
  void logout(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  // Inserta un nuevo servicio en la tabla 'Servicio'
  Future<bool> insertService({
    required String descripcion,
    required String cedulaUsuario,
  }) async {
    _setLoading(true);
    _setError(null);

    if (_userData == null || _userData!.departamento.isEmpty) {
      _setError(
        'Error: Los datos del usuario (departamento) no han sido cargados.',
      );
      _setLoading(false);
      return false;
    }

    try {
      final int? usuarioId = int.tryParse(cedulaUsuario.trim());
      if (usuarioId == null) {
        _setError('Error: La cédula del usuario debe ser un número válido.');
        _setLoading(false);
        return false;
      }
      
      final String fechaActual = DateTime.now().toLocal().toIso8601String();

      final Map<String, dynamic> newService = {
        'descripcion': descripcion.trim(),
        'estado': serviceStatusPending, // 1: Pendiente de inicio por técnico
        'completado_usuario': userCompletionPending, // 1: Pendiente de confirmación por usuario
        'usuario': usuarioId, // Se inserta como INT
        'fecha': fechaActual,
        'departamento': _userData!.departamento,
      };

      await supabase.from(tableName).insert(newService);
      
      // Tras insertar, refrescamos la lista de servicios del usuario
      // NO usamos await aquí para no bloquear la interfaz, el fetch correrá en segundo plano
      fetchUserServices(cedulaUsuario); 

      return true; 
    } on PostgrestException catch (e) {
      _setError('Error al crear servicio: ${e.message}');
      debugPrint('Error de Supabase (INSERT): ${e.message}');
      return false;
    } catch (e) {
      _setError('Error desconocido al guardar el servicio: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Carga la lista de servicios del usuario, incluyendo el nuevo campo
  Future<bool> fetchUserServices(String cedulaUsuario) async {
    _setServicesLoading(true);
    // Nota: No limpiamos el error global para que pueda verse en la pantalla
    try {
      final int? usuarioId = int.tryParse(cedulaUsuario.trim()); 
      
      if (usuarioId == null) {
        _setError('Error: Cédula de usuario inválida.');
        debugPrint('DEBUG FALLO: No se pudo convertir la cédula "$cedulaUsuario" a INT.'); 
        return false;
      }
      
      debugPrint('DEBUG BUSCANDO: Filtrando servicios por Cédula (INT): $usuarioId');

      final response = await supabase
          .from(tableName)
          // CRÍTICO: Se seleccionan todos los campos necesarios.
          .select('id_servicio, descripcion, estado, fecha, usuario, completado_usuario')
          // Filtro usando el INT
          .eq('usuario', usuarioId) 
          .order('fecha', ascending: false);

      _userServices = response
          .map<Service>((json) => Service.fromJson(json))
          .toList();
      
      debugPrint('DEBUG ENCONTRADOS: ${_userServices.length} servicios encontrados para el usuario $usuarioId.');

      // Opcional: Ordenar para que los servicios pendientes de confirmación (estado 1) aparezcan primero
      // Se podría mejorar este ordenamiento para priorizar diferentes estados.
      _userServices.sort((a, b) {
        // Priorizar servicios donde el técnico ya completó pero el usuario NO ha confirmado
        final aPriority = (a.estado == serviceStatusCompleted && a.completadoUsuario == userCompletionPending) ? 0 : 1;
        final bPriority = (b.estado == serviceStatusCompleted && b.completadoUsuario == userCompletionPending) ? 0 : 1;
        
        if (aPriority != bPriority) {
          return aPriority.compareTo(bPriority);
        }
        
        // Luego ordenar por fecha (más reciente primero)
        return DateTime.parse(b.fecha).compareTo(DateTime.parse(a.fecha));
      }); 

      return true;
    } on PostgrestException catch (e) {
      _setError('Error al cargar los servicios: ${e.message}');
      debugPrint('Error de Supabase (SELECT Services): ${e.message}');
      return false;
    } catch (e) {
      _setError('Error desconocido al cargar los servicios: $e');
      return false;
    } finally {
      _setServicesLoading(false);
    }
  }

  // MÉTODO CRÍTICO: Marca el servicio como completado/recibido por el usuario
  // Actualiza la columna 'completado_usuario' a 2 (Confirmado/Atendido).
  Future<bool> markServiceAsCompletedByUser(int serviceId, String cedulaUsuario) async {
    // Usamos el loading principal, ya que es una acción única
    _setLoading(true);
    _setError(null);

    try {
      debugPrint('DEBUG CONFIRMANDO: Actualizando servicio $serviceId a COMPLETADO_USUARIO=$userCompletionConfirmed');

      // Actualiza la columna 'completado_usuario' a 2 (Confirmado)
      await supabase.from(tableName).update({
        'completado_usuario': userCompletionConfirmed,
      })
      // Filtro por ID del servicio
      .eq('id_servicio', serviceId);

      // Refrescar la lista de servicios del usuario para que se actualice la UI
      await fetchUserServices(cedulaUsuario);

      return true;
    } on PostgrestException catch (e) {
      _setError('Error al confirmar la recepción del servicio: ${e.message}');
      debugPrint('Error de Supabase (UPDATE completado_usuario): ${e.message}');
      return false;
    } catch (e) {
      _setError('Error desconocido al actualizar el servicio: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}