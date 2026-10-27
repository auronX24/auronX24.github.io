-- ============================================================
-- Sistem Tracking Perbaikan Mesin - skema Supabase
-- Jalankan SEKALI di: Supabase > SQL Editor > New query > Run
-- ============================================================

-- 1. TABEL ---------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nama text not null,
  role text not null default 'produksi' check (role in ('produksi','manager','staff','editor')),
  created_at timestamptz not null default now()
);

create table public.tickets (
  id text primary key,
  mesin text not null,
  lokasi text not null default '-',
  masalah text not null,
  prioritas text not null default 'Sedang' check (prioritas in ('Tinggi','Sedang','Rendah')),
  pelapor text not null,
  pelapor_id uuid references auth.users(id) on delete set null,
  staff_id uuid references auth.users(id) on delete set null,
  staff_nama text,
  status text not null default 'dilaporkan' check (status in ('dilaporkan','ditugaskan','perbaikan','verifikasi','siap','closed')),
  tgl timestamptz not null default now(),
  upd timestamptz not null default now(),
  n_foto int not null default 0,
  log jsonb not null default '[]'::jsonb
);

create table public.photos (
  id uuid primary key default gen_random_uuid(),
  ticket_id text not null references public.tickets(id) on delete cascade,
  path text not null,
  oleh text,
  at timestamptz not null default now()
);
create index photos_ticket_idx on public.photos(ticket_id);
create index tickets_tgl_idx on public.tickets(tgl desc);

-- 2. FUNGSI BANTU --------------------------------------------
create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

-- Profil dibuat otomatis saat daftar. Pengguna PERTAMA = Editor.
-- Pendaftar berikutnya hanya boleh 'produksi' atau 'staff'.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare r text; n text;
begin
  n := coalesce(nullif(trim(new.raw_user_meta_data->>'nama'),''), split_part(new.email,'@',1));
  if not exists (select 1 from public.profiles) then r := 'editor';
  elsif new.raw_user_meta_data->>'role' in ('produksi','staff') then r := new.raw_user_meta_data->>'role';
  else r := 'produksi';
  end if;
  insert into public.profiles(id, nama, role) values (new.id, n, r);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Hanya Editor yang boleh mengubah peran
create or replace function public.guard_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role and auth.uid() is not null
     and coalesce(public.my_role(),'') <> 'editor' then
    raise exception 'Hanya Editor yang boleh mengubah peran';
  end if;
  return new;
end $$;
create trigger guard_profile before update on public.profiles
  for each row execute function public.guard_profile();

-- Jumlah foto + riwayat tiket diperbarui otomatis
create or replace function public.sync_photos() returns trigger
language plpgsql security definer set search_path = public as $$
declare tid text; c int; who text; msg text;
begin
  if tg_op = 'INSERT' then
    tid := new.ticket_id; who := coalesce(new.oleh,''); msg := 'Foto ditambahkan';
  else
    tid := old.ticket_id; who := coalesce((select nama from public.profiles where id = auth.uid()),''); msg := 'Foto dihapus';
  end if;
  select count(*) into c from public.photos where ticket_id = tid;
  update public.tickets
     set n_foto = c, upd = now(),
         log = log || jsonb_build_array(jsonb_build_object('w', now(), 's', msg, 'o', who, 'c', '1 foto'))
   where id = tid;
  return null;
end $$;
create trigger photos_sync after insert or delete on public.photos
  for each row execute function public.sync_photos();

-- Editor menghapus pengguna
create or replace function public.hapus_pengguna(target uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_role() <> 'editor' then raise exception 'Hanya Editor yang boleh menghapus pengguna'; end if;
  if target = auth.uid() then raise exception 'Tidak bisa menghapus akun sendiri'; end if;
  delete from auth.users where id = target;
end $$;
revoke all on function public.hapus_pengguna(uuid) from public, anon;
grant execute on function public.hapus_pengguna(uuid) to authenticated;

-- 3. KEAMANAN (Row Level Security) ---------------------------
alter table public.profiles enable row level security;
alter table public.tickets  enable row level security;
alter table public.photos   enable row level security;

create policy profiles_read on public.profiles for select to authenticated using (true);
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid() or public.my_role() = 'editor')
  with check (id = auth.uid() or public.my_role() = 'editor');

create policy tickets_read on public.tickets for select to authenticated using (true);
create policy tickets_insert on public.tickets for insert to authenticated
  with check (public.my_role() in ('produksi','manager','editor') and pelapor_id = auth.uid() and status = 'dilaporkan');
create policy tickets_upd_editor on public.tickets for update to authenticated
  using (public.my_role() = 'editor') with check (public.my_role() = 'editor');
create policy tickets_upd_manager on public.tickets for update to authenticated
  using (public.my_role() = 'manager' and status in ('dilaporkan','siap')) with check (public.my_role() = 'manager');
create policy tickets_upd_staff on public.tickets for update to authenticated
  using (public.my_role() = 'staff' and staff_id = auth.uid() and status in ('ditugaskan','perbaikan'))
  with check (public.my_role() = 'staff' and staff_id = auth.uid());
create policy tickets_upd_produksi on public.tickets for update to authenticated
  using (public.my_role() = 'produksi' and status = 'verifikasi') with check (public.my_role() = 'produksi');
create policy tickets_delete on public.tickets for delete to authenticated using (public.my_role() = 'editor');

create policy photos_read on public.photos for select to authenticated using (true);
create policy photos_insert on public.photos for insert to authenticated with check (public.my_role() is not null);
create policy photos_delete on public.photos for delete to authenticated using (public.my_role() = 'editor');

-- 4. PENYIMPANAN FOTO (bucket privat "foto") -----------------
insert into storage.buckets (id, name, public) values ('foto','foto', false) on conflict (id) do nothing;
create policy foto_read   on storage.objects for select to authenticated using (bucket_id = 'foto');
create policy foto_insert on storage.objects for insert to authenticated with check (bucket_id = 'foto');
create policy foto_delete on storage.objects for delete to authenticated using (bucket_id = 'foto' and public.my_role() = 'editor');

-- 5. REALTIME (data tampil langsung di semua perangkat) ------
alter publication supabase_realtime add table public.tickets, public.profiles, public.photos;
