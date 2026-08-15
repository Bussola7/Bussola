import 'package:bussola/core/services/supabase_service.dart';

/// Resultado de uma chamada a uma Edge Function — só o que quem chama
/// realmente precisa (`status` HTTP e o corpo da resposta), sem expor o
/// tipo concreto do SDK do Supabase para fora desta camada.
class EdgeFunctionResult {
  final int status;
  final dynamic data;

  const EdgeFunctionResult({required this.status, this.data});
}

/// Abstração genérica para chamar Edge Functions do Supabase — não é
/// específica de nenhum provedor (Google, Outlook, ...). Existe por um
/// motivo só: `SupabaseService.client.functions.invoke(...)` é uma
/// chamada estática ao SDK real, impossível de substituir por um fake em
/// teste unitário. Qualquer Service que precise chamar uma Edge Function
/// e queira ser testável de verdade deve depender desta interface, não
/// do SDK do Supabase diretamente.
abstract class EdgeFunctionCaller {
  Future<EdgeFunctionResult> invoke(String functionName, {Map<String, dynamic>? body});
}

/// Implementação real — só isso fala com o SDK do Supabase de verdade.
class SupabaseEdgeFunctionCaller implements EdgeFunctionCaller {
  const SupabaseEdgeFunctionCaller();

  @override
  Future<EdgeFunctionResult> invoke(String functionName, {Map<String, dynamic>? body}) async {
    final resposta = await SupabaseService.client.functions.invoke(functionName, body: body);
    return EdgeFunctionResult(status: resposta.status, data: resposta.data);
  }
}
