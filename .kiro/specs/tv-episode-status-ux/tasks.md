# Implementation Plan: TV Episode Status UX

## Overview

This implementation plan refactors the TV show configuration screen to use standard checkbox conventions for hierarchical selection. The new design eliminates the confusing "edit mode" paradigm and provides always-visible controls with tri-state checkboxes.

## Tasks

- [x] 1. Create StatusSelectorBar Component
  - [x] 1.1 Create status_selector_bar.dart file
    - Create new file at lib/ui/common/status_selector_bar.dart
    - Add selectedStatus and onStatusChanged parameters
    - Import WatchStatus enum
    - _Requirements: US-4_
  
  - [x] 1.2 Implement SegmentedButton layout for desktop
    - Use LayoutBuilder to detect screen width >= 768px
    - Create SegmentedButton with 4 segments for each WatchStatus
    - Show symbol + label text on desktop
    - _Requirements: US-4_
  
  - [x] 1.3 Implement compact FilterChip row for mobile
    - Use Row with FilterChip widgets for screens < 768px
    - Show symbol only (no label text) on mobile
    - Add tooltips for accessibility
    - _Requirements: US-4_
  
  - [x] 1.4 Add status symbols with labels
    - Map WatchStatus.wantToWatch to 📖 Want to Watch
    - Map WatchStatus.inProgress to ▶ In Progress
    - Map WatchStatus.watched to ✓ Watched
    - Map WatchStatus.dnf to ✗ Did Not Finish
    - _Requirements: US-5_
  
  - [x] 1.5 Handle onStatusChanged callback
    - Call callback when user taps a different status
    - Ensure selected status is visually highlighted
    - _Requirements: US-4_
  
  - [x] 1.6 Style with surfaceContainerHighest background
    - Apply Container with surfaceContainerHighest color
    - Add 12px vertical, 16px horizontal padding
    - _Requirements: US-4_

- [x] 2. Create TriStateCheckbox Helper Functions
  - [x] 2.1 Create helper functions for tri-state checkbox logic
    - Add private helper methods to _ShowConfigurationScreenState
    - Document tri-state behavior (true/false/null)
    - _Requirements: US-1, US-2_
  
  - [x] 2.2 Implement computeSeasonCheckboxState method
    - Return true if ALL episodes in season have status
    - Return false if NO episodes in season have status
    - Return null if SOME episodes have status (indeterminate)
    - _Requirements: US-2_
  
  - [x] 2.3 Implement computeShowCheckboxState method
    - Return true if ALL episodes across all seasons have status
    - Return false if NO episodes have status
    - Return null if SOME episodes have status (indeterminate)
    - _Requirements: US-1_
  
  - [x] 2.4 Implement getEffectiveEpisodeStatus method
    - Check _pendingChanges first for episode status
    - Fall back to existing persisted status if no pending change
    - Return null if no status exists
    - _Requirements: US-3_

- [x] 3. Refactor State Management
  - [x] 3.1 Remove isEditMode state variable
    - Delete _isEditMode declaration
    - Remove all references to _isEditMode
    - Checkboxes are now always active
    - _Requirements: Design Principles_
  
  - [x] 3.2 Rename selectedMode to selectedStatus with watched default
    - Rename variable throughout file
    - Set initial value to WatchStatus.watched
    - Update all usages
    - _Requirements: US-4_
  
  - [x] 3.3 Refactor localChanges to pendingChanges
    - Rename to _pendingChanges Map of season to episode to WatchStatus
    - null value means clear status
    - WatchStatus value means set to this status
    - _Requirements: US-3_
  
  - [x] 3.4 Add expandedSeasons Set
    - Add Set of int _expandedSeasons
    - Track which season numbers are expanded
    - Default all seasons to collapsed
    - _Requirements: Design Principles_
  
  - [x] 3.5 Remove markedSeasons variable
    - Delete _markedSeasons variable
    - Season state is now computed from episode states
    - Use _computeSeasonCheckboxState instead
    - _Requirements: US-2_

