# Directorio: provincia, isla y localidad · 02/11/2026

Javier confirma que la ubicación corresponde a las fichas de entrenadores,
no al perfil personal del deportista. El caso de aceptación es encontrar a Ervi
por «Gran Canaria» aunque su localidad sea «Telde».

## Comportamiento

La ficha permite elegir provincia del catálogo español: las 50 provincias y
Ceuta/Melilla. En Illes Balears, Las Palmas y Santa Cruz de Tenerife aparece
además un selector de isla opcional. La localidad es texto libre opcional y
admite hasta 80 caracteres. Al cambiar provincia se limpia la isla anterior.
La Graciosa se incluye como opción de Las Palmas, sin asignarle un código INE.
Fuentes: [provincias INE](https://www.ine.es/daco/daco42/codmun/cod_provincia.htm)
e [islas INE](https://www.ine.es/daco/daco42/codmun/cod_islas.htm), con
[La Graciosa en Las Palmas](https://www.miteco.gob.es/es/parques-nacionales-oapn/centros-fincas/graciosa/ficha-tecnica.html).

En presencial basta con provincia o con la localidad ya admitida; en online no
se obliga a indicar ubicación. La ficha muestra localidad, isla y provincia,
omitiendo valores vacíos y repeticiones exactas. Si no hay localidad, muestra la
provincia y, cuando se indique, la isla.

El campo «Provincia, isla o localidad» es de búsqueda libre. Compara todos los
datos de ubicación y admite palabras parciales en cualquier orden, sin
distinguir tildes o mayúsculas y tolerando espacios repetidos. «Telde», «Gran
Canaria», «Las Palmas» y «Canarias» encuentran la misma ficha si el profesional
ha completado provincia/isla. El buscador general también incluye la ubicación.
No se exige conocer una localidad ni se cambia a un filtro por igualdad exacta.
Los caracteres % y _ se interpretan literalmente, sin ampliar resultados.

## Datos, arquitectura y compatibilidad

El catálogo y la etiqueta de ubicación permanecen en el dominio puro de
`trainer_access/directory`. El adaptador traduce `province_code` e `island` y
la presentación consume el mismo contrato desde deportista y Trainer. No se
introducen dependencias ni se altera el motor de chat o la relación de alumnos.

La migración `20261102201433_trainer_directory_locations.sql` añade ambos campos
al esquema privado, valida provincias e islas también en servidor y permite
provincia sin localidad. Conserva las puertas de identidad/MFA, acceso vigente,
consentimiento, visibilidad app/web, moderación, favoritos y paginación. Mantiene
la firma de las RPC actuales. Un cliente antiguo que omite los nuevos campos
conserva sus valores, y las fichas antiguas no reciben ubicaciones inferidas.

El texto de acceso del editor contempla también el regalo explícito de ficha
que desarrolla el bloque de ADMIN, sin confundirlo con cualquier acceso manual.
Ambos bloques se guardan en commits separados. Se mantienen los datos y hunks
ajenos durante la integración.

## Verificación

La migración se ensayó con su contrato SQL dentro de una transacción revertida
y se aplicó únicamente a Dev `sxbxfjqgoddzhtcyhalw`. Después pasaron, siempre con
ROLLBACK, `trainer_directory_locations`, `trainer_directory`,
`trainer_directory_dev_pilot`, `trainer_directory_contacts` y
`trainer_directory_paid_plan_access`. Comprueban ubicación, tildes, palabras,
provincia sin localidad, claves antiguas, filtros, cursor, favoritos, validación,
propiedad, visibilidad y moderación. No dejan cuentas, fotos ni fichas de prueba.
El historial acredita la migración aplicada. Advisors conserva exactamente sus
avisos previos: 126 INFO y 152 WARN, sin nuevos avisos de este bloque.

Validación aislada de main más este bloque: análisis limpio de raíz, Trainer y
ADMIN; baterías completas con 1.714 correctas/una omisión previa en raíz,
445 correctas en Trainer y 368 correctas/dos omisiones previas en ADMIN. La
integración final del texto de acceso pasó además las cinco pruebas del editor.
No se modifican dependencias. Versiones: deportista `1.2.0+5` y Trainer `0.2.0+2`.

Una consulta transaccional con el emisor Dev requerido por el piloto confirma
que Javier y Ervi conservan elegibilidad hasta el 28/11/2026 a las 21:07:47 UTC,
fichas publicadas solo en la app y sin suspensión. Ervi conserva «TELDE» y aún no
ha completado provincia/isla. Es una comprobación de servidor, no un inicio de
sesión real ni la aceptación manual del recorrido.

## Ensayo con Ervi

1. Recargar Trainer Dev y abrir «Mi ficha pública» con la cuenta de Ervi.
2. Elegir Las Palmas y Gran Canaria; mantener Telde y guardar la ficha.
3. Desde una cuenta de alumno, buscar por Telde, Gran Canaria, Las Palmas y
   Canarias; comprobar que se abre la misma ficha con su ubicación completa.
4. Dejar localidad vacía, guardar y comprobar que sigue apareciendo al buscar
   por Las Palmas o Gran Canaria. La ficha debe mostrar provincia/isla.

Este es el único siguiente recorrido de aceptación. No se dan por realizadas
las acciones de Ervi, no se cambian sus datos ni su consentimiento por él y no
se amplía todavía a centros, mapas o geolocalización. La app local necesita
recompilar para mostrar el nuevo campo y la etiqueta; Trainer se sirve desde
su publicación Dev verificada. Producción no se consulta ni modifica.

## Publicación comprobada

El bloque de ubicación se guarda en `864aa4e1`; la integración con el regalo
opcional de ficha queda en `ce1f27407477fdf8ac532d633d3873d3334bd2bc`. Ambos
commits se subieron juntos, manteniendo main estable durante las publicaciones.
Las validaciones y el despliegue de
[Trainer Dev](https://github.com/jchjdev/entrenaop/actions/runs/41541658189)
han terminado correctamente. También finalizaron la validación, publicación y
conservación de paquetes de
[ADMIN Dev](https://github.com/jchjdev/entrenaop/actions/runs/41541658068);
su comprobación auxiliar de conservación necesitó un reintento por transporte,
resuelto sin modificar código ni repetir la publicación.

La comprobación HTTPS independiente acredita en ambos hosts el commit
`ce1f2740`, entorno development, proyecto Dev, fuentes limpias, SHA-256 del
JavaScript, arranque y recursos correctos. El `version.json` de cada publicación
aislada confirma `0.2.0+2`; el archivo legado de la raíz no identifica la versión
activa. La evidencia local se conserva en
`build/directory-location-publication-proof.json`. Queda pendiente únicamente
el ensayo manual descrito arriba, sin modificar la ficha de Ervi por él.
