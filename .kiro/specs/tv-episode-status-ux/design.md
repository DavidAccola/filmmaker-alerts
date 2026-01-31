# TV Episode Status Screen UX - Design Document

## Overview

This design refactors the TV show configuration screen to use standard checkbox conventions for hierarchical selection. The new design eliminates the confusing "edit mode" paradigm and provides always-visible controls with tri-state checkboxes.

## Architecture

### Component Hierarchy

```
ShowConfigurationScreen
├── AppBar (title, filter button)
├── StatusSelectorBar (always visible)
│   └── SegmentedButton or FilterChips for status selection
├── ShowLevelCheckbox (tri-state: all/some/none)
└── SeasonList
    └── SeasonItem (for each season)
        ├── SeasonCheckbox (tri-state)
        ├── SeasonHeader (name, episode count)
        └── EpisodeList (expandable)
            └── EpisodeItem (for each episode)
                ├── EpisodeCheckbox
                ├── EpisodeNumber
                ├── EpisodeTitle
                └── StatusIndicator (📖 ▶ ✓ ✗)
```

## Wireframes

### Desktop Layout (≥768px)

```
┌─────────────────────────────────────────────────────────────────┐
│ [←] Show Title                                        [Filter]  │
├─────────────────────────────────────────────────────────────────┤
│  Status to apply: [📖 Want to Watch] [▶ In Progress] [✓ Watched] [✗ DNF]  │
├─────────────────────────────────────────────────────────────────┤
│  [▣] Mark All Episodes                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [▣] Season 1 (8 episodes)                              [▼]     │
│  ├─ [☑] E01 - Pilot                                    ✓        │
│  ├─ [☑] E02 - The Beginning                            ✓        │
│  ├─ [☐] E03 - Rising Action                                     │
│  └─ [☐] E04 - The Twist                                         │
│                                                                 │
│  [☐] Season 2 (10 episodes)                             [▶]     │
│                                                                 │
│  [☑] Season 3 (6 episodes)                              [▼]     │
│  ├─ [☑] E01 - Return                                   ✓        │
│  ├─ [☑] E02 - Consequences                             ✓        │
│  └─ ...                                                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

Legend:
[☐] = Unchecked    [☑] = Checked    [▣] = Indeterminate (some checked)
[▼] = Expanded     [▶] = Collapsed
```

### Mobile Layout (<768px)

```
┌─────────────────────────────┐
│ [←] Show Title      [Filter]│
├─────────────────────────────┤
│ Status to apply:            │
│ [📖] [▶] [✓] [✗]            │
├─────────────────────────────┤
│ [▣] Mark All                │
├─────────────────────────────┤
│ [▣] Season 1 (8 ep)    [▼]  │
│   [☑] E01 Pilot        ✓    │
│   [☑] E02 Beginning    ✓    │
│   [☐] E03 Rising            │
│   [☐] E04 Twist             │
├─────────────────────────────┤
│ [☐] Season 2 (10 ep)   [▶]  │
├─────────────────────────────┤
│ [☑] Season 3 (6 ep)    [▼]  │
│   [☑] E01 Return       ✓    │
│   [☑] E02 Conseq...    ✓    │
└─────────────────────────────┘
```

## Component Specifications

### 1. StatusSelectorBar

Always-visible bar at the top showing which status will be applied when checking boxes.

```dart
class StatusSelectorBar extends StatelessWidget {
  final WatchStatus selectedStatus;
  final ValueChanged<WatchStatus> onStatusChanged;
}
```

**Behavior:**
- Uses `SegmentedButton` on desktop, compact `FilterChip` row on mobile
- Shows status symbol + text on desktop, symbol only on mobile
- Default selection: `WatchStatus.watched`
- Changing selection does NOT affect already-marked items

