-- Table des signets (bookmarks) — à exécuter dans l'éditeur SQL Supabase.
-- Nécessaire pour lib/services/supabase_service.dart (fetchBookmarks,
-- addBookmark, removeBookmark) et l'écran flipbook_viewer_screen.dart.
--
-- user_id est rempli automatiquement par défaut avec auth.uid(), donc le
-- code Dart existant (qui n'envoie que flipbook_id/page/note à l'insertion)
-- fonctionne sans modification.

create table if not exists public.bookmarks (
  id uuid primary key default gen_random_uuid(),
  flipbook_id uuid not null references public.flipbooks(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  page integer not null check (page > 0),
  note text,
  created_at timestamptz not null default now(),
  unique (flipbook_id, user_id, page)
);

alter table public.bookmarks enable row level security;

create policy "Users can view their own bookmarks"
  on public.bookmarks for select
  using (user_id = auth.uid());

create policy "Users can insert their own bookmarks"
  on public.bookmarks for insert
  with check (user_id = auth.uid());

create policy "Users can delete their own bookmarks"
  on public.bookmarks for delete
  using (user_id = auth.uid());

create index if not exists bookmarks_flipbook_id_idx on public.bookmarks (flipbook_id);
