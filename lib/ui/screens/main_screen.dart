import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import '../../providers/providers.dart';
import '../common/adaptive_scaffold.dart';
import '../common/department_selection_dialog.dart';
import '../common/snackbar_utils.dart';
import '../../data/models/contributor.dart';
import 'add_contributor_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'debug_screen.dart';
import 'settings_screen.dart';
import 'package:flutter/foundation.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with WindowListener {
  bool _hasCheckedOnboarding = false;

  final List<Widget> _screens = const [
    HomeScreen(),
    HistoryScreen(),
    DebugScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('[MainScreen] initState() called');
    if (Platform.isWindows) {
      debugPrint('[MainScreen] Adding window listener for Windows');
      windowManager.addListener(this);
    } else {
      debugPrint('[MainScreen] Not Windows, skipping window listener');
    }
  }

  @override
  void dispose() {
    debugPrint('[MainScreen] dispose() called');
    if (Platform.isWindows) {
      debugPrint('[MainScreen] Removing window listener');
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    debugPrint('[MainScreen] onWindowClose() called');
    if (Platform.isWindows) {
      try {
        bool isPreventClose = await windowManager.isPreventClose();
        debugPrint('[MainScreen] Current preventClose status: $isPreventClose');
        
        if (isPreventClose) {
          debugPrint('[MainScreen] preventClose is true, minimizing to tray instead of closing');
          final systemTray = ref.read(systemTrayServiceProvider);
          await systemTray.minimizeToTray();
        } else {
          debugPrint('[MainScreen] preventClose is false, allowing application to close');
          // No action needed, preventClose is already false so window will close
        }
      } catch (e) {
        debugPrint('[MainScreen] Error in onWindowClose: $e');
        // If error occurs, default to exit as a safety measure
        exit(0);
      }
    } else {
      debugPrint('[MainScreen] Not Windows, allowing normal close');
    }
  }

  @override
  void onWindowFocus() {
    debugPrint('[MainScreen] Window gained focus');
  }

  @override
  void onWindowBlur() {
    debugPrint('[MainScreen] Window lost focus');
  }

  @override
  void onWindowMinimize() {
    debugPrint('[MainScreen] Window minimized (not to tray)');
  }

  @override
  void onWindowRestore() {
    debugPrint('[MainScreen] Window restored');
  }

  @override
  Widget build(BuildContext context) {
    // Listen for contributor data to check onboarding
    ref.listen<AsyncValue<List>>(contributorsProvider, (previous, next) {
      if (_hasCheckedOnboarding) return;
      
      next.whenData((list) {
        if (list.isEmpty && mounted) {
          _hasCheckedOnboarding = true;
          // Navigate to Add Contributor screen
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddContributorScreen()),
              );
              _handleAddContributorResult(result);
            }
          });
        } else if (list.isNotEmpty) {
          _hasCheckedOnboarding = true;
        }
      });
    });

    final selectedIndex = ref.watch(selectedTabProvider);
    final homeTab = ref.watch(homeTabProvider);
    final isRankEditMode = ref.watch(rankEditModeProvider);
    
    // Determine which FAB to show
    // On Home tab (0), Watchlist sub-tab (1), show rank-related FAB
    final isOnWatchlist = selectedIndex == 0 && homeTab == 1;
    
    // Show FAB on Home (0) and History (1) tabs
    final showFab = selectedIndex == 0 || selectedIndex == 1;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddContributorScreen()),
          );
          _handleAddContributorResult(result);
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          if (kDebugMode) {
            // Phoenix.rebirth removed - use hot reload instead
            debugPrint('[MainScreen] Hot reload with Ctrl+R');
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: AdaptiveScaffold(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            ref.read(selectedTabProvider.notifier).setTab(index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.bug_report_outlined),
              selectedIcon: Icon(Icons.bug_report),
              label: 'Debug',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
          body: _screens[selectedIndex],
          floatingActionButton: showFab ? _buildFab(context, isOnWatchlist, isRankEditMode) : null,
        ),
      ),
    );
  }
  
  Widget _buildFab(BuildContext context, bool isOnWatchlist, bool isRankEditMode) {
    // If on watchlist and in rank edit mode, show "Done" button
    if (isOnWatchlist && isRankEditMode) {
      return Tooltip(
        message: 'Done Ranking',
        waitDuration: const Duration(milliseconds: 250),
        child: FloatingActionButton.extended(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          onPressed: () {
            ref.read(rankEditModeProvider.notifier).setEditMode(false);
          },
          icon: const Icon(Icons.check),
          label: const Text('Done'),
        ),
      );
    }
    
    // Default: show "Add" button
    return Tooltip(
      message: 'Find More to Follow',
      waitDuration: const Duration(milliseconds: 250),
      child: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddContributorScreen()),
          );
          _handleAddContributorResult(result);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
  
  void _handleAddContributorResult(dynamic result) {
    if (!mounted) return;
    if (result is! Map || result['contributor'] is! Contributor) return;
    
    final contributor = result['contributor'] as Contributor;
    final roles = result['roles'] as List<String>?;
    final availableRoles = result['availableRoles'] as List<String>? ?? [];
    final allSelectedInit = result['allRolesSelected'] as bool? ?? false;
    
    // Check if this is a watchlist item or a contributor
    if (contributor.type == ContributorType.movie || 
        contributor.type == ContributorType.tvShow || 
        contributor.type == ContributorType.collection) {
      // Navigate to Home tab, then Watchlist tab
      ref.read(selectedTabProvider.notifier).setTab(0);
      ref.read(homeTabProvider.notifier).setTab(1);
      ref.read(watchlistScrollTargetProvider.notifier).setTarget(contributor.tmdbId);
      
      // Clear scroll target after a delay
      Future.delayed(const Duration(seconds: 2), () {
        ref.read(watchlistScrollTargetProvider.notifier).clear();
      });
      
      // Show snackbar for watchlist item
      showSimpleSnackBar(
        context,
        'Added "${contributor.name}" to watchlist',
      );
    } else {
      // Navigate to Home tab, then People tab
      ref.read(selectedTabProvider.notifier).setTab(0);
      ref.read(homeTabProvider.notifier).setTab(0);
      
      // Show success snackbar for contributor
      showSuccessSnackBar(
        context,
        contributor: contributor,
        roles: roles ?? [],
        availableRoles: availableRoles,
        onChange: () async {
          final logic = ref.read(contributorLogicProvider);
          final prefs = ref.read(preferencesRepositoryProvider).getPreferences();

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

            final enrichedForUpdate = Contributor(
              tmdbId: contributor.tmdbId,
              name: contributor.name,
              type: contributor.type,
              profilePath: contributor.profilePath,
              notifyForDepartments: selectedDepts,
              availableDepartments: availableRoles,
              knownFor: contributor.knownFor,
            );

            await logic.updateContributorRoles(enrichedForUpdate, selectedDepts);
            ref.invalidate(contributorsProvider);
            if (mounted) {
              showSimpleSnackBar(context, 'Roles updated.');
            }
          }
        },
      );
    }
  }
}