import 'package:flutter/foundation.dart';

/// Provedores de calendário externo suportados. Só `googleCalendar` existe
/// de verdade nesta etapa — os outros dois são o motivo de este enum (e
/// toda a feature `integrations`) já nascer genérico, em vez de "Google"
/// estar espalhado pelo código.
enum CalendarProvider { googleCalendar, outlook, appleCalendar }

extension CalendarProviderX on CalendarProvider {
  static CalendarProvider fromDb(String value) {
    switch (value) {
      case 'outlook':
        return CalendarProvider.outlook;
      case 'apple_calendar':
        return CalendarProvider.appleCalendar;
      case 'google_calendar':
      default:
        return CalendarProvider.googleCalendar;
    }
  }

  String toDb() {
    switch (this) {
      case CalendarProvider.googleCalendar:
        return 'google_calendar';
      case CalendarProvider.outlook:
        return 'outlook';
      case CalendarProvider.appleCalendar:
        return 'apple_calendar';
    }
  }
}

enum IntegrationStatus { desconectado, conectado, pendente, erro }

extension IntegrationStatusX on IntegrationStatus {
  static IntegrationStatus fromDb(String value) {
    switch (value) {
      case 'conectado':
        return IntegrationStatus.conectado;
      case 'pendente':
        return IntegrationStatus.pendente;
      case 'erro':
        return IntegrationStatus.erro;
      case 'desconectado':
      default:
        return IntegrationStatus.desconectado;
    }
  }

  String toDb() => name;
}

/// Representa uma linha da tabela `integrations` — **sem** o
/// `refresh_token` (esse nunca sai do backend/Edge Function; nem este
/// model tem campo para ele, de propósito).
@immutable
class CalendarIntegrationModel {
  final String id;
  final String userId;
  final CalendarProvider provider;
  final IntegrationStatus status;
  final String? accessToken;
  final String? syncToken;
  final DateTime? lastSyncAt;
  final String? scopes;
  final bool autoSyncEnabled;
  final DateTime updatedAt;

  const CalendarIntegrationModel({
    required this.id,
    required this.userId,
    required this.provider,
    required this.status,
    this.accessToken,
    this.syncToken,
    this.lastSyncAt,
    this.scopes,
    this.autoSyncEnabled = false,
    required this.updatedAt,
  });

  bool get isConnected => status == IntegrationStatus.conectado;

  factory CalendarIntegrationModel.fromJson(Map<String, dynamic> json) {
    return CalendarIntegrationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      provider: CalendarProviderX.fromDb(json['provider'] as String),
      status: IntegrationStatusX.fromDb(json['status'] as String? ?? 'desconectado'),
      accessToken: json['token'] as String?,
      syncToken: json['sync_token'] as String?,
      lastSyncAt: json['last_sync_at'] == null ? null : DateTime.parse(json['last_sync_at'] as String),
      scopes: json['scopes'] as String?,
      autoSyncEnabled: json['auto_sync_enabled'] as bool? ?? false,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  CalendarIntegrationModel copyWith({
    IntegrationStatus? status,
    String? syncToken,
    DateTime? lastSyncAt,
    bool? autoSyncEnabled,
  }) {
    return CalendarIntegrationModel(
      id: id,
      userId: userId,
      provider: provider,
      status: status ?? this.status,
      accessToken: accessToken,
      syncToken: syncToken ?? this.syncToken,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      scopes: scopes,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      updatedAt: updatedAt,
    );
  }
}
