import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class AiAssistantClient {
  AiAssistantClient(this._apiClient);

  final ApiClient _apiClient;

  Stream<String> streamAnswer(
    String question, {
    String timezone = 'Europe/Istanbul',
  }) {
    final controller = StreamController<String>();
    final cancelToken = CancelToken();

    controller.onListen = () async {
      try {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/api/v1/assistant/query',
          data: {'question': question, 'timezone': timezone},
          cancelToken: cancelToken,
        );
        final answer = response.data?['answer'];
        if (answer is! String || answer.trim().isEmpty) {
          throw const FormatException('Geçersiz asistan yanıtı.');
        }

        final words = answer.trim().split(RegExp(r'\s+'));
        for (var index = 0; index < words.length; index++) {
          if (controller.isClosed) return;
          controller.add(
            index == words.length - 1 ? words[index] : '${words[index]} ',
          );
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
      401 => 'Finans asistanını kullanmak için giriş yapmalısın.',
      429 =>
        'Asistan kullanım sınırına ulaşıldı. Lütfen daha sonra tekrar dene.',
      502 => 'Finans asistanı şu anda yanıt oluşturamadı. Lütfen tekrar dene.',
      503 => 'Finans asistanı şu anda kullanılamıyor.',
      _ => 'Finans asistanına bağlanılamadı. İnternet bağlantını kontrol et.',
    };
  }
}