**Visual:**
- Sticky at top (doesn't scroll)
- Subtle background color to distinguish from content
- Selected status highlighted with primary color

### 2. TriStateCheckbox

Custom checkbox widget supporting three states: checked, unchecked, indeterminate.

```dart
class TriStateCheckbox extends StatelessWidget {
  final bool? value; // true=checked, false=unchecked, null=indeterminate
  final ValueChanged<bool?>? onChanged;
  final bool enabled;
}
```

**Behavior:**
- `null` (indeterminate) → clicking sets to `true` (checked)
- `true` (checked) → clicking sets to `false` (unchecked)
- `false` (unchecked) → clicking sets to `true` (checked)

**Visual:**
- Uses Flutter's built-in `Checkbox` with `tristate: true`
- Indeterminate shows horizontal dash (—)

### 3. ShowLevelCheckbox

Top-level checkbox for marking the entire show.

```dart
class ShowLevelCheckbox extends StatelessWidget {
  final bool? value; // Computed from all episodes
  final ValueChanged<bool?> onChanged;
  final int totalEpisodes;
  final int markedEpisodes;
}
```

**State Computation:**
- `true` if ALL episodes have a status
- `false` if NO episodes have a status
- `null` if SOME episodes have a status

**Behavior:**
- Clicking when indeterminate → marks all remaining unmarked episodes
- Clicking when checked → clears all episode statuses
- Clicking when unchecked → marks all episodes

### 4. SeasonItem

Expandable section for each season with tri-state checkbox.

```dart
class SeasonItem extends StatelessWidget {
  final int seasonNumber;
  final String seasonName;
  final List<EpisodeStatusEntry> episodes;
  final bool? checkboxValue; // Computed from episodes
  final bool isExpanded;
  final ValueChanged<bool?> onCheckboxChanged;
  final VoidCallback onToggleExpand;
  final WatchStatus selectedStatus;
}
```

**State Computation:**
- `true` if ALL episodes in season have a status
- `false` if NO episodes in season have a status
- `null` if SOME episodes in season have a status

**Visual:**
- Season header with checkbox, name, episode count
- Expand/collapse chevron icon
- Indented episode list when expanded
- Shows aggregate status indicator when collapsed

### 5. EpisodeItem

Individual episode row with checkbox and status indicator.

```dart
class EpisodeItem extends StatelessWidget {
  final int episodeNumber;
  final String episodeTitle;
  final WatchStatus? currentStatus;
  final bool isChecked;
  final ValueChanged<bool> onCheckboxChanged;
}
```

**Visual:**
- Checkbox on left
- Episode number (E01, E02, etc.)
- Episode title (truncated if needed)
- Status symbol on right (📖 ▶ ✓ ✗) if has status

## State Management

### Local State (StatefulWidget)

```dart
class _ShowConfigurationScreenState extends ConsumerState<ShowConfigurationScreen> {
  // Currently selected status to apply
  WatchStatus _selectedStatus = WatchStatus.watched;
  
  // Track pending changes: Map<seasonNumber, Map<episodeNumber, WatchStatus?>>
  // null means "clear status", WatchStatus means "set to this status"
  Map<int, Map<int, WatchStatus?>> _pendingChanges = {};
  
  // Track which seasons are expanded
  Set<int> _expandedSeasons = {};
  
  // Dirty flag for unsaved changes
  bool _isDirty = false;
}
```

### Computed Properties

```dart
// Get effective status for an episode (pending change or existing)
WatchStatus? _getEpisodeStatus(int seasonNumber, int episodeNumber) {
  if (_pendingChanges[seasonNumber]?.containsKey(episodeNumber) ?? false) {
    return _pendingChanges[seasonNumber]![episodeNumber];
  }
  return _existingStatuses[seasonNumber]?[episodeNumber];
}

// Compute checkbox state for season
bool? _getSeasonCheckboxState(int seasonNumber, List<EpisodeStatusEntry> episodes) {
  int marked = 0;
  for (final ep in episodes) {
    if (_getEpisodeStatus(seasonNumber, ep.episodeNumber) != null) {
      marked++;
    }
  }
  if (marked == 0) return false;
  if (marked == episodes.length) return true;
  return null; // indeterminate
}

// Compute checkbox state for entire show
bool? _getShowCheckboxState() {
  // Similar logic across all seasons
}
```

## Interaction Flows

### Flow 1: Mark Single Episode

1. User taps episode checkbox
2. If unchecked → set to `_selectedStatus`
3. If checked → clear status (set to null)
4. Update `_pendingChanges`
5. Recompute parent season checkbox state
6. Recompute show-level checkbox state
7. Set `_isDirty = true`

### Flow 2: Mark Entire Season

1. User taps season checkbox
2. Compute current state (checked/unchecked/indeterminate)
3. If indeterminate or unchecked → mark all episodes with `_selectedStatus`
4. If checked → clear all episode statuses
5. Update `_pendingChanges` for all episodes in season
6. Recompute show-level checkbox state
7. Set `_isDirty = true`

### Flow 3: Mark Entire Show

1. User taps show-level checkbox
2. Compute current state
3. If indeterminate or unchecked → mark all episodes in all seasons
4. If checked → clear all statuses
5. Update `_pendingChanges` for all episodes
6. Set `_isDirty = true`

### Flow 4: Change Status Selection

1. User taps different status in StatusSelectorBar
2. Update `_selectedStatus`
3. NO changes to existing marks (only affects future checkbox actions)

### Flow 5: Save Changes

1. User taps Save button (FAB or AppBar action)
2. Iterate through `_pendingChanges`
3. For each episode with non-null status → call `addStatusToEpisode`
4. For each episode with null status → call `removeStatusFromEpisode`
5. Clear `_pendingChanges`
6. Set `_isDirty = false`
7. Show success snackbar

### Flow 6: Navigate Away with Unsaved Changes

1. User attempts to navigate back
2. If `_isDirty` → show confirmation dialog
3. "Save" → execute save flow, then navigate
4. "Discard" → clear changes, navigate
5. "Cancel" → stay on screen

## Visual Design

### Colors & Theming

- Status selector background: `surfaceContainerHighest`
- Selected status chip: `primaryContainer` with `primary` border
- Checkbox colors: default Material theme
- Episode row hover: subtle `surfaceContainerLow`
- Status symbols: plain text (no color coding per requirements)

### Spacing

- Status bar padding: 12px vertical, 16px horizontal
- Season header padding: 12px all sides
- Episode row padding: 8px vertical, 16px horizontal (+ 24px left indent)
- Episode list indent: 24px from season header

### Typography

- Season name: `titleMedium`, `fontWeight: w600`
- Episode count: `bodySmall`, `onSurfaceVariant`
- Episode number: `bodyMedium`, `fontWeight: w500`
- Episode title: `bodyMedium`
- Status symbols: default text size

## Status Symbols Reference

| Status | Symbol | Meaning |
|--------|--------|---------|
| Want to Watch | 📖 | Queued for watching |
| In Progress | ▶ | Currently watching |
| Watched | ✓ | Completed |
| Did Not Finish | ✗ | Abandoned |

## Removed Features

The following features from the current implementation are being removed:

1. **Edit Mode Toggle** - No longer needed; checkboxes always active
2. **Mode Snackbar** - Replaced by always-visible StatusSelectorBar
3. **FAB for Edit** - FAB now only for Save (or removed entirely if auto-save)
4. **Season-level status records** - Only track episode-level statuses; season state is computed

## Migration Notes

- Existing episode statuses preserved
- Existing season-level statuses converted to episode-level on first load
- No data loss during migration

## Accessibility

- All checkboxes have semantic labels
- Keyboard navigation supported (Tab through items)
- Screen reader announces checkbox states
- Sufficient color contrast for status indicators
- Touch targets minimum 48x48dp

## Testing Considerations

### Unit Tests
- Checkbox state computation (show/season level)
- Status application logic
- Pending changes management

### Widget Tests
- Checkbox interactions update state correctly
- Status selector changes don't affect existing marks
- Expand/collapse behavior
- Save flow persists changes

### Integration Tests
- Full flow: select status → mark episodes → save → verify persistence
- Navigation with unsaved changes
- Filter interaction with checkboxes
