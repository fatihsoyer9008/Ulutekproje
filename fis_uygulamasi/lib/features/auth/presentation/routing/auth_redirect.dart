const groupsRootRoute = '/groups';

final RegExp _safeGroupsRoutePattern = RegExp(
  r'^/(?:groups(?:/[A-Za-z0-9_-]+)*|friends|activity)$',
);

String? safeGroupsRedirect(String? value) {
  final candidate = value?.trim();
  if (candidate == null || candidate.isEmpty) return null;

  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      !_safeGroupsRoutePattern.hasMatch(uri.path)) {
    return null;
  }

  return uri.path;
}

bool isGroupsRoute(String location) => safeGroupsRedirect(location) != null;

String groupsLoginLocation([String redirect = groupsRootRoute]) {
  final safeRedirect = safeGroupsRedirect(redirect) ?? groupsRootRoute;
  return Uri(
    path: '/login',
    queryParameters: <String, String>{'redirect': safeRedirect},
  ).toString();
}
