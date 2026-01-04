import 'package:flutter/material.dart';

class MultiSelectChipGroup<T> extends StatelessWidget {
  final List<T> options;
  final List<T> selectedValues;
  final ValueChanged<List<T>> onChanged;
  final String Function(T) labelBuilder;
  
  /// If true, the "All" pill can stay selected (True All mode).
  /// If false, it acts as a stateless "Select All / Select None" toggle.
  final bool allowTrueAll;

  /// Explicitly control the selected state of the "All" pill (only used if [allowTrueAll] is true).
  final bool isAllSelected;

  /// Callback when the "All" pill is tapped.
  final VoidCallback onAllToggled;

  const MultiSelectChipGroup({
    super.key,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    required this.labelBuilder,
    required this.isAllSelected,
    required this.onAllToggled,
    this.allowTrueAll = true,
  });

  @override
  Widget build(BuildContext context) {
    final allItemsSelected = options.isNotEmpty && 
        options.every((element) => selectedValues.contains(element));
    
    final String allPillLabel;
    final bool isPillChecked;

    if (allowTrueAll) {
      allPillLabel = 'All';
      isPillChecked = isAllSelected;
    } else {
      allPillLabel = allItemsSelected ? 'Select None' : 'Select All';
      isPillChecked = false; // Never marked when True All is off
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        // "All" Control Pill
        FilterChip(
          label: Text(allPillLabel),
          selected: isPillChecked,
          onSelected: (_) => onAllToggled(),
          // Use Tertiary colors to make the "Select All" pill distinct from regular options
          selectedColor: Theme.of(context).colorScheme.tertiaryContainer,
          checkmarkColor: Theme.of(context).colorScheme.onTertiaryContainer,
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPillChecked 
                ? Theme.of(context).colorScheme.onTertiaryContainer 
                : (allItemsSelected && !allowTrueAll ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.tertiary),
          ),
          side: isPillChecked 
            ? const BorderSide(style: BorderStyle.none)
            : BorderSide(color: allItemsSelected && !allowTrueAll ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.tertiary),
        ),
        
        // Option Pills
        ...options.map((option) {
          final isSelected = selectedValues.contains(option);
          return FilterChip(
            label: Text(labelBuilder(option)),
            selected: isSelected,
            onSelected: (bool selected) {
              final newValues = List<T>.from(selectedValues);
              if (selected) {
                newValues.add(option);
              } else {
                newValues.remove(option);
              }
              onChanged(newValues);
            },
          );
        }),
      ],
    );
  }
}
