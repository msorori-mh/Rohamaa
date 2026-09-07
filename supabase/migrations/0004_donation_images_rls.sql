create policy "donation_image_rows_owner_select" on public.donation_images
for select to authenticated
using (
  exists (
    select 1 from public.donations d
    where d.id = donation_id and d.user_id = auth.uid()
  )
);

create policy "donation_image_rows_owner_insert" on public.donation_images
for insert to authenticated
with check (
  exists (
    select 1 from public.donations d
    where d.id = donation_id and d.user_id = auth.uid()
  )
);

create policy "donation_image_rows_owner_delete" on public.donation_images
for delete to authenticated
using (
  exists (
    select 1 from public.donations d
    where d.id = donation_id and d.user_id = auth.uid()
  )
);
