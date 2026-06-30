class DemoAuth {
  static const String testPhone = 'chauffeur.test';
  static const String testPassword = 'TransitTest2026!';
  static const String demoUserId = 'demo-chauffeur';

  static bool isAuthenticated = false;

  static bool matchesTestCredentials(String phone, String password) {
    return phone.trim() == testPhone && password == testPassword;
  }

  static void signIn() {
    isAuthenticated = true;
  }

  static void signOut() {
    isAuthenticated = false;
  }
}