- [x] 4. Build New UI Structure
  - [x] 4.1 Add StatusSelectorBar below AppBar as sticky header
    - Place StatusSelectorBar in Column before scrollable content
    - Pass _selectedStatus and update callback
    - Ensure it stays fixed at top
    - _Requirements: US-4_
  
  - [x] 4.2 Add show-level Mark All checkbox with tri-state support
    - Add Checkbox with tristate true
    - Compute value using _computeShowCheckboxState
    - Label Mark All Episodes
    - _Requirements: US-1_
  
  - [x] 4.3 Replace table/grid layout with expandable list
    - Remove existing DataTable/GridView layout
    - Use ListView.builder with custom season/episode items
    - Support expand/collapse per season
    - _Requirements: Design Principles_
  
  - [x] 4.4 Implement buildSeasonItem method
    - Create method returning Widget for season row
    - Include tri-state Checkbox
    - Show season name and episode count
    - Add expand/collapse IconButton
    - _Requirements: US-2_
  
  - [x] 4.5 Implement buildEpisodeItem method
    - Create method returning Widget for episode row
    - Include binary Checkbox checked/unchecked
    - Show E## Title format
    - Display status symbol on right if has status
    - _Requirements: US-3, US-5_

- [x] 5. Implement Checkbox Interactions
  - [x] 5.1 Episode checkbox toggle between checked and unchecked
    - On check add _selectedStatus to _pendingChanges
    - On uncheck add null to _pendingChanges to clear
    - Set _isDirty to true
    - _Requirements: US-3_
  
  - [x] 5.2 Season checkbox mark/clear all episodes in season
    - If unchecked/indeterminate mark all episodes with _selectedStatus
    - If checked clear all episode statuses set to null
    - Update _pendingChanges for all episodes in season
    - _Requirements: US-2_
  
  - [x] 5.3 Show checkbox mark/clear all episodes in all seasons
    - If unchecked/indeterminate mark all episodes in all seasons
    - If checked clear all episode statuses
    - Update _pendingChanges for entire show
    - _Requirements: US-1_
  
  - [x] 5.4 Update parent checkbox states when child changes
    - Recompute season checkbox state after episode change
    - Recompute show checkbox state after any change
    - Use setState to trigger rebuild
    - _Requirements: US-1, US-2, US-3_
  
  - [x] 5.5 Ensure status selector change does NOT modify existing marks
    - Changing _selectedStatus only affects future checkbox actions
    - Do not iterate through _pendingChanges on status change
    - Existing marks retain their original status
    - _Requirements: US-4_

- [x] 6. Update Save Flow
  - [x] 6.1 Keep FAB as Save button and remove edit mode toggle
    - FAB always shows save icon
    - Remove edit mode toggle functionality
    - Only show FAB when _isDirty is true
    - _Requirements: Design Principles_
  
  - [x] 6.2 Update handleSave to process pendingChanges
    - Iterate through _pendingChanges map
    - For each season/episode entry apply the change
    - Clear _pendingChanges after successful save
    - _Requirements: US-3_
  
  - [x] 6.3 Handle clearing statuses with null values
    - If pending value is null call removeStatusFromEpisode
    - If pending value is WatchStatus call addStatusToEpisode
    - Handle both cases in save loop
    - _Requirements: US-3_
  
  - [x] 6.4 Show success snackbar using showSimpleSnackBar
    - Import snackbar_utils.dart
    - Call showSimpleSnackBar with Changes saved message
    - Set _isDirty to false after save
    - _Requirements: Design Principles_
  
  - [x] 6.5 Keep unsaved changes dialog on navigation
    - Maintain existing PopScope/WillPopScope logic
    - Show dialog if _isDirty is true
    - Options Save Discard Cancel
    - _Requirements: Design Principles_

