---
name: nappai-importar
description: Migra a NappAI flujos de n8n, Make o Zapier — lee el flujo ya normalizado (bloque <flujo-importado> o nappai_flow(action="import")), decide el equivalente componente a componente, lo explica, lo construye como flujo NUEVO tras la conformidad del usuario y PRUEBA que hace lo mismo que el original. Úsala SIEMPRE que el mensaje traiga un <flujo-importado>, que el usuario pegue un JSON o blueprint de n8n/Make/Zapier, o que pida migrar, pasar o traer un flujo, escenario o Zap de esas herramientas.
---

# Migrar un flujo de n8n, Make o Zapier

Quien trae un flujo de otra herramienta ya lo tiene funcionando allí. El éxito no es «está
montado»: es **«hace lo mismo que hacía, y el usuario sabe qué ha cambiado y por qué»**. Las
reglas de esta skill salen de medir unos 820 flujos reales (plantillas de n8n.io, colecciones
públicas de GitHub y blueprints de Make) y de migrar varios de punta a punta.

## 0. Lo que la aplicación ya ha hecho por ti

El JSON no te llega crudo. El normalizador ya ha hecho esto:

- **Secretos quitados.** Salen como `«redactado»`: cabeceras `Authorization`, claves `api_key`
  o `token`, parámetros `?token=` de las URLs y conexiones de Make.
- **Candidatos ya cruzados con el catálogo vivo.** Si un componente nativo no está en esta
  plataforma, el paso cae a PyCode y lo dice («Ninguno de X está disponible»).
- **Condiciones traducidas.** Cada IF, Switch, Filter o filtro de Make trae una de dos cosas:
  - la configuración exacta del router (`key_name`, `operator`, valor);
  - o «NO cabe en el router» con el motivo.
- **Referencias lejanas detectadas.** «Lee datos de «X», que NO le llega por conexión directa».
- **Expresiones traducidas.** O traducción exacta (`{campo}`), o una pista «≈» de qué hacer.
- **Reintentos y manejo de errores del original anotados en cada paso.** Las ramas «si falla»
  están marcadas.
- **Datos de muestra (`pinData`) del original incluidos.** Son tus casos de prueba.

