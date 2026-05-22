import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/resume_generator/domain/entities/resume_model.dart';
import '../../../../services/pdf/pdf_service.dart';
import '../../../../shared/providers/firebase_providers.dart';

class ResumePreviewScreen extends ConsumerStatefulWidget {
  final String resumeId;

  const ResumePreviewScreen({super.key, required this.resumeId});

  @override
  ConsumerState<ResumePreviewScreen> createState() =>
      _ResumePreviewScreenState();
}

class _ResumePreviewScreenState
    extends ConsumerState<ResumePreviewScreen> {
  bool _isDownloading = false;
  ResumeModel? _resume;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadResume();
  }

  Future<void> _loadResume() async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    try {
      final doc = await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('resumes')
          .doc(widget.resumeId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _resume = ResumeModel.fromFirestore(doc);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_resume?.generatedResumeData == null) return;
    setState(() => _isDownloading = true);

    try {
      final pdfService = PdfService();
      final pdfBytes = await pdfService.generatePdf(
        _resume!.generatedResumeData!,
        _resume!.templateUsed,
      );

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            '${_resume!.generatedResumeData!.name.replaceAll(' ', '_')}_Resume.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.pdfError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(AppStrings.resumePreview),
        elevation: 0,
        actions: [
          if (_resume != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _AtsScoreBadge(score: _resume!.atsScore),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _resume == null
              ? const Center(child: Text('Resume not found'))
              : Column(
                  children: [
                    // Resume preview area
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // ATS Score + Missing Keywords
                            if (_resume!.atsScore > 0)
                              _AtsInsightCard(resume: _resume!),
                            const SizedBox(height: 16),
                            // Resume Card
                            _ResumeCard(
                              resumeData: _resume!.generatedResumeData,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: const Border(
                          top: BorderSide(
                              color: AppColors.divider, width: 1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.refresh_rounded,
                                  size: 16),
                              label: const Text(AppStrings.regenerate),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isDownloading ? null : _downloadPdf,
                              icon: _isDownloading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.download_rounded, size: 16),
                              label: Text(
                                _isDownloading
                                    ? 'Preparing...'
                                    : AppStrings.downloadPdf,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _AtsScoreBadge extends StatelessWidget {
  final int score;
  const _AtsScoreBadge({required this.score});

  Color get _color {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 14, color: _color),
          const SizedBox(width: 4),
          Text(
            'ATS $score%',
            style: AppTypography.labelMedium.copyWith(
              color: _color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AtsInsightCard extends StatelessWidget {
  final ResumeModel resume;
  const _AtsInsightCard({required this.resume});

  @override
  Widget build(BuildContext context) {
    final missing = resume.missingKeywords;
    final color = resume.atsScore >= 80
        ? AppColors.success
        : resume.atsScore >= 60
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                'ATS Analysis',
                style: AppTypography.titleMedium.copyWith(color: color),
              ),
              const Spacer(),
              Text(
                '${resume.atsScore}/100',
                style: AppTypography.headlineMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              AppStrings.missingKeywords,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: missing.map((kw) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Text(
                    kw,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  final ResumeData? resumeData;
  const _ResumeCard({required this.resumeData});

  @override
  Widget build(BuildContext context) {
    if (resumeData == null) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(child: Text('No resume data')),
      );
    }

    final r = resumeData!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(r.name,
              style: AppTypography.displaySmall.copyWith(
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 4),
          Text(
            [r.email, r.phone, r.location]
                .where((s) => s.isNotEmpty)
                .join(' · '),
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          if (r.githubUrl.isNotEmpty || r.linkedinUrl.isNotEmpty)
            Text(
              [r.githubUrl, r.linkedinUrl]
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.accent,
              ),
            ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // Summary
          if (r.summary.isNotEmpty) ...[
            _ResumeSection(title: 'Professional Summary'),
            const SizedBox(height: 8),
            Text(r.summary,
                style: AppTypography.bodyMedium.copyWith(height: 1.6)),
            const SizedBox(height: 16),
          ],

          // Projects
          if (r.projects.isNotEmpty) ...[
            _ResumeSection(title: 'Projects'),
            const SizedBox(height: 8),
            ...r.projects.map((p) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(p.title,
                            style: AppTypography.titleMedium),
                        if (p.technologies.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              p.technologies.take(3).join(', '),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...p.bullets.map((bullet) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('• ',
                                  style: AppTypography.bodySmall
                                      .copyWith(
                                          color: AppColors.accent)),
                              Expanded(
                                child: Text(bullet,
                                    style: AppTypography.bodySmall
                                        .copyWith(height: 1.5)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              );
            }),
          ],

          // Education
          if (r.education.isNotEmpty) ...[
            _ResumeSection(title: 'Education'),
            const SizedBox(height: 8),
            ...r.education.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(e.institution,
                                style: AppTypography.titleMedium),
                            Text('${e.degree} ${e.field}',
                                style: AppTypography.bodySmall),
                          ],
                        ),
                      ),
                      Text(e.duration,
                          style: AppTypography.caption),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _ResumeSection extends StatelessWidget {
  final String title;
  const _ResumeSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),
      ],
    );
  }
}
