import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/projects/domain/entities/project_model.dart';
import '../../../../features/projects/data/repositories/project_repository.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../services/github/github_service.dart';
import '../../../../services/github/github_sync_limiter.dart';
import '../../../../features/dashboard/presentation/screens/dashboard_screen.dart'; // for userProfileProvider
import '../../../../routes/route_names.dart';

// ── Provider ───────────────────────────────────────────────

final projectsProvider = StreamProvider<List<ProjectModel>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(projectRepositoryProvider).watchProjects(uid);
});

final projectFilterProvider = StateProvider<String>((ref) => 'all');
final projectSearchProvider = StateProvider<String>((ref) => '');

// ── Projects Screen ────────────────────────────────────────

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  SyncLimitStatus? _limitStatus;
  Timer? _cooldownTimer;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _checkLimit();
    // Start a periodic timer to update cooldown countdowns dynamically in the UI
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_limitStatus?.isBlocked == true) {
        _checkLimit();
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLimit() async {
    final status = await GitHubSyncLimiter.checkLimit();
    if (mounted) {
      setState(() {
        _limitStatus = status;
      });
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String? _parseGitHubUsername(String url) {
    if (url.isEmpty) return null;
    var cleanUrl = url.trim();
    if (cleanUrl.contains('github.com/')) {
      final parts = cleanUrl.split('github.com/');
      if (parts.length > 1) {
        var username = parts[1].trim();
        if (username.contains('/')) {
          username = username.split('/')[0];
        }
        if (username.contains('?')) {
          username = username.split('?')[0];
        }
        return username.isNotEmpty ? username : null;
      }
    }
    // If it's a raw username (no dots, no slashes)
    if (!cleanUrl.contains('/') && !cleanUrl.contains('.')) {
      return cleanUrl;
    }
    return null;
  }

  Future<void> _handleGitHubSync() async {
    await _checkLimit();
    if (_limitStatus?.isBlocked == true) {
      _showBlockedDialog(context, _limitStatus!);
      return;
    }

    final user = ref.read(userProfileProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile is still loading. Please wait a moment...')),
      );
      return;
    }

    final githubUrl = user.githubUrl;
    if (githubUrl.trim().isEmpty) {
      _showMissingGitHubUrlDialog(context);
      return;
    }

    final username = _parseGitHubUsername(githubUrl);
    if (username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not parse a valid GitHub username from your profile URL. Please verify your profile details.')),
      );
      return;
    }

    setState(() => _isSyncing = true);

    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        dialogContext = dialogCtx;
        return const Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 3.5,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Fetching GitHub Repositories...',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Connecting to api.github.com',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final githubService = ref.read(gitHubServiceProvider);
      final repos = await githubService.fetchPublicReposByUsername(username);

      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      await GitHubSyncLimiter.recordSync();
      await _checkLimit();

      final existingProjects = ref.read(projectsProvider).value ?? [];
      final existingRepoUrls = existingProjects
          .map((p) => p.githubRepo.toLowerCase().trim())
          .where((url) => url.isNotEmpty)
          .toSet();

      final newRepos = repos.where((repo) {
        final repoUrl = repo.htmlUrl.toLowerCase().trim();
        return !existingRepoUrls.contains(repoUrl);
      }).toList();

      if (newRepos.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All public repositories are already in your project list!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        return;
      }

      if (mounted) {
        _showRepoImportDialog(context, newRepos, user.uid);
      }
    } catch (e) {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing with GitHub: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _showBlockedDialog(BuildContext context, SyncLimitStatus limit) {
    final blockMsg = limit.message;
    final remaining = limit.cooldownRemaining ?? Duration.zero;
    final timeStr = _formatDuration(remaining);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.timer_outlined, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            const Text(
              'Sync Limit Reached',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              blockMsg,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'To protect GitHub API rate-limits and prevent high traffic, syncing is temporarily suspended. Please try again after the cooldown period expires.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_bottom_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text(
                      'Reactivates in: $timeStr',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMissingGitHubUrlDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.link_off_rounded, color: AppColors.warning, size: 24),
            const SizedBox(width: 10),
            const Text(
              'GitHub URL Missing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No GitHub profile URL registered.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'To sync your repositories, please add your GitHub profile URL to your Personal Information under the Profile tab.',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop(); // pop dialog
              context.go(RouteNames.profile);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Go to Profile'),
          ),
        ],
      ),
    );
  }

  void _showRepoImportDialog(BuildContext context, List<GitHubRepo> repos, String uid) {
    final selectedRepos = List<bool>.filled(repos.length, true); // Select all by default
    bool selectAll = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.border),
              ),
              title: Row(
                children: [
                  const Icon(Icons.code_rounded, color: AppColors.accent, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Import Repositories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${selectedRepos.where((s) => s).length}/${repos.length} selected',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select the repositories you want to import as permanent projects. They will be saved to Firebase.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    // Select All Row
                    GestureDetector(
                      onTap: () {
                        setStateDialog(() {
                          selectAll = !selectAll;
                          for (int i = 0; i < selectedRepos.length; i++) {
                            selectedRepos[i] = selectAll;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: selectAll,
                              activeColor: AppColors.accent,
                              onChanged: (val) {
                                setStateDialog(() {
                                  selectAll = val ?? false;
                                  for (int i = 0; i < selectedRepos.length; i++) {
                                    selectedRepos[i] = selectAll;
                                  }
                                });
                              },
                            ),
                            const Text(
                              'Select All Repositories',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Checklist Scrollable area
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: repos.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: AppColors.divider,
                          ),
                          itemBuilder: (ctx, index) {
                            final repo = repos[index];
                            final isChecked = selectedRepos[index];

                            return CheckboxListTile(
                              value: isChecked,
                              activeColor: AppColors.accent,
                              onChanged: (val) {
                                setStateDialog(() {
                                  selectedRepos[index] = val ?? false;
                                  selectAll = selectedRepos.every((s) => s);
                                });
                              },
                              title: Text(
                                repo.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (repo.description != null && repo.description!.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      repo.description!,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (repo.language != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentContainer,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            repo.language!,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.accent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${repo.stars}',
                                        style: AppTypography.caption,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: selectedRepos.any((s) => s)
                      ? () async {
                          Navigator.of(dialogCtx).pop(); // pop safely
                          await _importSelectedRepos(repos, selectedRepos, uid);
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selectedRepos.any((s) => s)
                          ? AppColors.accent
                          : AppColors.textDisabled,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: selectedRepos.any((s) => s)
                          ? AppColors.accentShadow
                          : null,
                    ),
                    child: const Text(
                      'Import Selected',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _importSelectedRepos(
      List<GitHubRepo> repos, List<bool> selections, String uid) async {
    final toImport = <GitHubRepo>[];
    for (int i = 0; i < repos.length; i++) {
      if (selections[i]) {
        toImport.add(repos[i]);
      }
    }

    if (toImport.isEmpty) return;

    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        dialogContext = dialogCtx;
        return const Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 3.5,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Importing Projects...',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Saving repositories to Firestore',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final repo = ref.read(projectRepositoryProvider);
      final futures = toImport.map((r) {
        final p = ProjectModel(
          id: '',
          uid: uid,
          title: r.name,
          description: r.description ?? '',
          githubRepo: r.htmlUrl,
          isGithubSynced: true,
          technologies: r.language != null ? [r.language!] : <String>[],
          tags: r.topics.take(5).toList(),
        );
        return repo.addProject(uid, p);
      });

      await Future.wait(futures);

      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${toImport.length} project(s) from GitHub!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import projects: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildRateLimitBanner() {
    final status = _limitStatus!;
    final isBlocked = status.isBlocked;
    final bgColor = isBlocked
        ? AppColors.error.withOpacity(0.06)
        : AppColors.warning.withOpacity(0.06);
    final borderColor = isBlocked
        ? AppColors.error.withOpacity(0.3)
        : AppColors.warning.withOpacity(0.3);
    final textColor = isBlocked ? AppColors.error : AppColors.warning;
    final icon = isBlocked ? Icons.hourglass_bottom_rounded : Icons.warning_amber_rounded;

    String text = status.message;
    if (isBlocked && status.cooldownRemaining != null) {
      text += ' Reactivates in: ${_formatDuration(status.cooldownRemaining!)}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);
    final filter = ref.watch(projectFilterProvider);
    final search = ref.watch(projectSearchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(AppStrings.myProjects),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          // GitHub Sync Button with Rate-Limiting indicator
          IconButton(
            onPressed: _isSyncing ? null : _handleGitHubSync,
            tooltip: _limitStatus?.isBlocked == true
                ? 'Rate limit active. Please wait.'
                : 'Sync from GitHub profile',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _limitStatus?.isBlocked == true
                        ? AppColors.surfaceVariant
                        : AppColors.surface,
                    border: Border.all(
                      color: _limitStatus?.showWarning == true
                          ? AppColors.warning
                          : _limitStatus?.isBlocked == true
                              ? AppColors.border
                              : AppColors.border,
                      width: _limitStatus?.showWarning == true ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isSyncing
                      ? const Padding(
                          padding: EdgeInsets.all(7.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      : Icon(
                          Icons.sync_rounded,
                          color: _limitStatus?.isBlocked == true
                              ? AppColors.textDisabled
                              : _limitStatus?.showWarning == true
                                  ? AppColors.warning
                                  : AppColors.textPrimary,
                          size: 18,
                        ),
                ),
                if (_limitStatus?.showWarning == true)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                if (_limitStatus?.isBlocked == true)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push('/projects/add'),
            icon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Rate-Limit/Cooldown warning banner
          if (_limitStatus != null && (_limitStatus!.showWarning || _limitStatus!.isBlocked))
            _buildRateLimitBanner(),

          // Search + Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                _SearchBar(
                  onChanged: (v) =>
                      ref.read(projectSearchProvider.notifier).state = v,
                ),
                const SizedBox(height: 12),
                _FilterChips(
                  selected: filter,
                  onSelect: (v) =>
                      ref.read(projectFilterProvider.notifier).state = v,
                ),
              ],
            ),
          ),

          // Projects List
          Expanded(
            child: projectsAsync.when(
              data: (projects) {
                var filtered = projects;
                if (search.isNotEmpty) {
                  filtered = filtered
                      .where((p) =>
                          p.title.toLowerCase().contains(search.toLowerCase()) ||
                          p.technologies.any((t) =>
                              t.toLowerCase().contains(search.toLowerCase())))
                      .toList();
                }
                if (filter == 'github') {
                  filtered =
                      filtered.where((p) => p.isGithubSynced).toList();
                } else if (filter == 'manual') {
                  filtered =
                      filtered.where((p) => !p.isGithubSynced).toList();
                }

                if (filtered.isEmpty) {
                  return _EmptyProjects(
                    hasProjects: projects.isNotEmpty,
                    onAdd: () => context.push('/projects/add'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _ProjectCard(
                    project: filtered[i],
                    onTap: () {
                      if (filtered[i].isGithubSynced) {
                        context.push('/projects/github-view/${filtered[i].id}');
                      } else {
                        context.push('/projects/edit/${filtered[i].id}');
                      }
                    },
                  ),
                );
              },
              loading: () => const _ProjectsShimmer(),
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
                        'Unable to Sync Projects',
                        style: AppTypography.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We couldn\'t load your projects due to a temporary database sync issue.',
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
                        onTap: () => ref.invalidate(projectsProvider),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: AppStrings.searchProjects,
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppColors.textMuted, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// ── Filter Chips ──────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final options = [
      ('all', AppStrings.allProjects),
      ('github', AppStrings.githubProjects),
      ('manual', AppStrings.manualProjects),
    ];

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: options.map((option) {
          final isSelected = selected == option.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(option.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  option.$2,
                  style: AppTypography.labelMedium.copyWith(
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Project Card ──────────────────────────────────────────

class _ProjectCard extends StatefulWidget {
  final ProjectModel project;
  final VoidCallback onTap;

  const _ProjectCard({required this.project, required this.onTap});

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.project;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered ? AppColors.accent : AppColors.border,
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: _hovered
                ? AppColors.elevatedShadow
                : AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.title,
                      style: AppTypography.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (p.isGithubSynced)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.code,
                              size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('GitHub',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                              )),
                        ],
                      ),
                    ),
                ],
              ),

              if (p.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  p.description,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Tech stack chips
              if (p.technologies.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: p.technologies.take(5).map((tech) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        tech,
                        style: AppTypography.labelSmall,
                      ),
                    );
                  }).toList(),
                ),

              // AI summary preview
              if (p.aiSummary.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          p.aiSummary,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.accent,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────

class _EmptyProjects extends StatelessWidget {
  final bool hasProjects;
  final VoidCallback onAdd;

  const _EmptyProjects({required this.hasProjects, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accentContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.code_rounded,
                  size: 32, color: AppColors.accent),
            ),
            const SizedBox(height: 16),
            Text(
              hasProjects
                  ? 'No projects match your search'
                  : AppStrings.noProjectsYet,
              style: AppTypography.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (!hasProjects)
              Text(
                AppStrings.noProjectsYetSub,
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            if (!hasProjects)
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppColors.accentShadow,
                  ),
                  child: Text(
                    AppStrings.addProject,
                    style: AppTypography.labelLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer ───────────────────────────────────────────────

class _ProjectsShimmer extends StatelessWidget {
  const _ProjectsShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
