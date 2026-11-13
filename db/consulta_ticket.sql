begin;
-- Conserva el contrato de consulta anterior sin revelar IDs internos de personal/turnos.
create or replace function public.consultar_multa(p_folio text,p_placa text) returns setof public.multas
language plpgsql security definer set search_path='' as $$declare r public.multas;begin
 if length(coalesce(p_folio,''))>50 or length(coalesce(p_placa,'')) not between 3 and 16 then return;end if;
 select * into r from public.multas where folio=upper(trim(p_folio)) and placa=upper(regexp_replace(p_placa,'[^A-Za-z0-9]','','g'));
 if r.folio is null then return;end if;
 r.emisor_id:=null;r.turno_id:=null;r.solicitud:=null;r.tarifa_id:=null;return next r;
end $$;
-- No se crea ni se concede un endpoint nuevo: se reducen campos del existente.
commit;
