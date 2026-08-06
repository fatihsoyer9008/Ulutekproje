import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../core/network/api_client.dart';

typedef AssistantTimezoneResolver = Future<String> Function();

class AiAssistantStatus {
  const AiAssistantStatus({
    required this.enabled,
    required this.requiredConsentVersion,
    required this.consentGranted,
    this.consentGrantedAt,
    this.consentRevokedAt,
  });

  final bool enabled;
  final String requiredConsentVersion;
  final bool consentGranted;
  final DateTime? consentGrantedAt;
  final DateTime? consentRevokedAt;

  factory AiAssistantStatus.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    final requiredConsentVersion = json['required_consent_version'];
    final consentGranted = json['consent_granted'];

    if (enabled is! bool ||
        requiredConsentVersion is! String ||
        consentGranted is! bool) {
      throw const FormatException('Geçersiz asistan durum yanıtı.');
    }

    return AiAssistantStatus(
      enabled: enabled,
      requiredConsentVersion: requiredConsentVersion,
      consentGranted: consentGranted,
      consentGrantedAt: _optionalDateTime(json['consent_granted_at']),
      consentRevokedAt: _optionalDateTime(json['consent_revoked_at']),
    );
  }

  static DateTime? _optionalDateTime(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Geçersiz asistan tarih alanı.');
    }
    return DateTime.tryParse(value);
  }
}

abstract interface class AiAssistantAccessClient {
  Future<AiAssistantStatus> fetchStatus();

  Future<AiAssistantStatus> updateConsent({
    required bool accepted,
    required String consentVersion,
  });
}

class AiAssistantClient implements AiAssistantAccessClient {
  AiAssistantClient(
    this._apiClient, {
    AssistantTimezoneResolver? timezoneResolver,
  }) : _timezoneResolver = timezoneResolver ?? _deviceTimezone;

  final ApiClient _apiClient;
  final AssistantTimezoneResolver _timezoneResolver;

  static Future<String> _deviceTimezone() async {
    final timezone = await FlutterTimezone.getLocalTimezone();
    return timezone.identifier;
  }

  @override
  Future<AiAssistantStatus> fetchStatus() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/v1/assistant/status',
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Boş asistan durum yanıtı.');
      }
      return AiAssistantStatus.fromJson(data);
    } on DioException catch (error) {
      throw _friendlyMessage(error);
    }
  }

  @override
  Future<AiAssistantStatus> updateConsent({
    required bool accepted,
    required String consentVersion,
  }) async {
    try {
      final response = await _apiClient.dio.put<Map<String, dynamic>>(
        '/api/v1/assistant/consent',
        data: {'accepted': accepted, 'consent_version': consentVersion},
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Boş asistan rıza yanıtı.');
      }
      return AiAssistantStatus.fromJson(data);
    } on DioException catch (error) {
      throw _friendlyMessage(error);
    }
  }

  Stream<String> streamAnswer(String question) {
    final controller = StreamController<String>();
    final cancelToken = CancelToken();

    controller.onListen = () async {
      try {
        final normalizedQuestion = question.trim();
        if (normalizedQuestion.isEmpty) {
          throw const FormatException('Soru boş olamaz.');
        }
        if (normalizedQuestion.length > 500) {
          throw const FormatException('Soru en fazla 500 karakter olabilir.');
        }

        final timezone = await _timezoneResolver();
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/api/v1/assistant/query',
          data: {'question': normalizedQuestion, 'timezone': timezone},
          options: Options(receiveTimeout: const Duration(seconds: 35)),
          cancelToken: cancelToken,
        );

        final data = response.data;
        final answer = data?['answer'];
        final periodStart = data?['period_start'];
        final periodEndExclusive = data?['period_end_exclusive'];
        final dataAsOf = data?['data_as_of'];

        if (answer is! String ||
            answer.trim().isEmpty ||
            periodStart is! String ||
            periodEndExclusive is! String ||
            (dataAsOf != null && dataAsOf is! String)) {
          throw const FormatException('Geçersiz asistan yanıtı.');
        }

        final freshness = dataAsOf == null
            ? 'Veri güncelliği bilgisi bulunmuyor.'
            : 'Veri güncelliği: $dataAsOf';
        final displayAnswer =
            '${answer.trim()}\n\n'
            'Dönem: $periodStart – $periodEndExclusive (bitiş hariç)\n'
            '$freshness';

        final chunks = RegExp(
          r'\S+\s*',
        ).allMatches(displayAnswer).map((match) => match.group(0)!);

        for (final chunk in chunks) {
          if (controller.isClosed) return;
          controller.add(chunk);
          await Future<void>.delayed(const Duration(milliseconds: 28));
        }
      } on DioException catch (error, stackTrace) {
        if (!CancelToken.isCancel(error) && !controller.isClosed) {
          controller.addError(_friendlyMessage(error), stackTrace);
        }
      } on Object catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      } finally {
        if (!controller.isClosed) await controller.close();
      }
    };

    controller.onCancel = () {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('Kullanıcı yanıtı durdurdu.');
      }
    };

    return controller.stream;
  }

  String _friendlyMessage(DioException error) {
    return switch (error.response?.statusCode) {
      400 || 422 => 'Soruyu veya tarih aralığını kontrol edip tekrar dene.',
      401 => 'Finans asistanını kullanmak için giriş yapmalısın.',
      403 => 'Finans asistanını kullanmadan önce veri işleme izni vermelisin.',
      409 => 'Asistanın gizlilik metni güncellendi. Lütfen ekranı yeniden aç.',
      429 =>
        'Asistan kullanım sınırına ulaşıldı. Lütfen daha sonra tekrar dene.',
      502 => 'Finans asistanı şu anda yanıt oluşturamadı. Lütfen tekrar dene.',
      503 => 'Finans asistanı şu anda kullanılamıyor.',
      504 => 'Finans asistanı zaman aşımına uğradı. Lütfen tekrar dene.',
      _ => 'Finans asistanına bağlanılamadı. İnternet bağlantını kontrol et.',
    };
  }
}
