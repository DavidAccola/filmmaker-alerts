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
import 'package:flutter_phoenix/flutter_phoenix.dart';
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
    debugPrint('[MainScreen] onWindowClose() called - X button clicked!');
    if (Platform.isWindows) {
      debugPrint('[MainScreen] Platform is Windows, preventing close and minimizing to tray');
      
      try {
        // Prevent default close behavior
        bool isPreventClose = await windowManager.isPreventClose();
        debugPrint('[MainScreen] Current preventClose status: $isPreventClose');
        
        if (!isPreventClose) {
          debugPrint('[MainScreen] Setting preventClose to true');
          await windowManager.setPreventClose(true);
        }
        
        // Minimize to tray instead of closing
        debugPrint('[MainScreen] Getting system tray service');
        final systemTray = ref.read(systemTrayServiceProvider);
        debugPrint('[MainScreen] Calling minimizeToTray()');
        await systemTray.minimizeToTray();
        debugPrint('[MainScreen] minimizeToTray() completed');
      } catch (e) {
        debugPrint('[MainScreen] Error in onWindowClose: $e');
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

  void _handleContributorResult(dynamic result) {
    if (result is Map && result['contributor'] is Contributor) {
      final contributor = result['contributor'] as Contributor;
      final roles = result['roles'] as List<String>?;
      final availableRoles = result['availableRoles'] as List<String>? ?? [];
      final allSelectedInit = result['allRolesSelected'] as bool? ?? false;

      if (!mounted) return;

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
                final allSelected = resultDialog['allRolesSelected'] as bool;

                // Reconstruct contributor with correct flags
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
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Roles updated.')),
                  );
                }
              }
        },
      );
    }
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
              _handleContributorResult(result);
            }
          });
        } else if (list.isNotEmpty) {
          _hasCheckedOnboarding = true;
        }
      });
    });

    final selectedIndex = ref.watch(selectedTabProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddContributorScreen()),
          );
          _handleContributorResult(result);
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          if (kDebugMode) {
            Phoenix.rebirth(context);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: AdaptiveScaffold(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            ref.read(selectedTabProvider.notifier).state = index;
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
          ],
          body: _screens[selectedIndex],
        ),
      ),
    );
  }
}