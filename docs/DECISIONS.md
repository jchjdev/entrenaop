# Registro de decisiones vigentes

Este archivo es el índice de las decisiones de producto, dominio y arquitectura
que deben sobrevivir a una conversación concreta. No sustituye a los documentos
especializados: indica qué está acordado, su estado real y dónde se explica.

## Cómo utilizarlo

- **Acordada:** Javier y el equipo han confirmado el criterio, aunque todavía
  no exista implementación.
- **Implementada:** el criterio está reflejado en código o migraciones y se ha
  verificado.
- **Pendiente:** se ha identificado la pregunta, pero todavía no existe una
  decisión que pueda convertirse en regla.
- **Sustituida:** dejó de estar vigente; se conserva la referencia a la decisión
  que la reemplaza para no recuperar accidentalmente el criterio antiguo.

Cuando una conversación confirme o corrija una decisión relevante, esa misma
tarea actualizará este índice y el documento especializado correspondiente
antes de considerarla cerrada. Una omisión en el código no anula una decisión
acordada que todavía esté pendiente de implementación.

## Decisiones

| ID | Fecha | Área | Estado | Decisión | Documento de detalle |
| --- | --- | --- | --- | --- | --- |
| DOC-001 | 2026-09-25 | Colaboración | Implementada | Las decisiones relevantes no permanecerán únicamente en un chat: se registran aquí y se desarrollan en el documento de dominio correspondiente. | `AGENTS.md` |
| RUN-001 | 2026-09-25 | Carrera | Acordada | La batería prevista de evaluación de carrera está formada por VAM, 2.000 m y Cooper. No implica que todos los usuarios deban realizar las tres pruebas. | `docs/ALGORITMO_CARRERA_V1.md` |
| RUN-002 | 2026-09-25 | Carrera | Pendiente | Falta elegir y validar el protocolo concreto con el que EntrenaOP medirá la VAM y las reglas que decidirán entre VAM y Cooper. No se inferirá un protocolo por el nombre «VAM». | `docs/ALGORITMO_CARRERA_V1.md` |
| RUN-003 | 2026-09-25 | Carrera | Implementada | El control específico de 2.000 m registra intentos fechados, RPE y datos opcionales; todavía no recalcula automáticamente una semana. | `docs/ROADMAP.md` |
| PLAN-001 | 2026-09-24 | Planificación | Acordada | Fuerza y carrera aportarán propuestas especializadas, pero una única coordinación semanal resolverá disponibilidad, carga y preparaciones simultáneas. | `docs/ARCHITECTURE.md` |

## Regla para nuevas decisiones

Una entrada debe ser concreta y comprobable. Si todavía faltan datos, se
registra la pregunta como pendiente en lugar de completar huecos con una
suposición. Los detalles, fórmulas, fuentes y límites pertenecen al documento de
dominio enlazado; este índice debe seguir siendo breve.
