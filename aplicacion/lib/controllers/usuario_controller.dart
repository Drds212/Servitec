import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_client.dart';

class UserData {
  final String nombre;
  final String cedula;

  UserData({required this.nombre, required this.cedula});
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

  /// Carga los datos del usuario al inicio de la pantalla
  Future<void> loadUserData(String cedula) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await supabase
          .from('Usuario')
          .select('nombre, departamento')
          .eq('cedula', cedula)
          .single();

      _userData = UserData(
        nombre: response['nombre'] as String? ?? 'N/A',
        cedula: cedula,
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

  /// Función para insertar datos en Supabase
  Future<bool> insertService({
    required String descripcion,
    required String cedulaUsuario,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final int? usuarioId = int.tryParse(cedulaUsuario.trim());

      if (usuarioId == null) {
        _setError('Error: La cédula del usuario debe ser un número válido.');
        return false;
      }

      final String fechaActual = DateTime.now().toLocal().toIso8601String(); 

      final Map<String, dynamic> newService = {
        'descripcion': descripcion.trim(),
        'estado': initialStatus,
        'usuario': usuarioId,
        'fecha': fechaActual, // Enviamos la hora local con el offset
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