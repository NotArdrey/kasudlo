-- Let admins restore or permanently delete archived household assessments.
drop policy if exists household_assessments_update_own
  on public.household_assessments;
drop policy if exists household_assessments_update_own_or_admin
  on public.household_assessments;
create policy household_assessments_update_own_or_admin
on public.household_assessments
for update
to authenticated
using (auth.uid() = user_id or public.is_kasudlo_admin(auth.uid()))
with check (auth.uid() = user_id or public.is_kasudlo_admin(auth.uid()));

drop policy if exists household_assessments_delete_own
  on public.household_assessments;
drop policy if exists household_assessments_delete_own_or_admin
  on public.household_assessments;
create policy household_assessments_delete_own_or_admin
on public.household_assessments
for delete
to authenticated
using (auth.uid() = user_id or public.is_kasudlo_admin(auth.uid()));
