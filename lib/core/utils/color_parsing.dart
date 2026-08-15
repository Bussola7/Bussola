import 'package:flutter/material.dart';

/// Converte uma cor em formato hex (ex: "#2563EB", como salva no banco
/// para categorias e calendários) em um [Color] do Flutter. Centralizado
/// aqui porque várias partes da Agenda (EventCard, CategoryChip, o
/// seletor de categorias) precisam da mesma conversão.
Color hexToColor(String hex, {Color fallback = const Color(0xFF64748B)}) {
  final cleaned = hex.replaceAll('#', '');
  final value = int.tryParse('FF$cleaned', radix: 16);
  return value != null ? Color(value) : fallback;
}
