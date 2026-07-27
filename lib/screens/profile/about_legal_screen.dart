import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/legal_content.dart';
import '../../utils/support_contact.dart';
import '../../widgets/app_back_leading.dart';
import '../../widgets/content_max_width.dart';
import '../../widgets/form_section.dart';
import '../../widgets/summary_widgets.dart';

/// About & legal surface: version, open-source licenses, privacy policy, terms.
class AboutLegalScreen extends ConsumerWidget {
  const AboutLegalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const SecondaryAppBar(title: 'אודות ומשפטי'),
      body: ContentMaxWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormSection(
                title: 'אודות',
                child: SectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text(AppConstants.appName),
                        subtitle: Text(
                          'גרסה ${AppConfig.appVersion} · ${AppConfig.environmentLabel}',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.article_outlined),
                        title: const Text('רישיונות קוד פתוח'),
                        subtitle: const Text('ספריות צד שלישי בשימוש האפליקציה'),
                        trailing: const Icon(
                          Icons.chevron_left,
                          color: AppTheme.textSecondary,
                        ),
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: AppConstants.appName,
                          applicationVersion: AppConfig.appVersion,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.support_agent_outlined),
                        title: const Text('פנה לתמיכה'),
                        subtitle: const Text('שלח פרטי גרסה ותקלה לצוות'),
                        trailing: const Icon(
                          Icons.chevron_left,
                          color: AppTheme.textSecondary,
                        ),
                        onTap: () => openSupportContact(
                          context,
                          ref,
                          route: '/about',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FormSection(
                title: 'משפטי',
                child: SectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _LegalRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'מדיניות פרטיות',
                        title: 'מדיניות פרטיות',
                        body: LegalContent.privacyPolicy,
                      ),
                      const Divider(height: 1),
                      _LegalRow(
                        icon: Icons.gavel_outlined,
                        label: 'תנאי שימוש',
                        title: 'תנאי שימוש',
                        body: LegalContent.termsOfService,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalRow extends StatelessWidget {
  const _LegalRow({
    required this.icon,
    required this.label,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String label;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.navy),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing:
          const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _LegalDocumentScreen(title: title, body: body),
        ),
      ),
    );
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(title: title),
      body: ContentMaxWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SelectableText(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ),
      ),
    );
  }
}
