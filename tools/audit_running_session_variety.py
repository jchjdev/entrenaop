"""Diagnóstico de sesiones reales. No cambia el motor ni prescribe alternativas."""
from collections import Counter
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'docs/audits/FAS_SEIS_MESES_CORREGIDO_2026_10_16.json'
j=json.loads(p.read_text(encoding='utf8'))
sessions=[s for w in j['weeks'] for s in w['decision']['running']['sessions']]
families=Counter(s['family'] for s in sessions)
variants=Counter(s['variant_code'] for s in sessions)
assert sum(families.values())==61
lines=['# Diagnóstico de variedad de carrera · 16/10/2026','',
 'Inspección del ensayo corregido de seis meses anterior a los controles automáticos. No se cambia catálogo, calentamiento, selección, progresión ni motor de carrera en este diagnóstico.','',
 f'Fuente: `{p.relative_to(ROOT).as_posix()}`. SHA-256: `{hashlib.sha256(p.read_bytes()).hexdigest()}`.','',
 '## Qué recibió realmente este perfil','',
 '| Familia | Sesiones | Formato utilizado |','| --- | --- | --- |',
 f'| Fácil E | {families["E"]} | Carrera continua fácil; duración variable. |',
 f'| Sostenidos T | {families["T"]} | Cinco de 2 × 5 min; una de 2 × 6 min. Recuperación 2 min. |',
 f'| Aeróbicos V | {families["V"]} | Seis de 4 × 2 min, recuperación 2 min. |',
 f'| Específico S | {families["S"]} | Cuatro de 6 × 200 m, recuperación 1:30. |',
 '| Progresivos R | 0 | No seleccionados en este caso. |','',
 'La observación de Javier sobre repetición de series tiene fundamento. No todo son intervalos de dos minutos, pero el repertorio efectivamente utilizado es reducido. No salió ninguna serie de 400, 500, 600, 800 o 1.000 m. Los rodajes fáciles representan 45 de las 61 salidas; el reparto fácil/calidad no demuestra por sí solo un defecto.','',
 'Todas las sesiones de calidad publicadas contienen 10 min de calentamiento. La vuelta a la calma absorbe el tiempo restante después del trabajo y recuperaciones, con mínimo de 6 min. Es una regla de construcción explícita, no una elección individual del calentamiento para cada sesión.','',
 '## Catálogo que sí está conectado al motor','',
 '| Familia | Escalones del catálogo actual |','| --- | --- |',
 '| T | 2 × 5, 6, 8, 10 o 12 min; recuperación 2 min. |',
 '| V | 4/5/6 × 2 min; 4/5 × 3 min; 4 × 4 min (último con 3 min de recuperación). |',
 '| S | 6/8/10 × 200 m; 5/6 × 400 m; 4 × 600 m; 3 × 800 m; 4 × 500 m. |',
 '| R | 4/6 × 15 s; 6 × 20 s, con recuperación de 75 s. |','',
 'Las entradas dobles v2 añaden 2 × 4 min T y 3 × 2 min V cuando ya procede repartir calidad. No constan 10 × 400, 15 × 200 ni series de 1 km en este catálogo activo. El 5 × 400 existente usa recuperación de 90 segundos; no representa una variante 400 m + 200 m de recuperación. El editor admite recuperaciones por distancia, pero estas recetas automáticas solo generan recuperaciones temporales. El campo `source_sessions` referencia sesiones aportadas; no equivale a importar todas sus estructuras al selector. La lectura de este caso no permite afirmar que el banco completo esté conectado.','',
 '## Por qué no avanzó por más formatos','',
 '1. El motor exige dos respuestas toleradas de la misma familia, escalón y referencia comparable (ancla dentro del 3 %). Los controles ficticios del ensayo anterior cambian la referencia cada cinco semanas aproximadamente; se recalibran ritmos y se reinicia la consolidación. Esa cadencia fue una entrada de la simulación, no un test pautado automáticamente.',
 '2. El crecimiento de minutos fáciles, la introducción de otra familia y el aumento de frecuencia consumen el permiso para progresar una demanda. En varias semanas la dosis de intervalos queda retenida aunque el resultado sea favorable.',
 '3. Los 10 min de calentamiento y al menos 6 de cierre, las recuperaciones íntegras y los mínimos por salida dejan poco margen para escalones mayores dentro del presupuesto de carrera. Disponer de cuatro días de 60–75 min para la preparación conjunta no acredita capacidad para correr todo ese tiempo.',
 '4. En la semana 19 existen rechazos `does_not_fit` para T, V y S. En la 20 sí se redistribuyen tres minutos y se alcanza T1 (2 × 6 min). En la 24 aparece S0 otra vez como introducción tras recalibrar referencia; en la 25 hay descarga y en la 26 puesta a punto con otra recalibración.',
 '5. La segunda calidad requiere evidencia y un presupuesto mínimo de 120 min de carrera; este caso llega a 85. R también depende de frecuencia, minutos y separación respecto a piernas/calidad, por lo que no aparece. Estos son parámetros operativos actuales; no se presentan aquí como límites universales de la ciencia.','',
 '## Revisión recomendada, pendiente de autorización','',
 'Auditar la progresión de formatos y su encaje temporal con referencias que cambian, comprobar qué sesiones aportadas están realmente representadas y justificar las reglas que retienen escalones. La variedad debe responder al estímulo y al momento de preparación; añadir series distintas al azar no resolvería estos bloqueos. Esta tarea solo documenta el hallazgo. Los controles automáticos se verifican en su propio ensayo y no autorizan modificar esas reglas de carrera.','',
 '## Variantes exactas observadas','',
 '\n'.join(f'- `{k}`: {v} salidas.' for k,v in sorted(variants.items())), '']
out=ROOT/'docs/audits/VARIEDAD_CARRERA_2026_10_16.md'
out.write_text('\n'.join(lines),encoding='utf8')
print(json.dumps({'families':dict(families),'variants':dict(variants),'report':str(out)}))
