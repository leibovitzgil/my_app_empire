/// Interface for Consent Management Platform (CMP) wrapper.
abstract class ConsentService {
  /// Request consent from the user (e.g. for GDPR).
  ///
  /// This should trigger the CMP UI if necessary.
  /// Returns `true` if the consent flow completed successfully, `false` otherwise.
  Future<bool> requestConsent();

  /// Resets the consent state.
  ///
  /// Useful for testing or allowing the user to change their preferences.
  Future<void> resetConsent();

  /// Checks if consent is required for the current user/region.
  Future<bool> isConsentRequired();
}
