-- Add the new attachments column
alter table public.health_tips
  add column if not exists attachments jsonb not null default '[]'::jsonb;

-- Migrate existing attachments into the new column
update public.health_tips
set attachments = jsonb_build_array(
  jsonb_build_object(
    'file_name', file_name,
    'mime_type', mime_type,
    'file_size', file_size,
    'attachment_base64', attachment_base64
  )
)
where length(btrim(file_name)) > 0
  and length(btrim(attachment_base64)) > 0;

-- Drop the old columns
alter table public.health_tips
  drop column if exists file_name,
  drop column if exists mime_type,
  drop column if exists file_size,
  drop column if exists attachment_base64;
