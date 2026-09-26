class AuthService {
  static String? currentUserId;
  static String? currentUserName;
  
  static Map<String, String> get authHeaders {
    return {
      'Content-Type': 'application/json',
      if (currentUserId != null) 'x-user-id': currentUserId!,
    };
  }
}
