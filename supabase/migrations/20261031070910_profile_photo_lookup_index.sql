begin;
-- La política de descarga consulta la referencia vigente por nombre de objeto.
-- Los usuarios sin foto no necesitan ocupar este índice.
create index profile_photo_current_path on profile_private.photos(path) where path is not null;
commit;
