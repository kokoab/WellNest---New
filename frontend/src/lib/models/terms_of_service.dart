/// WellNest Terms & Conditions — static content shown at sign-up.
/// Update [version] when sections change materially.
class TermsSection {
  final String title;
  final List<String> paragraphs;

  const TermsSection({required this.title, required this.paragraphs});
}

class TermsOfService {
  TermsOfService._();

  static const String version = '1.0';
  static const String effectiveDate = 'May 10, 2026';

  /// Ordered sections for display (full text).
  static List<TermsSection> get sections => const [
    TermsSection(
      title: 'Introduction',
      paragraphs: [
        'Welcome to WellNest. By creating an account, you agree to these Terms & Conditions and our approach to a respectful, safe community focused on recipes, wellness, and shared experiences.',
        'If you do not agree, you may not register or use the service.',
      ],
    ),
    TermsSection(
      title: 'Your account',
      paragraphs: [
        'You must provide accurate information and keep your login credentials confidential. You are responsible for activity under your account.',
        'We may suspend or terminate accounts that violate these terms, applicable law, or harm other users or the platform.',
      ],
    ),
    TermsSection(
      title: 'Content you share',
      paragraphs: [
        'You retain rights to content you post, but grant WellNest a licence to host, display, and distribute it as needed to operate the service.',
        'Do not post unlawful, misleading, harassing, or infringing content. Recipes and posts should follow community guidelines where applicable.',
      ],
    ),
    TermsSection(
      title: 'Privacy',
      paragraphs: [
        'We process personal data to run the app (account, features you use, and communications). See our privacy practices in-product or contact us for details.',
      ],
    ),
    TermsSection(
      title: 'Disclaimer & limitation',
      paragraphs: [
        'WellNest is provided “as is” to the extent permitted by law. Wellness and recipe information is not a substitute for professional medical or dietary advice.',
        'To the extent permitted by law, our liability is limited for issues arising from use of the service.',
      ],
    ),
    TermsSection(
      title: 'Changes',
      paragraphs: [
        'We may update these terms; continued use after notice constitutes acceptance of the updated terms where required by law.',
      ],
    ),
  ];
}
