# KASUDLO

KASUDLO is a Flutter mobile application for community health data gathering during nursing community duty. It supports worker login, household data collection, health assessment checklists, SQLite offline saving, Supabase sync retry, and simple monitoring reports.

## Run

Flutter is installed for this workspace at:

```powershell
C:\Users\Neila\devtools\flutter\bin\flutter.bat
```

Run in local demo mode:

```powershell
$env:Path='C:\Users\Neila\devtools\flutter\bin;' + $env:Path
flutter run
```

Local demo mode seeds sample household records once so the dashboard and reports can be tested immediately. If all demo records are deleted, they will not be automatically re-added for that same local browser/device store.

Run against Supabase:

```powershell
$env:Path='C:\Users\Neila\devtools\flutter\bin;' + $env:Path
flutter run `
  --dart-define=SUPABASE_URL=https://ombfilswymuhsaovefuc.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key> `
  --dart-define=PASSWORD_RESET_REDIRECT_URL=com.kasudlo.kasudlo://login-callback
```

Do not commit PATs, database passwords, service-role keys, or Stitch API keys.

## Implemented

- Stitch-generated design direction: `Fieldwork Utility & Trust`
- Login and password reset with Supabase Auth when configured
- Admin-only account creation with Supabase roles and Edge Function scaffold
- Home dashboard with survey, family member, pending sync, and synced counts
- Household/community data collection form
- Family member entry, dropdowns, checklists, consent gate, save draft, submit
- SQLite-backed offline queue with sync status
- Supabase online mode with automatic retry when connectivity returns
- Timestamp-aware refresh/merge so pending SQLite work is not overwritten by older remote rows
- Reports for vaccination, nutrition, water/sanitation, health problems, and concerns
- Append-only audit log for auth, admin, collection, report, sync, and refresh actions
- Settings screen for profile, sync, privacy status, retry, and sign out
- Supabase schema with RLS and `kasudlo_submit_household_assessment`

## Admin accounts

Account creation is handled from the in-app Admin page. The public login screen only signs users in.

Local demo mode treats emails that start with `admin` as admin accounts so the Admin page can be reviewed without Supabase. For live Supabase use:

1. Apply the migration in `supabase/migrations`.
2. Deploy `supabase/functions/kasudlo-admin-users` with JWT verification enabled.
3. Configure `SUPABASE_SERVICE_ROLE_KEY` as a Supabase Edge Function secret.
4. Manually seed the first admin:

```sql
update public.profiles set role = 'admin' where email = 'admin@example.com';
```

After that, admins can create worker or admin accounts from the Admin page.

## Password reset

The login screen can send Supabase password reset emails and complete the new
password step after the email link returns to the app. Add
`com.kasudlo.kasudlo://login-callback` to Supabase Authentication Settings as an
Additional Redirect URL, or provide your own callback with
`PASSWORD_RESET_REDIRECT_URL`.

## Audit log

The Admin page includes an audit log that lists recent system actions. Live mode
writes events through `kasudlo_log_audit_event`; only admins can read events via
`kasudlo_admin_list_audit_logs`.

## Verification

```powershell
$env:Path='C:\Users\Neila\devtools\flutter\bin;' + $env:Path
dart format --set-exit-if-changed .
flutter analyze
flutter test
```
