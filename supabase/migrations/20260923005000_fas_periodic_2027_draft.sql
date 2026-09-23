-- Programa de evaluación periódica de las FAS: identidad separada del ingreso.
-- Permanece oculto al opositor hasta implementar puntuación por edad y sexo,
-- registro específico y validación en PostgreSQL del anexo II completo.

begin;

insert into public.preparation_programs (id, name, kind, enabled)
values (
  'fas_periodic_assessment',
  'Evaluación periódica FAS · 2027 (PAFAS/PAEF)',
  'internal_assessment',
  false
);

commit;
