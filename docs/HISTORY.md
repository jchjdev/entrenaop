# Contexto histórico y procedencia

Este documento conserva el sentido del traspaso realizado desde el trabajo
anterior. **No es una lista de instrucciones vigente.** Si contradice el código,
`AGENTS.md` o una decisión posterior, pierde prioridad.

## Contexto recibido

El desarrollo anterior describía EntrenaOP como una aplicación Flutter con
Supabase, Bloc/Cubit, una interpretación estricta de Clean Architecture, GetIt,
`go_router` y Material 3. Indicaba que autenticación, login, perfil automático y
la base de datos inicial ya funcionaban, y proponía continuar por ejercicios,
registro, rutinas, sesión activa, PAEF/PAFA, panel, chat e integraciones.

También documentaba como tablas remotas supuestamente existentes:

- `profiles`
- `exercises`
- `routines`
- `routine_exercises`
- `session_logs`

Se mencionó un trigger de creación automática de perfil y RLS. Ninguna de estas
afirmaciones sobre el proyecto remoto debe darse por verificada mientras no se
contraste con migraciones, esquema o panel de Supabase.

## Propuestas antiguas que requieren verificación

- Un campo `profiles.role` mezclaba Free, Premium, seguimiento y administración.
- `session_logs` solo contemplaba duración, completado, RPE, estado y notas.
- `routine_exercises` tenía una estructura plana de series, repeticiones,
  duración, peso y descanso.
- Se afirmaba que todo usuario únicamente veía sus propios datos.
- Se propusieron seis destinos en una barra inferior.
- Se daban por previstas 300–500 piezas de vídeo en Supabase Storage.
- Se citaban Flutter 3.35.2 y estados concretos del emulador y las herramientas.

Son antecedentes útiles, pero no decisiones cerradas ni hechos actuales.

## Reglas antiguas expresamente retiradas

El traspaso anterior pedía seguir siempre estas reglas, que ya no son vigentes:

- Extender siempre `Equatable` sin valorar el caso.
- Crear siempre repositorio abstracto y un caso de uso por operación.
- Hacer commit después de cada feature.
- Usar siempre `context.go()` y nunca otras formas de navegación.
- No crear `CHECK constraints` y confiar la validación a Flutter.
- Seguir obligatoriamente una secuencia fija de nueve capas/pasos para cualquier
  feature.

Las sustituyen los criterios de `AGENTS.md` y `docs/ARCHITECTURE.md`.

## Hallazgos provisionales trasladados

El documento nuevo señaló para futura comprobación:

- Posible ausencia de una llamada inicial a `checkCurrentUser()`.
- Conversión forzada de `ExerciseEntity` a `ExerciseModel`.
- Uso de `.single()` en una búsqueda cuyo contrato permite `null`.
- Ausencia de pruebas reales.
- Uso de `print` en autenticación o perfil.
- Configuración de Supabase acoplada al código.
- Cambios previos de Git que deben preservarse.

Estos puntos son hipótesis de auditoría, salvo aquellos confirmados y registrados
posteriormente en documentación vigente.

## Fuentes originales fuera del repositorio

El contexto procedía de `Pegado text.txt` y de un texto de traspaso posterior
aportados por Javier el 19 de septiembre de 2026. Su información estable se ha
normalizado en `AGENTS.md`, `PRODUCT.md`, `ARCHITECTURE.md` y `ROADMAP.md` para
que futuras tareas no dependan de archivos del escritorio ni de una conversación
concreta.
