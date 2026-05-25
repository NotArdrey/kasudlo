revoke all on function public.handle_new_user_profile()
  from public, anon, authenticated;
grant execute on function public.handle_new_user_profile()
  to service_role;

revoke all on function public.is_kasudlo_admin(uuid)
  from public, anon;
grant execute on function public.is_kasudlo_admin(uuid)
  to authenticated, service_role;

revoke all on function public.kasudlo_jsonb_text_array(jsonb)
  from public, anon, authenticated;
grant execute on function public.kasudlo_jsonb_text_array(jsonb)
  to service_role;

revoke all on function public.kasudlo_submit_household_assessment(jsonb, text)
  from public, anon;
grant execute on function public.kasudlo_submit_household_assessment(jsonb, text)
  to authenticated;

revoke all on function public.kasudlo_log_audit_event(text, text, text, text, jsonb)
  from public, anon;
grant execute on function public.kasudlo_log_audit_event(text, text, text, text, jsonb)
  to authenticated;

revoke all on function public.kasudlo_admin_list_audit_logs(integer, text)
  from public, anon;
grant execute on function public.kasudlo_admin_list_audit_logs(integer, text)
  to authenticated;
