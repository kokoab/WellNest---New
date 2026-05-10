import 'package:flutter/material.dart';
import 'package:my_app/models/terms_of_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';

/// Full Terms & Conditions in a branded sheet/dialog aligned with auth screens.
class TermsOfServiceModal {
  TermsOfServiceModal._();

  static Future<void> show(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: kBackgroundCream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Terms & Conditions',
                                style: georgiaProTextStyle(
                                  fontSize: 22,
                                  color: kPrimaryGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Version ${TermsOfService.version} · Effective ${TermsOfService.effectiveDate}',
                                style: helveticaNow(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: kCaptionGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          color: kPrimaryGreen,
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: wellnestOutlineColor(context)),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        24,
                        AppSpacing.md,
                        24,
                        bottomInset + AppSpacing.lg,
                      ),
                      children: [
                        for (final section in TermsOfService.sections) ...[
                          Text(
                            section.title,
                            style: helveticaNow(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: kPrimaryGreen,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final p in section.paragraphs) ...[
                            Text(
                              p,
                              style: helveticaNow(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: kBodyTextDark,
                              ).copyWith(height: 1.45),
                            ),
                            const SizedBox(height: AppSpacing.sm2),
                          ],
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: kAccentOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Close',
                            style: helveticaNow(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
