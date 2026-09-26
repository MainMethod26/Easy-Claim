class AuthService {
  static String? currentUserId;
  static String? currentUserName;
  static String? currentRole;
  static String? currentTenant;
  static String? token;
  
  static Map<String, String> get authHeaders {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
