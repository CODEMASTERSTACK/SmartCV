import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../../../features/profile/data/repositories/profile_repository.dart';
import '../../../../features/profile/domain/entities/user_model.dart';
import '../../../../shared/widgets/app_button.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppStrings.navProfile),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded, size: 16,
                color: AppColors.textMuted),
            label: Text(AppStrings.signOut,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textMuted,
                )),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 36,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Profile Sync Incomplete',
                  style: AppTypography.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We couldn\'t fetch your career data due to a temporary database sync issue.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Retry Connection',
                  fullWidth: false,
                  variant: AppButtonVariant.secondary,
                  icon: Icons.refresh_rounded,
                  onTap: () => ref.invalidate(userProfileProvider),
                ),
              ],
            ),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Profile not found'));
          }
          return _ProfileContent(user: user);
        },
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  final UserModel user;

  const _ProfileContent({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = user.uid;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Avatar + Name
        _ProfileHeader(user: user),
        const SizedBox(height: 24),

        // Personal Info Section
        _ProfileSection(
          title: AppStrings.personalInfo,
          icon: Icons.person_outline_rounded,
          child: _PersonalInfoContent(user: user),
        ),
        const SizedBox(height: 12),

        // Summary
        _ProfileSection(
          title: AppStrings.professionalSummary,
          icon: Icons.description_outlined,
          child: _SummaryContent(user: user),
        ),
        const SizedBox(height: 12),

        // Skills
        _ProfileSection(
          title: AppStrings.skills,
          icon: Icons.bolt_outlined,
          child: _SkillsContent(uid: uid, ref: ref),
        ),
        const SizedBox(height: 12),

        // Education
        _ProfileSection(
          title: AppStrings.education,
          icon: Icons.school_outlined,
          child: _EducationContent(uid: uid, ref: ref),
        ),
        const SizedBox(height: 12),

        // Experience
        _ProfileSection(
          title: AppStrings.experience,
          icon: Icons.work_outline_rounded,
          child: _ExperienceContent(uid: uid, ref: ref),
        ),
        const SizedBox(height: 12),

        // Projects
        _ProfileSection(
          title: AppStrings.projects,
          icon: Icons.code_outlined,
          child: _ProjectsLinkContent(uid: uid),
        ),
        const SizedBox(height: 12),

        // Certifications
        _ProfileSection(
          title: AppStrings.certifications,
          icon: Icons.verified_outlined,
          child: _CertificationsContent(uid: uid, ref: ref),
        ),
        const SizedBox(height: 12),

        // Achievements
        _ProfileSection(
          title: AppStrings.achievements,
          icon: Icons.emoji_events_outlined,
          child: _AchievementsContent(uid: uid, ref: ref),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Profile Header ─────────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  final UserModel user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.accentContainer,
          backgroundImage: user.profileImageUrl.isNotEmpty
              ? NetworkImage(user.profileImageUrl)
              : null,
          child: user.profileImageUrl.isEmpty
              ? Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: AppTypography.displaySmall.copyWith(
                    color: AppColors.accent,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name.isNotEmpty ? user.name : 'Your Name',
                style: AppTypography.headlineLarge,
              ),
              if (user.currentRole.isNotEmpty)
                Text(
                  user.currentRole,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              if (user.email.isNotEmpty)
                Text(user.email, style: AppTypography.bodySmall),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _showEditProfileDialog(context, user, ref),
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_outlined, size: 18),
          ),
        ),
      ],
    );
  }

  void _showEditProfileDialog(BuildContext ctx, UserModel user, WidgetRef ref) {
    final nameCtrl = TextEditingController(text: user.name);
    final roleCtrl = TextEditingController(text: user.currentRole);
    final phoneCtrl = TextEditingController(text: user.phone);
    final locationCtrl = TextEditingController(text: user.location);
    final githubCtrl = TextEditingController(text: user.githubUrl);
    final linkedinCtrl = TextEditingController(text: user.linkedinUrl);
    final summaryCtrl = TextEditingController(text: user.summary);

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(labelText: 'Current Role / Headline'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: githubCtrl,
                decoration: const InputDecoration(labelText: 'GitHub URL'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: linkedinCtrl,
                decoration: const InputDecoration(labelText: 'LinkedIn URL'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: summaryCtrl,
                decoration: const InputDecoration(labelText: 'Professional Summary'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(profileRepositoryProvider)
                  .updateUser(user.uid, {
                'name': nameCtrl.text.trim(),
                'currentRole': roleCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'location': locationCtrl.text.trim(),
                'githubUrl': githubCtrl.text.trim(),
                'linkedinUrl': linkedinCtrl.text.trim(),
                'summary': summaryCtrl.text.trim(),
              });
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ── Section Wrapper ────────────────────────────────────────

class _ProfileSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accentContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon,
                        size: 16, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title,
                        style: AppTypography.headlineSmall),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded,
                        color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.child,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ── Section Contents ───────────────────────────────────────

class _PersonalInfoContent extends StatelessWidget {
  final UserModel user;
  const _PersonalInfoContent({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoRow(label: 'Name', value: user.name, icon: Icons.person_outline),
        _InfoRow(label: 'Email', value: user.email, icon: Icons.email_outlined),
        _InfoRow(label: 'Phone', value: user.phone, icon: Icons.phone_outlined),
        _InfoRow(label: 'Location', value: user.location, icon: Icons.location_on_outlined),
        _InfoRow(label: 'GitHub', value: user.githubUrl, icon: Icons.code),
        _InfoRow(label: 'LinkedIn', value: user.linkedinUrl, icon: Icons.link),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.caption),
                Text(
                  value.isNotEmpty ? value : 'Not set',
                  style: AppTypography.bodySmall.copyWith(
                    color: value.isNotEmpty
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
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

class _SummaryContent extends StatelessWidget {
  final UserModel user;
  const _SummaryContent({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.summary.isNotEmpty
              ? user.summary
              : 'Add a professional summary to improve AI resume quality.',
          style: AppTypography.bodyMedium.copyWith(
            color: user.summary.isNotEmpty
                ? AppColors.textPrimary
                : AppColors.textMuted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.auto_awesome_rounded,
              size: 14, color: AppColors.accent),
          label: Text(AppStrings.aiEnhance,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.accent,
              )),
        ),
      ],
    );
  }
}

class _SkillsContent extends StatelessWidget {
  final String uid;
  final WidgetRef ref;
  const _SkillsContent({required this.uid, required this.ref});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ref.read(profileRepositoryProvider).watchSkills(uid),
      builder: (context, snap) {
        final skills = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...skills.map((s) => _SkillChip(name: s['name'] as String)),
                GestureDetector(
                  onTap: () => _addSkillDialog(context, uid, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.accent.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 14, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Text(AppStrings.addSkill,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.accent,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _addSkillDialog(BuildContext ctx, String uid, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Add Skill'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g., Flutter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                final navigator = Navigator.of(ctx);
                await ref
                    .read(profileRepositoryProvider)
                    .addSkill(uid, ctrl.text.trim(), 'General');
                navigator.pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String name;
  const _SkillChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(name, style: AppTypography.labelSmall),
    );
  }
}

class _EducationContent extends StatelessWidget {
  final String uid;
  final WidgetRef ref;
  const _EducationContent({required this.uid, required this.ref});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ref.read(profileRepositoryProvider).watchEducation(uid),
      builder: (context, snap) {
        final items = snap.data ?? [];
        return Column(
          children: [
            ...items.map((e) {
              final isSchool = e['degree'] == '10th Standard' || e['degree'] == '12th Standard';
              final title = isSchool ? (e['degree'] as String) : (e['institution'] as String? ?? '');
              final subtitle = isSchool 
                  ? '${e['institution'] ?? ''}${e['board'] != null && e['board'].toString().isNotEmpty ? " (${e['board']})" : ""}'
                  : '${e['degree'] ?? ''}${e['field'] != null && e['field'].toString().isNotEmpty ? " - ${e['field']}" : ""}';
              
              final trailing = isSchool
                  ? '${e['percentage'] != null && e['percentage'].toString().isNotEmpty ? "${e['percentage']} | " : ""}${e['endYear'] ?? ''}'
                  : '${e['startYear'] != null && e['startYear'].toString().isNotEmpty ? "${e['startYear']} – " : ""}${e['endYear'] ?? ''}';

              return _TimelineItem(
                title: title,
                subtitle: subtitle,
                trailing: trailing,
              );
            }),
            _AddButton(
              label: AppStrings.addEducation,
              onTap: () => _showAddDialog(context, uid, ref, items),
            ),
          ],
        );
      },
    );
  }

  void _showAddDialog(BuildContext ctx, String uid, WidgetRef ref, List<Map<String, dynamic>> items) {
    final has10th = items.any((e) => e['degree'] == '10th Standard');
    final has12th = items.any((e) => e['degree'] == '12th Standard');

    if (has10th && has12th) {
      _showAddHigherEducationDialog(ctx, uid, ref);
    } else {
      showDialog(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Add Education'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!has10th) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Add 10th Standard'),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _showAddSchoolDialog(ctx, uid, ref, '10th Standard');
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (!has12th) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.school_rounded),
                  label: const Text('Add 12th Standard'),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _showAddSchoolDialog(ctx, uid, ref, '12th Standard');
                  },
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('Add Higher Education'),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _showAddHigherEducationDialog(ctx, uid, ref);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void _showAddSchoolDialog(BuildContext ctx, String uid, WidgetRef ref, String degree) {
    final schoolCtrl = TextEditingController();
    final boardCtrl = TextEditingController();
    final pctCtrl = TextEditingController();
    final yearCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Add $degree Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: schoolCtrl,
                decoration: const InputDecoration(hintText: 'School Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: boardCtrl,
                decoration: const InputDecoration(hintText: 'Board (e.g. CBSE, State Board)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pctCtrl,
                      decoration: const InputDecoration(hintText: 'Percentage (%)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: yearCtrl,
                      decoration: const InputDecoration(hintText: 'Passing Year'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(profileRepositoryProvider)
                  .addEducation(uid, {
                'degree': degree,
                'institution': schoolCtrl.text.trim(),
                'board': boardCtrl.text.trim(),
                'percentage': pctCtrl.text.trim(),
                'endYear': yearCtrl.text.trim(),
              });
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddHigherEducationDialog(BuildContext ctx, String uid, WidgetRef ref) {
    final institutionCtrl = TextEditingController();
    final degreeCtrl = TextEditingController();
    final fieldCtrl = TextEditingController();
    final yearCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Higher Education'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: institutionCtrl,
                decoration: const InputDecoration(hintText: 'Institution / College'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: degreeCtrl,
                decoration: const InputDecoration(hintText: 'Degree (e.g. B.Tech, MBA)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: fieldCtrl,
                decoration: const InputDecoration(hintText: 'Field of Study (e.g. Computer Science)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: yearCtrl,
                decoration: const InputDecoration(hintText: 'Graduation Year'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(profileRepositoryProvider)
                  .addEducation(uid, {
                'institution': institutionCtrl.text.trim(),
                'degree': degreeCtrl.text.trim(),
                'field': fieldCtrl.text.trim(),
                'endYear': yearCtrl.text.trim(),
              });
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _ExperienceContent extends StatelessWidget {
  final String uid;
  final WidgetRef ref;
  const _ExperienceContent({required this.uid, required this.ref});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ref.read(profileRepositoryProvider).watchExperience(uid),
      builder: (context, snap) {
        final items = snap.data ?? [];
        return Column(
          children: [
            ...items.map((e) => _TimelineItem(
                  title: e['role'] as String? ?? '',
                  subtitle: e['company'] as String? ?? '',
                  trailing: e['duration'] as String? ?? '',
                )),
            _AddButton(
              label: AppStrings.addExperience,
              onTap: () => _showAddExperienceDialog(context, uid, ref),
            ),
          ],
        );
      },
    );
  }

  void _showAddExperienceDialog(BuildContext ctx, String uid, WidgetRef ref) {
    final roleCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final durationCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Experience'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roleCtrl,
              decoration: const InputDecoration(hintText: 'Role / Job Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: companyCtrl,
              decoration: const InputDecoration(hintText: 'Company'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: durationCtrl,
              decoration: const InputDecoration(hintText: 'Duration (e.g. 2024 - Present)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(profileRepositoryProvider)
                  .addExperience(uid, {
                'role': roleCtrl.text.trim(),
                'company': companyCtrl.text.trim(),
                'duration': durationCtrl.text.trim(),
                'startDate': DateTime.now(), // Safe ordering fallback
              });
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _CertificationsContent extends StatelessWidget {
  final String uid;
  final WidgetRef ref;
  const _CertificationsContent({required this.uid, required this.ref});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ref.read(profileRepositoryProvider).watchCertifications(uid),
      builder: (context, snap) {
        final items = snap.data ?? [];
        return Column(
          children: [
            ...items.map((c) => _TimelineItem(
                  title: c['title'] as String? ?? '',
                  subtitle: c['issuer'] as String? ?? '',
                  trailing: c['date'] as String? ?? '',
                )),
            _AddButton(
              label: AppStrings.addCertification,
              onTap: () => _showAddCertificationDialog(context, uid, ref),
            ),
          ],
        );
      },
    );
  }

  void _showAddCertificationDialog(BuildContext ctx, String uid, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final issuerCtrl = TextEditingController();
    final dateCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Certification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(hintText: 'Certification Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: issuerCtrl,
              decoration: const InputDecoration(hintText: 'Issuer'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: dateCtrl,
              decoration: const InputDecoration(hintText: 'Date (e.g. May 2026)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(profileRepositoryProvider)
                  .addCertification(uid, {
                'title': titleCtrl.text.trim(),
                'issuer': issuerCtrl.text.trim(),
                'date': dateCtrl.text.trim(),
              });
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _AchievementsContent extends StatelessWidget {
  final String uid;
  final WidgetRef ref;
  const _AchievementsContent({required this.uid, required this.ref});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ref.read(profileRepositoryProvider).watchAchievements(uid),
      builder: (context, snap) {
        final items = snap.data ?? [];
        return Column(
          children: [
            ...items.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          a['title'] as String? ?? '',
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )),
            _AddButton(
              label: AppStrings.addAchievement,
              onTap: () => _showAddAchievementDialog(context, uid, ref),
            ),
          ],
        );
      },
    );
  }

  void _showAddAchievementDialog(BuildContext ctx, String uid, WidgetRef ref) {
    final titleCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Achievement'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(hintText: 'e.g. First place in Google Hackathon'),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(profileRepositoryProvider)
                  .addAchievement(uid, {
                'title': titleCtrl.text.trim(),
              });
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _ProjectsLinkContent extends StatelessWidget {
  final String uid;
  const _ProjectsLinkContent({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline_rounded,
            size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          'Manage your projects from the Projects tab',
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }
}

// ── Shared Sub-Widgets ─────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;

  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
              ),
              Container(width: 1, height: 32, color: AppColors.border),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMedium),
                Text(subtitle, style: AppTypography.bodySmall),
              ],
            ),
          ),
          Text(trailing, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.labelMedium),
          ],
        ),
      ),
    );
  }
}
