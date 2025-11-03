import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_client.dart';

class LoginController extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  int? _userRole;
  String? _cedulaArgument;

  // Getters para exponer el estado a la UI
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get userRole => _userRole;
  String? get cedulaArgument => _cedulaArgument;

  //metodod para gestionar la peticion a supabase
  Future<String?> handleLogin(String cedula) async {

    if (cedula.isEmpty) {
      _setError('Por favor, ingrese su cédula.');
      return null;
    }

    _setLoading(true);

    _cedulaArgument = cedula;

      // Consulta a Supabase
    try {
      final response = await supabase
          .from('Usuario')
          .select('rol')
          .eq('cedula', cedula)
          .single();

      final role = response['rol'] as int?;
      _userRole = role;

      String? routeName;

      //Determinacion de la ruta de navegación
      if (role == 1) {
        routeName = '/tecnico';
      } else if (role == 2) {
        routeName = '/usuario';
      } else if (role == 3) {
        routeName = '/admin';
      } else {
        _setError('Rol de usuario no válido.');
        return null;
      }

      _setLoading(false);
      return routeName;
    } on PostgrestException catch (e) {

      if (e.message.contains('single row expected')) {
        _setError('Cédula no encontrada. Acceso denegado.');
      } else {
        _setError('Error de API: ${e.message}');
      }
      return null;
    } catch (e) {
      _setError('Error inesperado. Inténtelo más tarde.');
      debugPrint('ERROR en LoginController: $e');
      return null;
    } finally {

      if (_isLoading) {
        _setLoading(false);
      }
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (value) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    _userRole = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
