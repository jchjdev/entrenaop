# Dominio de evaluación física

Última revisión: 23 de septiembre de 2026.

## Decisión vigente

EntrenaOP no modelará `PAEF` o `PAFA` como si fueran una oposición. Son pruebas
internas con reglas propias, tramos de edad, puntuaciones y cálculo agregado;
se incorporarán cuando sus baremos oficiales estén disponibles. Los accesos a
Tropa y Marinería, Suboficiales y Oficiales también serán programas distintos,
aunque compartan parte de la normativa o de las pruebas.

La [Orden DEF/15/2026](https://www.boe.es/eli/es/o/2026/01/13/def15) establece
un régimen unificado y separa, entre otros contextos, ingreso, formación,
egreso y evaluación periódica.

El programa implementado `armed_forces_troop_entry` corresponde al **ingreso
desde fuera a las escalas de Tropa y Marinería**, no a las pruebas periódicas
de quien ya es militar. El artículo 6 comparte los tipos de prueba, pero el
artículo 12 separa las tablas: anexo III para ingreso y anexo II, por marca,
sexo y edad, para evaluación periódica. La disposición transitoria segunda
aplaza la entrada en vigor de los nuevos baremos periódicos al 1 de enero de
2027. Igual ejercicio no implica igual objetivo, puntuación ni programa.

La evaluación inicial que tenía la app antes de incorporar preparaciones usaba
el único catálogo disponible. La migración
`20260920003000_preparation_goals.sql` asoció las evaluaciones existentes de
ese catálogo al programa de Tropa sin alterar las marcas. Eso explica la
sensación de que una evaluación «general» terminó dentro de Tropa: fue una
transición de datos, no una regla de producto para futuros programas. No se
renombrará ni reutilizará su identificador, porque hay preparaciones y
evaluaciones vinculadas. La futura captura inicial debe nacer en el contexto
del programa elegido y permitir reutilizar mediciones compatibles como dato
de entrenamiento, no como apto oficial de otro baremo.

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

La recomendación `assessment_focus_v1` prioriza el mayor déficit porcentual
respecto al mínimo. Cuando las cuatro pruebas están superadas, prioriza la de
menor margen relativo. PostgreSQL guarda la versión, prueba elegida, margen y
razón junto a la evaluación; una versión futura no reescribirá esta decisión.

La prescripción se aplaza hasta validar sus reglas deportivas. La evaluación
periódica y otros accesos se incorporarán como programas y catálogos posteriores
sin alterar esta primera vertical.

## Siguiente piloto de evaluación periódica

Javier prefiere trabajar primero con las pruebas que conoce como PAFAS/PAEF.
Para el nuevo régimen se ha creado el programa estable
`fas_periodic_assessment`, de tipo `internal_assessment`, **habilitado en
desarrollo**.
Ambos nombres se tratan como formas de referirse a esta evaluación periódica,
no como dos baremos inventados. La referencia
`assets/programs/fas_periodic_2027/assessment_reference_v1.json` recoge del
anexo II de la Orden DEF/15/2026 las marcas más bajas o más lentas que
alcanzan **al menos 20 puntos** en cada prueba para los tramos 17–25 a 60+,
según las columnas M/F. Conserva milisegundos para tiempos y no copia los
mínimos de ingreso de Tropa. Conforme al artículo 10, el circuito no se exige
a partir de los 45 años, aunque el último tramo visible de su tabla se titule
41–45. La vigencia de este régimen periódico comienza el 1 de enero de 2027.

Esta referencia **no es el baremo íntegro de 0 a 100 puntos**. La migración
`20260923006000_fas_periodic_assessments.sql` guarda cada intento fechado en
tablas independientes del ingreso, con edad declarada en la fecha del test,
categoría, versión y las tres o cuatro marcas exigibles. El servidor valida
propiedad de la preparación activa, conjunto exacto de pruebas y valores no
negativos. La app permite repetir el test y consultar sus marcas frente al
mínimo de 20 puntos; desde los 45 años el circuito no se exige. Las marcas
anteriores a 2027 quedan etiquetadas como referencia de entrenamiento, no
como evaluación oficial bajo el nuevo régimen. Aún faltan la puntuación
completa, verificación independiente de edad/categoría declaradas y las reglas
de aptitud operativa. Un escenario normativo de 2026 requiere su catálogo
histórico propio; no se le aplican anticipadamente los baremos de 2027.