**Los prompts y el código llegan ENTEROS**, debajo de los parámetros («texto #N, completo»).
Si aun así algún valor viene recortado (`… [+N car.]`), **no lo completes inventando**: pídele
al usuario ese texto. Un prompt de sistema rellenado «a ojo» cambia el comportamiento del
agente sin que nadie lo note.

**No pidas el JSON otra vez ni lo reconstruyas.** Si no hay bloque `<flujo-importado>` (por
ejemplo, por un cliente MCP), llama a `nappai_flow(action="import", source=<el JSON tal cual>)`:
devuelve lo mismo.

## 1. Entiende qué hay que migrar

- **Varios flujos.** Un export de Zapier puede traer varios Zaps, y n8n exporta listas. Cada
  uno es un flujo de NappAI. Pregunta cuáles se migran.
- **Sub-flujos.** Si uno llama a otro (Execute Workflow de n8n, sub-escenario de Make), migra
  primero el llamado y deja el que llama para después. `nappai-plan` lo trata como proyecto.
- **Notas del autor.** Léelas: explican la intención mejor que los nodos («cambia demoCase
  para probar…», «la URL privada es una credencial…»).
- **Pasos desactivados en el original.** Pregunta si se migran.

## 2. Decide el equivalente y explícalo

Cuando el JSON llega pegado en el chat, **la aplicación ya le ha enseñado al usuario la tabla
de lo leído** (pasos y candidatos), justo encima de tu respuesta. No la repitas tal cual. Lo
tuyo es lo que esa tabla no sabe:

- qué componente eliges donde hay varios candidatos, y por qué;
- qué cambia respecto al original (PyCode, ramas, programación, URL del webhook);
- qué le vas a preguntar.

Si lo importaste tú con la acción del MCP, nadie le ha enseñado nada: escribe la tabla entera
(`| Paso en … | Qué hace | En NappAI |`).

**Esto se ESCRIBE en tu texto antes de cualquier pregunta**, incluida la de la carpeta. Lo que
redactas en tu razonamiento no lo ve nadie: medido, el agente pensaba la tabla, la daba por
enseñada y pedía conformidad «del plan» sin haberlo mostrado.

Usa el vocabulario de aquí: nodo, módulo o paso → **componente**; Zap, escenario o workflow →
**flujo**; trigger → **disparador** o **entrada**.

Marca con ⚠️, y explica, todo lo que no es uno a uno. Las decisiones que más se repiten están
en `references/patrones.md`. Léelo antes de proponer:

- **Un LLM que sólo extrae o reformatea datos** («You're a JSON parser») → propón un PyCode
  determinista, que no tiene coste por ejecución. Pregúntalo; es su decisión.
- **Un router de Make con varias rutas.** Allí se ejecutan TODAS las rutas cuyo filtro se
  cumple; aquí es un «si / si no». Confirma qué quería.
- **Un IF que vuelve a juntarse (Merge).** Aquí las ramas no se reúnen si una va vacía. Di cómo
  lo resuelves.
- **Lo que no tiene par:** HubSpot, Google Docs, Pipedrive… → PyCode con su API. Dilo: es
  código a medida que escribes tú.

## 3. Plan y conformidad: `nappai-plan`

Con lo anterior escrito, carga `nappai-plan`: la carpeta (la elige el usuario, siempre), el
nombre y el «sí».

- El nombre dice qué HACE el flujo, no de dónde viene. «Avisar de facturas urgentes de Gmail»,
  no «Importado de n8n».
- Los casos de prueba del plan salen del original: los datos de muestra, los casos que el autor
  dejó preparados y las ramas del IF.

## 4. Construye

1. `nappai_flow(action="create", name=…, folder_id=…)`.
2. Lee los contratos con `nappai_catalog(action="get", items=[{name, operation}…])`. La
   «operación en el origen» (`message.send`, `addRow`) es una pista para elegir `operation`,
   no su valor.
3. Carga `nappai-flow-builder` y declara el flujo entero con `nappai_flow_apply`.
4. Antes de escribir código, consulta la referencia de la plataforma de origen. Ahí están la
   chuleta de JavaScript, IML o Formatter a Python y las tablas nodo a nodo:
   - `references/n8n.md`
   - `references/make.md`
   - `references/zapier.md`

Las seis reglas que más han fallado al construir (detalle en `references/patrones.md`):

1. **La configuración viaja con el dato.** Un paso sólo ve lo que le entra por sus conexiones.
   Si lee de un paso lejano, haz que el dato lo lleve consigo, o ponlo como constante o
   variable de entorno.
2. **Cada rama termina en una salida.** La guarda no deja ejecutar una rama muerta. Los finales
   válidos son:
   - un `ChatOutput` (sólo uno por flujo);
   - un `TextOutput`;
   - un `WebhookResponse`;
   - una acción sobre un servicio con credencial.
3. **Las ramas no se reúnen si una va vacía.** Un `MergeData` detrás de un router no se ejecuta
   cuando una de sus ramas no lleva datos.
4. **El router no compara números ni fechas.** Calcula antes un booleano en un PyCode y usa
   `boolean validator`.
5. **Agente.** La pregunta entra por `arg_input`, el modelo va al puerto `llm` y las
   herramientas a `tools` en `tool_mode`. Cada `$fromAI(…)` del original es un `tool_args`. La
   memoria la lleva el propio agente (`memory_strategy`).
6. **Secretos.** Van en `env`, desde un environment asignado al flujo, nunca en el código.
   Tampoco valen las URLs con el token dentro.

## 5. Lo que va fuera del lienzo

- **Programación.**
  - El flujo arranca con una entrada autosuficiente.
  - Al guardarlo, se crea la programación con `nappai_platform(kind="schedules")`, con el cron
    en **UTC**. Di la conversión: «las 8:00 de Madrid son las 6:00 UTC en verano».
  - Los disparadores de sondeo («watch», «new row», los de Zapier) también son programaciones.
    Si el origen no traía la cadencia (Make no la exporta), pregúntala.
- **Webhook.**
  - La URL CAMBIA: lo que llamaba al original tiene que apuntar a la de NappAI.
  - Mientras tanto, el flujo nuevo no recibe nada.
- **Credenciales.** Las del origen no se importan. Una por turno, con `nappai_credentials`.
- **Entornos.** Los secretos de PyCode van en un environment asignado al flujo
  (`nappai_platform(kind="environments")`).

## 6. Prueba que hace lo mismo

Un flujo migrado no está terminado hasta que se ha comparado con el original. Carga
`nappai-fixer` y:

1. Ejecuta los casos del original:
   - los datos de muestra (`pinData`);
   - los casos que el autor dejó preparados (un «demoCase», un payload de ejemplo en el
     webhook);
   - una entrada por cada rama del IF o router.
2. Compara cada resultado con lo que daba el original. Si difiere, arréglalo o explica por qué
   la diferencia es correcta. Por ejemplo: el orden de la lista cambia porque aquí no hay
   rejoin.
3. Guarda esos casos con el flujo (`nappai_platform(kind="tests")`), para que un cambio futuro
   no rompa la equivalencia sin que nadie se entere.
4. Si un paso necesita un servicio que no se puede llamar en la prueba (sin credencial, o con
   coste), prueba lo que se pueda y dilo: «la consulta a NeetoCal no la he ejecutado: falta la
   clave».

El informe final dice:

- qué quedó igual;
- qué cambió y por qué;
- qué casos se han probado y cuáles no;
- qué tiene que hacer el usuario fuera de NappAI: cambiar la URL del webhook, crear
  credenciales y, cuando el nuevo esté probado, **apagar el flujo viejo** para no procesar dos
  veces lo mismo.
