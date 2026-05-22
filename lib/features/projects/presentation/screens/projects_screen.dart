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

// ── Provider ───────────────────────────────────────────────

final projectsProvider = StreamProvider<List<ProjectModel>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(projectRepositoryProvider).watchProjects(uid);
});

final projectFilterProvider = StateProvider<String>((ref) => 'all');
final projectSearchProvider = StateProvider<String>((ref) => '');

// ── Projects Screen ────────────────────────────────────────

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    onTap: () =>
                        context.push('/projects/edit/${filtered[i].id}'),
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
