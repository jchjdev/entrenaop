# Acceso profesional y relación del piloto · TRN-008/009

> Estado posterior: TRN-011 habilita la gestión manual y la primera cuenta de
> cinco plazas solo en Dev; el panel está publicado y verificado por HTTPS.
> La entrada humana con TOTP sigue pendiente. [Publicación actual](TRAINER_HOSTING_2026_10_21.md).

## Estado comprobado · 20/10/2026

La migración `20261020072345_trainer_access_and_client_relations.sql` está aplicada
solo a `entrenaop-dev`. Hay 167 migraciones local/Dev coincidentes. No hay cambios
Flutter, paquetes, producción ni cobros. La configuración manual empieza y sigue
deshabilitada; no se habilita a ninguna cuenta real ni se concede Pro.

Javier confirma un único preparador activo por alumno y que el acceso mediante
entrenador no debe conceder creación personal ilimitada. La relación no toca
`has_pro_access`, Free/Pro, permisos administrativos ni cuotas personales. El
alumno Free conserva ocho ejercicios propios y cuatro sesiones propias; un Pro
individual conserva sus derechos independientes. El acceso incluido al contenido
asignado aún necesita su integración y no está implementado por estas tablas.

## Contrato

| Recurso | Comportamiento |
| --- | --- |
| `trainer_access_settings` | Gestión manual desactivada por defecto y sin privilegios de cliente. Su activación requiere una operación de confianza posterior. |
| `trainer_access` | Vigencia, habilitación y cupo positivo por preparador, separados de Pro. Revisión optimista de configuración y versión interna de membresía. |
| `trainer_access_audit` | Actor, motivo, revisión y estados de las concesiones/cambios. Solo lo consulta el responsable administrativo autorizado. |
| `trainer_invitations` | ID estable y hash SHA-256 del secreto, vigencia de siete días, cancelación y uso único. No contiene el secreto en claro. |
| `trainer_client_relations` | Aceptación explícita, partes y finalización. Un índice único parcial protege el preparador activo por alumno; terminar conserva el registro y libera plaza. |

`get_trainer_access` devuelve el estado propio; el responsable puede consultar
el estado comercial de otra cuenta. `admin_set_trainer_access` exige
`can_manage_pro_accounts()` —incluido su control MFA— y la configuración manual
habilitada. Recibe revisión esperada y motivo. El reintento idéntico no duplica
la concesión ni la auditoría; una revisión obsoleta se rechaza.

El cupo cuenta vínculos aceptados con `ended_at` ausente. Las invitaciones
pendientes o relaciones terminadas no ocupan plaza. Se permite deshabilitar el
acceso sin borrar vínculos; el piloto manual rechaza habilitar/reducir un cupo
inferior a los vínculos activos. No resuelve todavía una bajada comercial de
paquete ni concede nuevas facultades al alumno por conservar la relación.

## Invitación y aceptación

1. El futuro cliente profesional generará 32 bytes mediante un generador
   criptográficamente seguro y los representará en 64 caracteres hexadecimales.
   Conservará ese secreto y un UUID durante los reintentos de creación. El
   servidor comprueba formato, derecho profesional y coincidencia al reintentar.
2. `create_trainer_invitation` guarda solo el hash y devuelve metadatos. No
   consulta el directorio de usuarios ni envía mensajes automáticamente.
3. `preview_trainer_invitation` exige una cuenta autenticada no anónima y el
   secreto. Muestra el preparador y su nombre, sin aceptar ni enumerar alumnos.
4. `accept_trainer_invitation` fija al alumno desde Auth; no recibe un alumno
   arbitrario. Comprueba acceso vigente, código válido, ausencia de preparador
   activo y capacidad. La misma aceptación devuelve el mismo vínculo mientras
   siga activo; nunca resucita uno terminado ni permite que otro use el código.
5. `cancel_trainer_invitation` corresponde al preparador; cancelar un código ya
   utilizado no termina su vínculo. `end_trainer_relation` permite terminar a
   cualquiera de las dos partes, también con el acceso profesional caducado.

La entrega del secreto y su futura interfaz/QR siguen pendientes. Debe ir en el
cuerpo de la petición, sin registrarse en logs ni publicarse en catálogos. La
posesión del código permite solicitar esa vinculación; por eso solo lo debe
recibir el alumno previsto y la vista previa debe preceder a su aceptación.

