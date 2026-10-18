# Programas demo de desarrollo

Solicitados por Javier el 17/10/2026 para probar Biblioteca sin acceso a ADMIN.
El script fija `entrenaop-dev` (`sxbxfjqgoddzhtcyhalw`); no es una migración,
no se ejecuta con `db push` y no cambia usuarios, permisos ni seguimientos reales.
La carga de contenido utiliza las RPC de autoría/publicación, un administrador existente y ejercicios
públicos identificados por su perfil. No incorpora ejercicios nuevos.

- **Demo · Empuje, tirón y pierna:** guía repetible con tres sesiones.
- **Demo · Mejora de dominadas:** tres fases con una sesión por fase; dos semanas
  orientativas cada una y avance confirmado por el usuario.
- Tres calentamientos reutilizables opcionales y descansos ajustables de 60 a
  180 segundos. Sin pesos predeterminados ni adaptación automática.

Contenido para aceptación funcional; no sustituye la revisión editorial
deportiva necesaria para publicar un programa definitivo.

Desde la raíz del repositorio, con Supabase CLI autenticado:

```powershell
# Valida autoría/publicación sin persistir datos.
./tools/guided_programs_demo/run.ps1
# Publica exclusivamente en desarrollo, por petición expresa de Javier.
./tools/guided_programs_demo/run.ps1 -Publish
# Comprueba catálogo, las seis sesiones, calentamientos, descansos y fases.
supabase db query --linked --project-ref sxbxfjqgoddzhtcyhalw --file tools/guided_programs_demo/verify.sql
# Ensaya la clasificación editorial con ROLLBACK.
./tools/guided_programs_demo/run.ps1 -Classify
# Asigna categorías a las demos existentes, exclusivamente en desarrollo.
./tools/guided_programs_demo/run.ps1 -Classify -Publish
```

La carga es atómica e idempotente: una segunda ejecución conserva los mismos
programas y sesiones, sin revisar versiones publicadas. Ante una demo parcial,
se detiene para revisarla. Para editar o retirar estos programas se utiliza
ADMIN, como con el resto del catálogo.

PRG-007 clasifica la rutina con Hipertrofia (principal) y Fuerza, y el programa
de dominadas con Fuerza (principal) e Iniciación. El script de clasificación
conserva las asignaciones existentes: no las sobrescribe al repetirlo. Solo
añade metadatos a las demos que aún no tienen categorías; no crea versiones,
sesiones, seguimientos ni resultados. No se incorpora a las migraciones.
