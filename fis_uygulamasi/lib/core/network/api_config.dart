abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: String.fromEnvironment(
      'RECEIPT_API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000',
    ),
  );

  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    // OAuth client IDs are public identifiers, not client secrets. This is the
    // Web client from android/app/google-services.json and may be overridden
    // per environment with --dart-define.
    defaultValue:
        '356175797700-cvih7hepb72j56deugtirr38sqf3h1sd.apps.googleusercontent.com',
  );
}
