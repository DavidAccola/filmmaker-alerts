import 'package:flutter/material.dart';
import 'multi_select_chip_group.dart';

class DepartmentSelectionDialog extends StatefulWidget {
  final String name;
  final List<String> availableDepartments;
  final List<String> initialSelectedDepartments;
  final List<String> defaultDepartments;

  final bool initialAllRolesSelected;
  final bool allowTrueAll;
  final bool initialNotificationsPaused;

  const DepartmentSelectionDialog({
    super.key,
    required this.name,
    required this.availableDepartments,
    required this.initialSelectedDepartments,
    this.defaultDepartments = const [],
    this.initialAllRolesSelected = false,
    this.allowTrueAll = true,
    this.initialNotificationsPaused = false,
  });

  @override
  State<DepartmentSelectionDialog> createState() => _DepartmentSelectionDialogState();
}

class _DepartmentSelectionDialogState extends State<DepartmentSelectionDialog> {
  late List<String> _selectedDepartments;
  late bool _allRolesSelected;
  late List<String> _sortedDepartments;
  late bool _notificationsPaused;

  @override
  void initState() {
    super.initState();
    _selectedDepartments = List.from(widget.initialSelectedDepartments);
    _allRolesSelected = widget.initialAllRolesSelected;
    _notificationsPaused = widget.initialNotificationsPaused;
    _sortDepartments();
  }

  void _sortDepartments() {
    final priority = ['Creator', 'Director', 'Writer', 'Production'];

    _sortedDepartments = List.from(widget.availableDepartments);
    _sortedDepartments.sort((a, b) {
      final aIsDefault = widget.defaultDepartments.contains(a);
      final bIsDefault = widget.defaultDepartments.contains(b);
      // 1. Defaults first
      if (aIsDefault != bIsDefault) return aIsDefault ? -1 : 1;
      // 2. Priority order
      final aIndex = priority.indexOf(a);
      final bIndex = priority.indexOf(b);
      if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;
      // 3. Alphabetical
      return a.compareTo(b);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Text('Notification preferences for ${widget.name}'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pause notifications toggle
              SwitchListTile(
                title: const Text('Pause notifications'),
                subtitle: Text(
                  _notificationsPaused 
                      ? 'Notifications are paused' 
                      : 'Notifications are active',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                value: _notificationsPaused,
                onChanged: (value) {
                  setState(() {
                    _notificationsPaused = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Roles to follow:',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              MultiSelectChipGroup<String>(
                options: _sortedDepartments,
                selectedValues: _selectedDepartments,
                isAllSelected: _allRolesSelected,
                allowTrueAll: widget.allowTrueAll,
                labelBuilder: (role) => role,
                onAllToggled: () {
                  setState(() {
                    final isFull = _selectedDepartments.length == _sortedDepartments.length;
                    
                    final bool shouldDeselect;
                    if (widget.allowTrueAll) {
                      shouldDeselect = _allRolesSelected;
                    } else {
                      shouldDeselect = isFull;
                    }

                    if (shouldDeselect) {
                      _selectedDepartments = [];
                      _allRolesSelected = false;
                    } else {
                      _selectedDepartments = List.from(_sortedDepartments);
                      _allRolesSelected = widget.allowTrueAll;
                    }
                  });
                },
                onChanged: (newValues) {
                  setState(() {
                    _selectedDepartments = newValues;
                    // Individual selection always clears the "All" flag
                    _allRolesSelected = false;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedDepartments.isEmpty
              ? null
              : () => Navigator.pop(context, {
                  'roles': _selectedDepartments,
                  'allRolesSelected': _allRolesSelected,
                  'notificationsPaused': _notificationsPaused,
                }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
