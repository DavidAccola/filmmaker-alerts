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

  /// Breakpoint for switching to compact checkbox list layout
  static const double _compactBreakpoint = 400.0;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use checkbox list on small screens, chips on larger screens
        if (constraints.maxWidth < _compactBreakpoint) {
          return _buildCheckboxList(context);
        } else {
          return _buildChipWrap(context);
        }
      },
    );
  }

  /// Compact checkbox list for small screens
  Widget _buildCheckboxList(BuildContext context) {
    final theme = Theme.of(context);
    final allItemsSelected = options.isNotEmpty && 
        options.every((element) => selectedValues.contains(element));
    
    final String allLabel;
    final bool isAllChecked;

    if (allowTrueAll) {
      allLabel = 'All';
      isAllChecked = isAllSelected;
    } else {
      allLabel = allItemsSelected ? 'Select None' : 'Select All';
      isAllChecked = false;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "All" option
        _CheckboxListItem(
          label: allLabel,
          isSelected: isAllChecked,
          isAllOption: true,
          onTap: onAllToggled,
        ),
        const Divider(height: 1),
        // Regular options in a 2-column grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 4.0,
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
          ),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            final isSelected = selectedValues.contains(option);
            return _CheckboxListItem(
              label: labelBuilder(option),
              isSelected: isSelected,
              onTap: () {
                final newValues = List<T>.from(selectedValues);
                if (isSelected) {
                  newValues.remove(option);
                } else {
                  newValues.add(option);
                }
                onChanged(newValues);
              },
            );
          },
        ),
      ],
    );
  }

  /// Chip wrap layout for larger screens
  Widget _buildChipWrap(BuildContext context) {
    final allItemsSelected = options.isNotEmpty && 
        options.every((element) => selectedValues.contains(element));
    
    final String allPillLabel;
    final bool isPillChecked;

    if (allowTrueAll) {
      allPillLabel = 'All';
      isPillChecked = isAllSelected;
    } else {
      allPillLabel = allItemsSelected ? 'Select None' : 'Select All';
      isPillChecked = false;
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

/// Compact checkbox list item widget
class _CheckboxListItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isAllOption;
  final VoidCallback onTap;

  const _CheckboxListItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isAllOption = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                activeColor: isAllOption 
                    ? theme.colorScheme.tertiary 
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isAllOption ? FontWeight.bold : FontWeight.normal,
                  color: isAllOption 
                      ? theme.colorScheme.tertiary 
                      : theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
