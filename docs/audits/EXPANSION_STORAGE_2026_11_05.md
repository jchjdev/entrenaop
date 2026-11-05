# Aislamiento del estado de desplegables · 05/11/2026

Javier pide extender la revisión del bloque gris de FAS/Tropa a ADMIN, Trainer,
los componentes compartidos y la app del deportista. Se conserva el diseño y
los contratos de negocio. No hay paquetes, migraciones, permisos ni reglas
deportivas nuevos.

## Causa y alcance contrastado

Flutter guarda tanto el plegado como el desplazamiento mediante PageStorage.
Sin identificadores distintos, ExpansionTile escribe un bool en la entrada que
Scrollable, TextField, SelectableText o DropdownMenu intenta recuperar como
double. También puede ocurrir a la inversa al volver a montar un apartado.

El inventario sintáctico de lib/, admin_app/lib/, trainer_app/lib/ y los lib/
de packages/ identifica 73 ExpansionTile. La revisión inicial encuentra 42 sin
clave propia; cuatro usan ValueKey, que no separa PageStorage, y AMRAP alterna
la clave persistente con una GlobalKey de enfoque. Los demás conservan sus claves
existentes. No se presenta cada ausencia de clave como un fallo visible actual:
su reproducción depende del árbol padre, de controles interiores y del estado
que ya haya guardado la página.

## Corrección localizada

- Cada desplegable conserva identidad independiente. Las listas usan recurso,
  posición o sesión; los paneles únicos nombran su función. AMRAP mantiene el
  enfoque inicial colocando su GlobalKey en el título, separado del plegado.
- ADMIN: laboratorios, soporte, seguridad y revisión escrita. Trainer: códigos de
  invitación/autenticador, ayudas de pruebas, medios, ejercicios y actividades.
- Creadores compartidos: metadatos de sesión/programa/fase, propiedades del
  bloque, clasificación, calentamiento/descansos y comparador de resultados.
  Los campos conservan sus selectores y controladores; el estado interior tiene
  una clave diferente de la del desplegable. No se rediseñan los creadores.
- Deportista: dispositivos, información de programas, historiales, avisos,
  disponibilidad/material, preparación y consultas de semanas. La búsqueda de
  material conserva el texto al plegar y reabrir.
- Restaurar un desplegable puede notificar durante build. Las cargas diferidas
  de soporte y bandeja, la revisión y los ajustes de sesión esperan al siguiente
  frame y comprueban que el contexto siga vigente antes de actualizar estado.

## Verificación y límites

Una regresión con el formulario real de material bajo scroll persistente falla
antes del arreglo con bool no es double y pasa después. Las pruebas de ciclo de
vida de metadatos remontan ambos creadores con el estado de página conservado.
Se añaden restauración de soporte y bandeja, y despliegue de clave manual Trainer
con datos ficticios. Las baterías completas detectan además DropdownMenu de zona
horaria y campos de minutos concretos de carrera; se aíslan y sus 23 pruebas
relacionadas pasan. La revisión ADMIN detecta el callback durante build y sus
16 pruebas pasan tras aplazarlo.

Versiones del bloque: deportista 1.18.1+39, ADMIN 0.7.2+14 y Trainer 0.3.3+9.
Análisis de raíz, ADMIN, Trainer y workout_editor_ui sin incidencias. Las baterías
completas terminan con 1.880 pruebas raíz y una omisión previa; 409 ADMIN y dos
omisiones previas; 451 Trainer y 252 del creador compartido. Total: 2.992 correctas.
La compilación web release del deportista exclusivamente contra Dev es correcta.
No cambian los lockfiles. Una compilación web y una prueba de widgets no
acreditan instalación/aceptación física del nuevo cliente en iPhone.

## Publicación acreditada

Commit funcional a51045140b02832c69d0e51a6f5c23ba497dc0e4. ADMIN Dev 42113739020
y Trainer Dev 42113739226 completan validación, compilación, despliegue HTTPS y
retención. Las comprobaciones de Salud 42113738836 y Garmin 42113738962 también
terminan correctamente. CI repite 1.880 pruebas raíz, 409 ADMIN y 451 Trainer.

La consulta HTTPS independiente de admin.entrenaop.es y trainer.entrenaop.es
confirma la misma revisión, versiones 0.7.2+14 y 0.3.3+9, sourceTreeDirty=false,
entorno development y proyecto sxbxfjqgoddzhtcyhalw. Se comprueban version.json,
base del índice, SHA-256 de main.dart.js, Cache-Control no-store y
X-Frame-Options DENY. Producción y tiendas no se publican.

Trainer conserva sesión en el navegador integrado: se comprueban biblioteca,
cuenta y Para mí; la bandeja de actividades recibidas carga, pliega y reabre sin
bloque gris y sin errores nuevos de esta revisión en consola. No se crea una
sesión para verificar el editor: la revisión automática rechaza ese clic por
su posible creación de borrador. Los metadatos del creador se acreditan mediante
sus pruebas de ciclo de vida. ADMIN solicita iniciar sesión y se contrasta por
HTTPS y sus pruebas; no se declara una nueva aceptación autenticada global.

El control automático rechazó una edición posicional en lote por riesgo de
inserciones fuera de su constructor. Se resolvió mediante parches por archivo,
revisión de los diffs y comprobación sintáctica; ese intento no se publicó.
Este bloque cubre la colisión de estados y su restauración, no garantiza ausencia
universal de otras causas de bloques grises.