- [x] 7. Visual Polish
  - [x] 7.1 Add proper indentation for episode rows 24px from season
    - Add Padding with left 24.0 to episode items
    - Ensure visual hierarchy is clear
    - Align checkboxes vertically
    - _Requirements: Design Principles_
  
  - [x] 7.2 Style season headers with expand/collapse chevron
    - Use Icons.expand_more when expanded
    - Use Icons.chevron_right when collapsed
    - Add InkWell for tap feedback
    - _Requirements: Design Principles_
  
  - [x] 7.3 Show status symbol on right side of episode row
    - Add Spacer or Expanded before symbol
    - Display status symbol based on effective status
    - Hide symbol if no status
    - _Requirements: US-5_
  
  - [x] 7.4 Add hover states for desktop
    - Wrap rows in Material with InkWell
    - Use hoverColor from theme
    - Ensure touch feedback on mobile
    - _Requirements: Design Principles_
  
  - [x] 7.5 Ensure mobile layout works well under 768px breakpoint
    - Test on narrow screens
    - Truncate long episode titles with ellipsis
    - Ensure touch targets are 48x48dp minimum
    - _Requirements: Design Principles_

- [x] 8. Remove Deprecated Code
  - [x] 8.1 Remove buildModeSnackbar method
    - Delete the method entirely
    - Remove any calls to _buildModeSnackbar
    - StatusSelectorBar replaces this functionality
    - _Requirements: Design Principles_
  
  - [x] 8.2 Remove edit mode FAB toggle logic
    - Remove FAB onPressed edit mode toggle
    - Remove edit mode icon switching
    - FAB now only handles save
    - _Requirements: Design Principles_
  
  - [x] 8.3 Remove buildModePill method
    - Delete _buildModePill method
    - Remove calls to _buildModePill
    - StatusSelectorBar provides this UI
    - _Requirements: Design Principles_
  
  - [x] 8.4 Clean up unused state variables and methods
    - Remove _isEditMode and related code
    - Remove _markedSeasons and related code
    - Remove any other unused variables
    - _Requirements: Design Principles_
  
  - [x] 8.5 Remove table-based desktop layout
    - Delete DataTable/GridView code
    - Remove responsive table/grid switching
    - Single expandable list layout for all screen sizes
    - _Requirements: Design Principles_

- [x] 9. Testing
  - [x] 9.1 Test tri-state checkbox computation logic
    - Unit test _computeSeasonCheckboxState
    - Unit test _computeShowCheckboxState
    - Test all three states true/false/null
    - _Requirements: US-1, US-2_
  
  - [x] 9.2 Test episode marking/unmarking updates parent states
    - Mark single episode verify season becomes indeterminate
    - Mark all episodes verify season becomes checked
    - Unmark all episodes verify season becomes unchecked
    - _Requirements: US-3_
  
  - [x] 9.3 Test season marking marks all episodes
    - Click unchecked season checkbox
    - Verify all episodes in season get _selectedStatus
    - Verify season checkbox becomes checked
    - _Requirements: US-2_
  
  - [x] 9.4 Test show marking marks all seasons and episodes
    - Click unchecked show checkbox
    - Verify all episodes in all seasons get _selectedStatus
    - Verify all season checkboxes become checked
    - _Requirements: US-1_
  
  - [x] 9.5 Test status selector change does not affect existing marks
    - Mark some episodes as Watched
    - Change selector to In Progress
    - Verify existing marks still show Watched
    - _Requirements: US-4_
  
  - [x] 9.6 Test save persists changes correctly
    - Make various changes mark/unmark
    - Click save
    - Reload screen and verify changes persisted
    - _Requirements: US-3_

## Notes

- All tasks are required for comprehensive implementation
- The refactor eliminates edit mode - checkboxes are always active
- Status selector only affects future checkbox actions, not existing marks
- Tri-state checkboxes follow standard conventions (file managers, email clients)
