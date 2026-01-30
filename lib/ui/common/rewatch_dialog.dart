import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReWatchDialog extends StatefulWidget {
  final List<DateTime> existingWatchDates;
  final DateTime? lastWatchDate;

  const ReWatchDialog({
    super.key,
    required this.existingWatchDates,
    this.lastWatchDate,
  });

  @override
  State<ReWatchDialog> createState() => _ReWatchDialogState();
}

class _ReWatchDialogState extends State<ReWatchDialog> {
  late List<DateTime> _watchDates;
  late bool _isEditMode;

  @override
  void initState() {
    super.initState();
    _watchDates = List.from(widget.existingWatchDates);
    
    // Check if less than 12 hours since last watch
    if (widget.lastWatchDate != null) {
      final hoursSinceLastWatch = DateTime.now().difference(widget.lastWatchDate!).inHours;
      _isEditMode = hoursSinceLastWatch < 12;
    } else {
      _isEditMode = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_isEditMode ? 'Edit Watched Details' : 'Watch History'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isEditMode)
              Text(
                'Edit your most recent watch:',
                style: theme.textTheme.bodySmall,
              )
            else
              Text(
                'All watches:',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            
            // List of watch dates
            ..._watchDates.asMap().entries.map((entry) {
              final index = entry.key;
              final date = entry.value;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Watch ${index + 1}',
                            style: theme.textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _selectDate(context, index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outline,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(date),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeWatch(index),
                      tooltip: 'Remove watch',
                    ),
                  ],
                ),
              );
            }),

            // Add button
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addWatch,
              icon: const Icon(Icons.add),
              label: const Text('Add Watch'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () {
            // Sort dates before returning
            _watchDates.sort();
            Navigator.of(context).pop(_watchDates);
          },
          child: const Text('SAVE'),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, int index) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _watchDates[index],
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != _watchDates[index]) {
      setState(() {
        _watchDates[index] = picked;
      });
    }
  }

  void _addWatch() {
    setState(() {
      _watchDates.add(DateTime.now());
    });
  }

  void _removeWatch(int index) {
    if (_watchDates.length == 1) {
      // If removing the only watch, return empty list to signal "unmark as watched"
      Navigator.of(context).pop([]);
      return;
    }
    
    setState(() {
      _watchDates.removeAt(index);
    });
  }
}

/// Shows the re-watch dialog and returns the updated list of watch dates
Future<List<DateTime>?> showReWatchDialog(
  BuildContext context, {
  required List<DateTime> existingWatchDates,
  DateTime? lastWatchDate,
}) async {
  return showDialog<List<DateTime>>(
    context: context,
    builder: (context) => ReWatchDialog(
      existingWatchDates: existingWatchDates,
      lastWatchDate: lastWatchDate,
    ),
  );
}
