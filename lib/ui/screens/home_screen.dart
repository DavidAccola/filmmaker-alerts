import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contributor.dart';
import '../../data/models/preferences.dart';
import '../../providers/providers.dart';
import '../common/contributor_card.dart';
import '../common/department_selection_dialog.dart';
import '../common/snackbar_utils.dart';
import '../common/tmdb_attribution.dart';
import 'add_contributor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contributorsAsync = ref.watch(contributorsProvider);
    final prefsAsync = ref.watch(preferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Followed Contributors'),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh All',
              onPressed: () async {
                final logic = ref.read(contributorLogicProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Refreshing contributors...'), duration: Duration(seconds: 1)),
                );
                await logic.refreshAllContributors();
                ref.invalidate(contributorsProvider);
                if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refresh complete.')),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          // Display Settings Menu
          prefsAsync.when(
            data: (prefs) => PopupMenuButton<String>(
              icon: const Icon(Icons.tune),
              tooltip: 'Display Settings',
              onSelected: (value) async {
                final repo = ref.read(preferencesRepositoryProvider);
                if (value == 'toggle_group') {
                  prefs.groupByType = !(prefs.groupByType ?? true);
                } else if (value == 'toggle_view') {
                  prefs.useGridView = !(prefs.useGridView ?? true);
                } else {
                  prefs.homeSortOrder = value;
                }
                await repo.savePreferences(prefs);
                ref.invalidate(preferencesProvider);
              },
              itemBuilder: (context) {
                final currentSort = prefs.homeSortOrder ?? 'dateAdded';
                final isGrouped = prefs.groupByType ?? true; // Default to true
                final isGrid = prefs.useGridView ?? true;

                return [
                  PopupMenuItem(
                    value: 'dateAdded',
                    child: Row(
                      children: [
                        if (currentSort == 'dateAdded') const Icon(Icons.check, size: 18),
                        const SizedBox(width: 8),
                        const Text('Date Added'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'name',
                    child: Row(
                      children: [
                        if (currentSort == 'name') const Icon(Icons.check, size: 18),
                        const SizedBox(width: 8),
                        const Text('Alphabetical'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'latestRelease',
                    child: Row(
                      children: [
                        if (currentSort == 'latestRelease') const Icon(Icons.check, size: 18),
                        const SizedBox(width: 8),
                        const Text('Latest Release'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  CheckedPopupMenuItem(
                    value: 'toggle_group',
                    checked: isGrouped,
                    child: const Text('Group by Type'),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'toggle_view',
                    child: Row(
                      children: [
                        Icon(isGrid ? Icons.view_list : Icons.grid_view, size: 18),
                        const SizedBox(width: 8),
                        Text(isGrid ? 'Switch to Detail View' : 'Switch to Grid View'),
                      ],
                    ),
                  ),
                ];
              },
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'App Settings',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: contributorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (contributors) {
          if (contributors.isEmpty) {
            return const Center(
              child: Text('No contributors followed yet.\nAdd one to get started!'),
            );
          }

          final prefs = prefsAsync.value ?? Preferences();
          final sortedList = _sortContributors(contributors, prefs.homeSortOrder ?? 'dateAdded');

          return LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen = constraints.maxWidth >= 600;
              final useGrid = isLargeScreen && (prefs.useGridView ?? true);
              final isGrouped = prefs.groupByType ?? true; // Default to true

              if (isGrouped) {
                // Grouping Logic
                final Map<ContributorType, List<Contributor>> groups = {};
                for (var c in sortedList) {
                  groups.putIfAbsent(c.type, () => []).add(c);
                }

                // Sort types for consistent display (Person first, then Movie, etc.)
                final displayTypes = [
                  ContributorType.person,
                  ContributorType.movie,
                  ContributorType.collection,
                  ContributorType.company,
                ].where((t) => groups.containsKey(t)).toList();

                return CustomScrollView(
                  slivers: [
                    for (var type in displayTypes) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text(
                            _getTypeLabel(type).toUpperCase(),
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      if (useGrid)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 420,
                              childAspectRatio: 2.7,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final contributor = groups[type]![index];
                                return ContributorCard(
                                  key: ValueKey(contributor.tmdbId),
                                  contributor: contributor,
                                  onTap: () {},
                                  onRemove: () => _removeContributor(context, ref, contributor),
                                  onEditRoles: () => _editRoles(context, ref, contributor),
                                );
                              },
                              childCount: groups[type]!.length,
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final contributor = groups[type]![index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: ContributorCard(
                                  key: ValueKey(contributor.tmdbId),
                                  contributor: contributor,
                                  onTap: () {},
                                  onRemove: () => _removeContributor(context, ref, contributor),
                                  onEditRoles: () => _editRoles(context, ref, contributor),
                                ),
                              );
                            },
                            childCount: groups[type]!.length,
                          ),
                        ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    const SliverToBoxAdapter(child: TmdbAttribution()),
                  ],
                );
              }

              // Normal Flat View
              if (useGrid) {
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 420,
                          childAspectRatio: 2.7,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final contributor = sortedList[index];
                            return ContributorCard(
                              key: ValueKey(contributor.tmdbId),
                              contributor: contributor,
                              onTap: () {},
                              onRemove: () => _removeContributor(context, ref, contributor),
                              onEditRoles: () => _editRoles(context, ref, contributor),
                            );
                          },
                          childCount: sortedList.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: TmdbAttribution()),
                  ],
                );
              } else {
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: sortedList.length + 1, // +1 for attribution
                  itemBuilder: (context, index) {
                    if (index == sortedList.length) {
                      // Show attribution at the end
                      return const TmdbAttribution();
                    }
                    
                    final contributor = sortedList[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ContributorCard(
                        key: ValueKey(contributor.tmdbId),
                        contributor: contributor,
                        onTap: () {},
                        onRemove: () => _removeContributor(context, ref, contributor),
                        onEditRoles: () => _editRoles(context, ref, contributor),
                      ),
                    );
                  },
                );
              }
            },
          );
        },
      ),
      floatingActionButton: Tooltip(
        message: 'Add Contributor',
        waitDuration: const Duration(milliseconds: 250),
        child: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddContributorScreen()));
            
            if (context.mounted && result is Map && result['contributor'] is Contributor) {
              final contributor = result['contributor'] as Contributor;
              final roles = result['roles'] as List<String>?;
              final availableRoles = result['availableRoles'] as List<String>? ?? [];
              final allSelectedInit = result['allRolesSelected'] as bool? ?? false;

              showSuccessSnackBar(
                context,
                contributor: contributor,
                roles: roles ?? [],
                availableRoles: availableRoles,
                onChange: () async {
                  final logic = ref.read(contributorLogicProvider);
                  final repo = ref.read(preferencesRepositoryProvider);
                  final prefs = repo.getPreferences();

                  final resultDialog = await showDialog<dynamic>(
                    context: context,
                    builder: (context) => DepartmentSelectionDialog(
                      name: contributor.name,
                      availableDepartments: availableRoles,
                      initialSelectedDepartments: roles ?? [],
                      defaultDepartments: prefs.effectiveDefaultDepartments,
                      initialAllRolesSelected: allSelectedInit,
                      allowTrueAll: prefs.autoFollowNewRoles ?? true,
                    ),
                  );

                  if (resultDialog != null && resultDialog is Map) {
                    final selectedDepts = resultDialog['roles'] as List<String>;
                    final allSelected = resultDialog['allRolesSelected'] as bool;

                    final enrichedForUpdate = Contributor(
                      tmdbId: contributor.tmdbId,
                      name: contributor.name,
                      type: contributor.type,
                      profilePath: contributor.profilePath,
                      notifyForDepartments: selectedDepts,
                      availableDepartments: availableRoles, 
                      knownFor: contributor.knownFor,
                      allRolesSelected: allSelected,
                    );

                    await logic.updateContributorRoles(enrichedForUpdate, selectedDepts);
                    ref.invalidate(contributorsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Roles updated.')),
                      );
                    }
                  }
                },
              );
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
  
  List<Contributor> _sortContributors(List<Contributor> list, String sortOrder) {
    final sorted = List<Contributor>.from(list);
    switch (sortOrder) {
      case 'name':
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'latestRelease':
        sorted.sort((a, b) {
          final dateA = a.latestWork?.releaseDate ?? '';
          final dateB = b.latestWork?.releaseDate ?? '';
          if (dateA == dateB) return a.name.compareTo(b.name);
          return dateB.compareTo(dateA); // Newest first
        });
        break;
      case 'dateAdded':
      default:
        sorted.sort((a, b) {
          final dateA = a.followedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.followedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          if (dateA == dateB) return a.name.compareTo(b.name);
          return dateB.compareTo(dateA); // Newest first
        });
        break;
    }
    return sorted;
  }

  String _getTypeLabel(ContributorType type) {
    switch (type) {
      case ContributorType.person: return 'Filmmakers';
      case ContributorType.movie: return 'Movies';
      case ContributorType.collection: return 'Collections';
      case ContributorType.company: return 'Companies';
    }
  }

  Future<void> _removeContributor(BuildContext context, WidgetRef ref, Contributor contributor) async {
    final repo = ref.read(contributorRepositoryProvider);
    
    // 1. Remove immediately
    await repo.removeContributor(contributor.tmdbId);
    ref.invalidate(contributorsProvider);

    // 2. Show Undo SnackBar
    if (context.mounted) {
      showRemovalSnackBar(
        context,
        message: 'Removed ${contributor.name}',
        onUndo: () async {
          // 3. Re-add if Undone
          await repo.addContributor(contributor);
          ref.invalidate(contributorsProvider);
        },
      );
    }
  }

  Future<void> _editRoles(BuildContext context, WidgetRef ref, Contributor contributor) async {
    final logic = ref.read(contributorLogicProvider);
    final repo = ref.read(preferencesRepositoryProvider);
    final prefs = repo.getPreferences();
    
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => DepartmentSelectionDialog(
        name: contributor.name,
        availableDepartments: contributor.availableDepartments,
        initialSelectedDepartments: contributor.notifyForDepartments,
        defaultDepartments: prefs.effectiveDefaultDepartments,
        initialAllRolesSelected: contributor.allRolesSelected ?? false,
        allowTrueAll: prefs.autoFollowNewRoles ?? true,
      ),
    );

    if (result != null && result is Map) {
      final selectedDepts = result['roles'] as List<String>;
      final allSelected = result['allRolesSelected'] as bool;
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updating roles for ${contributor.name}...')),
        );
      }

      // Create updated contributor with new flags
      final updatedContributor = Contributor(
        tmdbId: contributor.tmdbId,
        name: contributor.name,
        type: contributor.type,
        profilePath: contributor.profilePath,
        notifyForDepartments: selectedDepts,
        availableDepartments: contributor.availableDepartments, 
        knownFor: contributor.knownFor,
        latestWork: contributor.latestWork,
        followedAt: contributor.followedAt,
        allRolesSelected: allSelected,
      );
      
      await logic.updateContributorRoles(updatedContributor, selectedDepts);
      ref.invalidate(contributorsProvider);
    }
  }
}