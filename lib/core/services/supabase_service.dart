import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bussola/core/constants/app_constants.dart';

/// Ponto único de conexão com o Supabase. Nenhuma outra parte do app deve
/// chamar `Supabase.initialize` diretamente — sempre passar por cá.
/// Isso deixa fácil trocar de provedor de backend no futuro, se precisar.
class SupabaseService {
  SupabaseService._();

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.get(AppConstants.supabaseUrlEnvKey),
      anonKey: dotenv.get(AppConstants.supabaseAnonKeyEnvKey),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
