import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_client.dart';
import 'package:provider/provider.dart';

//pantallas
import 'screens/login_screen.dart';
import 'screens/tecnico_screen.dart';
import 'screens/usuario_screen.dart';
import 'screens/admi_screen.dart';


import 'controllers/login_controller.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY);

  runApp(
    MultiProvider(
      providers: [
        //Para manejar el estado de autenticación.
        ChangeNotifierProvider(create: (_) => LoginController()),
        
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Roles App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      //Definición de Rutas
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),


        '/tecnico': (context) {

          return const TecnicoScreen();
        },


        '/usuario': (context) => const UsuarioScreen(),


        '/admin': (context) {
          final adminCedula =
              ModalRoute.of(context)!.settings.arguments as String;
          return AdminScreen(adminCedula: adminCedula);
        },
      },
    );
  }
}