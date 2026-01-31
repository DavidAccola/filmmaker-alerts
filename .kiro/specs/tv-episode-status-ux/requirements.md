# TV Episode Status Screen UX Refactor

## Problem Statement
The current TV show configuration screen for marking episodes as watched/in-progress/etc. is unintuitive. Users must:
1. Enter "edit mode" via FAB before making any changes
2. Select a status mode first, then tap items to apply that status
3. Navigate a confusing hierarchy between show-level, season-level, and episode-level marking

The standard convention for hierarchical selection (like file managers, email clients) uses checkboxes with tri-state behavior that users already understand.

## User Stories

### US-1: Mark Entire Show
As a user, I want to mark the entire show with a single checkbox, so that I can quickly indicate I've watched everything.

**Acceptance Criteria:**
- A "Mark All" checkbox at the top of the screen
- Checking it marks all seasons and all episodes with the currently selected status
- Unchecking it clears all episode and season statuses
- Shows indeterminate state (dash) when some but not all episodes are marked
- Clicking an indeterminate checkbox marks all remaining unmarked episodes

### US-2: Mark Entire Season
As a user, I want to mark an entire season using a checkbox, so that I can quickly indicate I've watched a whole season.

**Acceptance Criteria:**
- Each season header has a checkbox
- Checking the season checkbox marks all episodes in that season with the selected status
- Unchecking clears all episode statuses in that season
- Shows indeterminate state when some episodes in the season are marked
- Clicking an indeterminate checkbox marks all remaining episodes in that season

### US-3: Mark Individual Episodes
As a user, I want to mark individual episodes with checkboxes, so that I can track my progress episode by episode.

**Acceptance Criteria:**
- Each episode row has a checkbox
- Checking an episode marks it with the currently selected status
- Unchecking an episode clears its status
- Episode checkboxes update parent season/show checkbox states automatically

### US-4: Select Status Before Marking
As a user, I want to select which status I'm applying before I start checking boxes, so that I can mark items as "Watched", "In Progress", etc.

**Acceptance Criteria:**
- Status selector is always visible (not hidden in edit mode)
- Options: Want to Watch, In Progress, Watched, Did Not Finish
- Default selection is "Watched" (most common use case)
- Changing the status selector does NOT change already-marked items
- Only newly checked items get the currently selected status

### US-5: Visual Status Indicators
As a user, I want to see the current status of each episode at a glance, so that I know where I left off.

**Acceptance Criteria:**
- Each episode shows its current status with the existing symbol indicators (📖 ▶ ✓ ✗)
- Unmarked episodes show no symbol
- Season headers show aggregate status or mixed indicator if episodes have different statuses

## Design Principles
1. **Standard checkbox conventions** - Tri-state checkboxes for hierarchical selection
2. **No hidden modes** - Status selector and checkboxes always accessible
3. **Visual hierarchy** - Show > Season > Episode relationship clear through indentation
4. **Immediate feedback** - Checkbox states update instantly
5. **Preserve existing symbols** - Keep current status symbols for familiarity

## Out of Scope
- Rewatch tracking (handled elsewhere)
- Episode details/synopsis display
- Air date filtering
- Color-coded status badges (keep existing symbols)
