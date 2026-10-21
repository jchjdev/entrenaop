# Peticiones profesionales vinculadas a la cuenta · 21/10/2026

## Alcance y estado

La ampliación TRN-020 conserva cuentas, permisos administrativos, acceso
profesional y relaciones independientes. Un cambio de cuenta tampoco debe
trasladar a otra sesión una petición preparada con contenido de la anterior.
El helper y los adaptadores están integrados y validados con las baterías de
Trainer, ADMIN, editor común y deportista; su publicación se acredita aparte.

## Sesión fijada por petición

La revisión del SDK instalado (`supabase` 2.16.1, `postgrest` 2.9.1) confirma que
el cliente HTTP consulta la sesión asíncronamente antes de adjuntar el bearer.
Comprobar el usuario antes y después del `await` evita entregar una respuesta a
la pantalla equivocada, pero por sí solo no fija con qué sesión se envía.

`packages/trainer_access/lib/authenticated_rpc.dart` centraliza el transporte
autenticado de las RPC profesionales:

- Comprueba sesión existente, titular esperado y cuenta no anónima.
- Si la sesión caduca, espera su renovación, comprueba de nuevo la identidad y
  captura la sesión vigente del mismo titular antes de preparar la petición.
- Fija el bearer en el builder devuelto por `setHeader`, sin otro `await` entre
  captura y preparación. Sobrescribe todas las variantes heredadas de la
  cabecera Authorization solo en esa petición; no muta cabeceras globales.
- Comprueba de nuevo la identidad tanto al recibir respuesta como al fallar.
  Una renovación del mismo usuario puede completar la petición; otra cuenta
  recibe un error y no el resultado anterior.

No concede derechos ni sustituye JWT, MFA, acceso profesional, RLS o propiedad
del recurso en servidor. No guarda ni registra tokens. Las RPC POST no tienen
reintento automático en esta versión del SDK: el consumidor conserva la orden
idempotente para un nuevo intento explícito.

## Consumidores y límites

Trainer conecta acceso/clientes, agenda, sesiones, programas, ejercicios,
preferencias, revisión, grupos, recurrencia, ficha, formularios, evaluaciones y
mensajes mediante ese helper. La app del deportista lo usa para formularios,
evaluaciones y técnica profesionales, además de los contratos compartidos de
acceso y mensajes. ADMIN puede reutilizarlo mediante sus adaptadores; compartir
el helper no abre su contexto a Trainer.

Las nuevas RPC de trabajos de programas añaden además `p_expected_owner`
obligatorio y lo comparan con `auth.uid()` antes de consultar o escribir.
El historial de Salud tiene la misma barrera en su propio contrato; los medios
ya comprueban `expected_user_id` en la función de vídeo. Esos campos son una
comprobación adicional, nunca autoridad para escoger al propietario.

Este cambio no modifica todos los métodos Auth/MFA del SDK ni todas las
peticiones de EntrenaOP. Las consultas directas existentes conservan sus filtros
y permisos propios. El helper comprueba UID, no una generación global: los
anfitriones y las features siguen desmontando estado o invalidando respuestas al
salir y cambiar de cuenta. Una petición ya enviada con A puede confirmarse en A
tras cerrar sesión; no se revierte una transacción por descartar su respuesta.

## Evidencia dirigida

Doce regresiones con `SupabaseClient` real y HTTP simulado, sin red, cubren sesión
normal/ausente/anónima/ajena, cabeceras con distinto uso de mayúsculas, renovación
del mismo titular, cambio de cuenta durante renovación, respuestas inciertas y
nuevos intentos. El caso de control reproduce en el SDK sin protección el envío
de un payload de A con token de B; el helper lo rechaza antes de enviar la RPC.

La prueba del router real de Trainer conserva UUID, controlador y texto crudo
al renovar sesión, verifica autosave a 700 ms y recupera el checkpoint al volver
a la misma URL. Las pruebas no atribuyen esa evidencia a una sesión humana ni
a una publicación web todavía no realizada de este cambio.
