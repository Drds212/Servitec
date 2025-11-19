import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_client.dart'; // Asumo que este archivo existe

class UserData {
  final String nombre;
  final String cedula;
  final String departamento; // Campo para almacenar el nombre del departamento

  UserData({
    required this.nombre,
    required this.cedula,
    required this.departamento,
  });
}

class UsuarioController extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  UserData? _userData;

  List<String> _userTasks = [];

  static const String tableName = 'Servicio';
  final int initialStatus = 1;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserData? get userData => _userData;
  List<String> get userTasks => _userTasks;

  void _setLoading(bool value) {
    _isLoading = value;
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

  // --- FUNCIÓN MODIFICADA: loadUserData ---
  /// Carga los datos del usuario al inicio de la pantalla, incluyendo el nombre del departamento.
  Future<void> loadUserData(String cedula) async {
    _setLoading(true);
    _setError(null);

    try {
      // 🎯 CAMBIO CLAVE 1: Usar la notación de punto para hacer el JOIN y traer el nombre.
      // Asume: La FK es 'departamento' y la columna con el nombre es 'nombre_departamento'.
      final response = await supabase
          .from('Usuario')
          .select('nombre, departamento(nombre_departamento)')
          .eq('cedula', cedula)
          .single();

      // La respuesta viene anidada: response['departamento'] es un Map.
      final Map<String, dynamic>? departamentoData =
          response['departamento'] as Map<String, dynamic>?;

      // 🎯 CAMBIO CLAVE 2: Extraer el nombre del campo anidado.
      final String nombreDepartamento = departamentoData != null
          ? departamentoData['nombre_departamento'] as String? ?? 'Desconocido'
          : 'Desconocido';

      _userData = UserData(
        nombre: response['nombre'] as String? ?? 'N/A',
        cedula: cedula,
        departamento:
            nombreDepartamento, // Asignamos el nombre del departamento
      );
    } on PostgrestException catch (e) {
      _setError('Error al cargar datos: ${e.message}');
    } catch (e) {
      _setError('Error inesperado al cargar datos.');
      debugPrint('ERROR loadUserData: $e');
    } finally {
      if (_userData != null || _errorMessage != null) {
        _setLoading(false);
      }
    }
  }
  // ----------------------------------------

  /// Función para insertar datos en Supabase (No necesita cambios, ya usa _userData.departamento)
  Future<bool> insertService({
    required String descripcion,
    required String cedulaUsuario,
  }) async {
    _setLoading(true);
    _setError(null);

    // ✅ VALIDACIÓN: Asegurar que _userData está cargado y tiene el departamento
    if (_userData == null) {
      _setError(
        'Error: Los datos del usuario (departamento) no han sido cargados.',
      );
      return false;
    }

    try {
      final int? usuarioId = int.tryParse(cedulaUsuario.trim());

      if (usuarioId == null) {
        _setError('Error: La cédula del usuario debe ser un número válido.');
        return false;
      }

      final String fechaActual = DateTime.now().toLocal().toIso8601String();

      // 🎯 CAMBIO 3: Añadir el campo 'departamento' al mapa de inserción
      final Map<String, dynamic> newService = {
        'descripcion': descripcion.trim(),
        'estado': initialStatus,
        'usuario': usuarioId,
        'fecha': fechaActual,
        'departamento':
            _userData!.departamento, // <-- Ahora es el nombre del departamento
      };

      await supabase.from(tableName).insert(newService);

      return true; // Éxito
    } on PostgrestException catch (e) {
      _setError('Error al crear servicio: ${e.message}');
      debugPrint('Error de Supabase (INSERT): ${e.message}');
      return false;
    } catch (e) {
      _setError('Error desconocido al guardar el servicio: $e');
      debugPrint('Error desconocido (INSERT): $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void logout(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/');
  }
}
