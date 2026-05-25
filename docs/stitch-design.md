# Stitch Design Reference

Stitch project: `projects/6140356844698170466`

Session: `6993611639392253574`

Design system: `Fieldwork Utility & Trust`

## Tokens

- Primary: `#0F766E`
- Primary dark: `#005C55`
- Secondary: `#4F46E5`
- Warning: `#D97706`
- Critical: `#E11D48`
- Surface: `#F8F9FA`
- Border: `#BDC9C6`
- Text: `#191C1D`
- Muted text: `#3E4947`
- Radius: `4px` for inputs/buttons, up to `8px` for cards
- Spacing: `8px` rhythm, `16px` mobile margin
- Touch targets: minimum `44px`, primary buttons `48px`

## Screens Generated

- Login
- Home Dashboard
- Data Collection
- Reports
- Settings
- Admin / User Management

The Flutter implementation maps this directly to a Material 3 utility interface with bottom navigation, outlined cards, large form controls, and clear health-worker actions.

## Admin Screen Prompt

Generate a mobile-first `Admin / User Management` screen for KASUDLO using the existing `Fieldwork Utility & Trust` design system. Preserve the teal primary color, indigo secondary color, white utility cards, low-radius controls, 8px spacing rhythm, strong form labels, and 44px minimum touch targets.

Target responsive widths: 360px, 390px, 430px, and tablet. On phones, keep the create-account form and account list in a single column with keyboard-safe scrolling. On wider screens, allow account summary cards to wrap into two columns.

Required content:

- Admin status header with signed-in email and live/local badge
- Account metrics for all accounts, admins, and workers
- Create account form with role segmented control, full name, email, temporary password, and primary create action
- Searchable account directory with role badges and compact list rows
- Loading, empty, validation, and error states

## Admin Implementation Mapping

- Header uses `AppCard`, a secondary admin icon tile, and existing `StatusBadge`.
- Metrics use responsive wrapping cards that switch from one column on small screens to two columns on wider screens.
- Role selection uses Material 3 segmented buttons for `Worker` and `Admin`.
- Directory rows use compact list tiles with role-colored avatars and badges.
