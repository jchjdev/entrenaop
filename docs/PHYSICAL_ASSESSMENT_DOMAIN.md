# Dominio de evaluación física

Última revisión: 20 de septiembre de 2026.

## Decisión vigente

EntrenaOP no modelará `PAEF` o `PAFA` como si fueran una única oposición fija.
Son denominaciones históricas o específicas de determinados ejércitos. La
[Orden DEF/15/2026](https://www.boe.es/eli/es/o/2026/01/13/def15) establece un
régimen unificado y separa, entre otros contextos, ingreso, formación, egreso y
evaluación periódica.

Cada catálogo tendrá un identificador de versión, fuente oficial y fecha de
vigencia. Una marca guardada conservará la versión del baremo con la que fue
evaluada. Publicar una versión nueva no recalculará silenciosamente el
histórico.

## Primera vertical

El primer catálogo implementado es `es_def_15_2026_troop_v1`, correspondiente
a las escalas de tropa y marinería del anexo III. Incluye los tres hitos
oficiales:

- ingreso;
- fin de la fase de formación militar general;
- fin de la enseñanza de formación.

Las cuatro pruebas son flexo-extensiones de brazos en dos minutos, plancha
isométrica, carrera continua de 2.000 metros y circuito de
agilidad-velocidad. Las categorías `men` y `women` reflejan literalmente las
dos columnas H/M del baremo oficial; no se reutilizarán como identidad de
género del usuario.

## Reglas de modelado

- Las repeticiones y los tiempos son unidades distintas y no se pueden
  comparar entre sí.
- En flexiones y plancha una marca mayor es mejor; en carrera y agilidad un
  tiempo menor es mejor.
- Los tiempos se almacenan internamente en milisegundos para conservar décimas
  en agilidad sin usar números decimales.
- La prueba acuática pertenece a determinados accesos de oficiales y
  suboficiales; no forma parte de este primer catálogo de tropa y marinería.
- Los baremos de evaluación periódica de la nueva orden entran en vigor el 1 de
  enero de 2027. Se implementarán como otro catálogo, no mezclados con ingreso.

## Estado de la primera vertical

Se ha elegido como primer recorrido al aspirante a tropa y marinería que prepara
las pruebas de ingreso. La aplicación permite seleccionar el baremo H/M,
introducir las cuatro marcas, obtener un informe con el mínimo y el margen de
cada prueba, guardar el intento y consultar el historial propio.

La persistencia separa la cabecera de la evaluación de sus cuatro marcas. El
cliente envía las mediciones originales a la función
`record_physical_assessment`; PostgreSQL comprueba de nuevo la sesión, versión,
categoría, hito, número de pruebas, identificadores y valores antes de insertar
todo en una única transacción. La interfaz no puede concederse a sí misma un
resultado apto.

Las políticas RLS limitan el historial al propietario y a los administradores.
La vista `physical_assessment_results` reconstruye cada resultado desde la marca
y el baremo versionado, conservando el criterio que se usó en ese momento.

El historial agrupa correctamente las cuatro filas de la vista en una única
evaluación y compara los dos últimos intentos. La diferencia favorable mantiene
el mismo significado en todas las pruebas: positiva es mejora, aunque para
carrera y agilidad se obtenga reduciendo el tiempo.

El siguiente bloque funcional partirá de estos datos para orientar el objetivo
del usuario y preparar una primera recomendación explicable. La evaluación
periódica y otros accesos se incorporarán como catálogos posteriores sin alterar
esta primera vertical.