## Autorización y concurrencia

Las tablas tienen RLS y no permiten escritura directa al cliente. Cada parte
solo consulta sus relaciones; gestionar cuentas no permite verlas por defecto.
El preparador ve metadatos de sus invitaciones, sin hashes. La relación no abre
el perfil completo ni el historial personal de resultados. La asignación y los
medios privados necesitarán permisos por recurso en el bloque correspondiente.

Las siete RPC públicas son `SECURITY INVOKER`; las operaciones privilegiadas
viven en `trainer_private`, fuera de los esquemas expuestos, con `search_path`
vacío y autorización explícita. Se revocan permisos PUBLIC/anon y se conceden
solo los necesarios a authenticated. No se utiliza metadata editable para
conceder acceso.

La aceptación bloquea primero el contexto del alumno, después el acceso del
preparador y la invitación. La última plaza se comprueba dentro del bloqueo.
La versión interna de membresía cambia al aceptar/terminar para que un snapshot
obsoleto de REPEATABLE READ produzca conflicto en lugar de exceder el cupo.
La unicidad de preparador está además en un índice SQL independiente de la RPC.

## Verificaciones y límites del 20/10/2026 · ampliados en TRN-010

- `trainer_access_and_relations.sql`: concesión reservada al gestor, MFA,
  configuración cerrada, revisiones/reintentos, anonimato y metadata editable,
  RLS A/B/alumnos/gestor, escritura directa y hashes rechazados, vista previa,
  cupo y preparador único, cancelación/caducidad, reintento sin duplicación,
  finalización por ambas partes, liberación de plaza y conservación del vínculo.
- Un alumno vinculado Free crea ocho ejercicios y cuatro sesiones propios;
  el noveno ejercicio y la quinta sesión se rechazan con los motivos de cuota
  existentes. La vinculación no le concede Pro.
- Regresiones SQL `account_directory_and_manager.sql` y
  `pro_access_and_free_quotas.sql` correctas. Las tres pruebas terminan con
  `ROLLBACK`; una lectura posterior confirma cero concesiones, vínculos,
  invitaciones, auditorías y usuarios `@trainer-contract.invalid` de ensayo.
- Asesores de seguridad/performance revisados para los objetos nuevos. La
  configuración cerrada genera el aviso informativo esperado de
  [RLS sin política](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy):
  carece también de grants de cliente y solo la leen operaciones privilegiadas.
  Los índices nuevos de FK aparecen como no usados en una base sin uso real;
  no hay warnings nuevos sobre las RPC profesionales. Avisos ajenos no se cambian.

La prueba de última plaza es secuencial y comprueba restricciones y estados,
no acredita dos aceptaciones realmente simultáneas. El ensayo con conexiones
concurrentes, incluido snapshot obsoleto, queda requerido antes de habilitar
cuentas del piloto. Tampoco acredita interfaces, asignación/ejecución profesional,
acceso incluido con cuotas agotadas o consulta de resultados. El recorrido
profesional permanece abierto; el siguiente bloque integra estas interfaces y
completa esa verificación. No se ejecuta Flutter por un cambio solo SQL/documental.

## Ampliación comprobada · 21/10/2026 · TRN-010

El contrato base se conserva y ahora tiene interfaces en ADMIN, trainer_app y
Perfil → Mi preparador. Se añaden resumen autorizado de contraparte y directorio
profesional del gestor, sin abrir perfiles ni historiales. TOTP verificado y AAL2
son obligatorios en servidor para operar como profesional; el alumno mantiene
su autenticación habitual para aceptar/finalizar. Las implementaciones internas
sin MFA ya no se pueden ejecutar desde roles cliente. La prueba original se
actualiza con factores/sesiones profesionales MFA.

La limitación del ensayo secuencial descrita arriba se amplía con quince
contenciones reales en PostgreSQL local 17.6 desechable, ejecutando las migraciones
originales; Auth/RLS y cuotas se acreditan aparte con ROLLBACK contra Dev.
178 migraciones coinciden y no quedan usuarios ni concesiones de prueba.
Esto no acredita un recorrido TOTP humano remoto ni habilita el piloto.
[Contrato ampliado, interfaces y evidencia](TRAINER_PORTAL_2026_10_21.md).
