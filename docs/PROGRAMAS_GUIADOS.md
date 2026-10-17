# Programas guiados oficiales

## Acuerdo e implementación por bloques · 17/10/2026

Javier autoriza implementar PRG-001 conservando Biblioteca, preparaciones
adaptativas y ejecutores actuales. ADMIN elige guía repetible o recorrido por
fases en el mismo creador. Ambos contienen sesiones para entrenar y registrar
resultados. El autor define duración y condiciones de cada fase; el usuario
confirma el avance, sin consumo automático de etapas por calendario.

ADMIN crea calentamientos reutilizables y los adjunta opcionalmente a cada
sesión. El deportista puede omitirlos. Los descansos configurables conservan
pauta y ajuste personal separados; el ajuste genérico se limita a bloques
convencionales, sin alterar formatos temporizados ni el motor adaptativo.

## Bloque 1 · Autoría en ADMIN

Implementados catálogo y creador común, orden de fases/sesiones, duración,
condiciones, selección de sesiones oficiales generales publicadas, calentamiento
por sesión y límites de descanso entre series. Una guía usa una fase repetible
sin plazo. Publicación y retirada son explícitas; editar una publicación crea
un borrador nuevo. Las sesiones se crean y publican desde el editor existente.

El creador de calentamientos reutiliza campos, ejercicios públicos y series
convencionales del editor. Guarda una versión oficial privada con bloques
`warm_up`; no aparece como sesión suelta. Revisarla conserva las referencias
previas. No se adjunta otro calentamiento a una sesión que ya incluya uno.

### Contrato e integración

- `workout_core/guided_program.dart`: entidades y validación pura.
  `guided_program_codec.dart`: adaptación JSON fuera de las entidades.
- `admin_app/lib/features/guided_programs/`: repositorio, adaptador y pantallas.
  Los widgets no consultan Supabase directamente.
- `guided_programs`: documento editorial versionado. `guided_program_links`
  acredita sesiones/calentamientos con claves foráneas y posiciones.
- `guided_warmups`: familia, versión y plantilla privada.
- `save_guided_program`, `save_guided_warmup`, `set_guided_program_status`:
  transacciones administrativas con `search_path` vacío y grants explícitos.
  Las tablas conceden al cliente solo lectura con RLS.
- No se admite una sesión privada de oposición como contenido libre. Retirar
  una sesión de un programa publicado se rechaza para no romper ese programa.

Migración `20261017101000_guided_program_authoring.sql`, aplicada únicamente
a `entrenaop-dev`. Prueba instalada `guided_program_authoring.sql` con ROLLBACK:
autoría, guía/fases, descansos inválidos, referencias, versiones y permisos.
Sin contenido de prueba persistido ni ejemplos publicados.

Validación: análisis de raíz y ADMIN limpios; 927 pruebas raíz y 111 ADMIN
correctas, con sus omisiones existentes. Los avisos del asesor para las tres
RPC autenticadas son deliberados: la autorización administrativa se comprueba
dentro y está cubierta por SQL. Los avisos anteriores de Auth y otras funciones
no se corrigen dentro de este alcance.

### Límites y siguiente bloque

Este cierre habilita la autoría. El recorrido del deportista aún no está
implementado: catálogo, seguimiento, sesión preparada con calentamiento/ajustes
y confirmación de fases. Sin cambios de motor, ejecutor, cuotas o producción.

**Único siguiente bloque:** Biblioteca y seguimiento versionado, integración
con el ejecutor y pruebas de omisiones, ajustes, reintentos y avance de fases.
