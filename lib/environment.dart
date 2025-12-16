class Environment {
  /// Appwrite Project ID
  static const String appwriteProjectId = '69417cf3001545fb8858';

  /// Appwrite Project Name (non usato a runtime, solo info)
  static const String appwriteProjectName = 'Mariadora';

  /// Appwrite endpoint pubblico
  static const String appwritePublicEndpoint =
      'https://appwrite.mimmodev.com/v1';

  /// Team ID degli admin (usato per permessi documenti)
  static const String appwriteAdminTeamId = '6941972100137c456711';

  /// URL di redirect per la verifica email
  /// L'utente verrà reindirizzato qui dopo aver cliccato sul link di verifica
  /// Può essere un deep link dell'app o una pagina web
  static const String verificationRedirectUrl =
      'https://appwrite.mimmodev.com/verify';
}

