import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/friend_models.dart';
import 'friend_repository.dart';
import 'group_api_failure.dart';

class ApiFriendRepository implements FriendRepository {
  const ApiFriendRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<FriendSummary>> listFriends() async {
    final body = await _send(
      () => _apiClient.dio.get<Map<String, dynamic>>('/api/v1/friends'),
      fallbackMessage: 'Arkadaşlar yüklenemedi. Lütfen tekrar deneyin.',
    );
    return FriendsResponse.fromJson(body).friends;
  }

  @override
  Future<void> createInvitation({required String email}) async {
    await _send(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/friends/invitations',
        data: {'email': email},
      ),
      fallbackMessage:
          'Arkadaşlık daveti gönderilemedi. Lütfen tekrar deneyin.',
    );
  }

  @override
  Future<FriendSummary> acceptInvitation(String token) async {
    final encodedToken = Uri.encodeComponent(token);
    final body = await _send(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/friend-invitations/$encodedToken/accept',
      ),
      fallbackMessage: 'Davet kabul edilemedi. Lütfen tekrar deneyin.',
    );
    return FriendSummary.fromJson(
      Map<String, Object?>.from(body['friend']! as Map),
    );
  }

  @override
  Future<List<PendingFriendInvitation>> listPendingInvitations() async {
    final body = await _send(
      () => _apiClient.dio.get<Map<String, dynamic>>(
        '/api/v1/friends/invitations/pending',
      ),
      fallbackMessage: 'Bekleyen davetler yüklenemedi. Lütfen tekrar deneyin.',
    );
    return PendingFriendInvitationsResponse.fromJson(body).invitations;
  }

  @override
  Future<FriendSummary> acceptInvitationById(String invitationId) async {
    final body = await _send(
      () => _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/friends/invitations/$invitationId/accept',
      ),
      fallbackMessage: 'Davet kabul edilemedi. Lütfen tekrar deneyin.',
    );
    return FriendSummary.fromJson(
      Map<String, Object?>.from(body['friend']! as Map),
    );
  }

  Future<Map<String, Object?>> _send(
    Future<Response<Map<String, dynamic>>> Function() request, {
    required String fallbackMessage,
  }) async {
    try {
      final response = await request();
      return Map<String, Object?>.from(response.data ?? const {});
    } on DioException catch (error) {
      throw groupApiExceptionFromDio(error, fallbackMessage: fallbackMessage);
    }
  }
}
