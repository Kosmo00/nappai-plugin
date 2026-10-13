# Patrones de migración (valen para n8n, Make y Zapier)

Cada patrón sale de un fallo real: medido sobre ~820 flujos públicos o al migrar uno de punta a
punta. El motivo va contado, para que sepas cuándo aplica y cuándo no.

## 1. La configuración viaja con el dato

**El problema.** En n8n cualquier nodo lee `$('Otro nodo').first().json`, y en Make cualquier
módulo lee `{{3.campo}}`. Es habitual que un nodo «Set» del principio guarde la configuración y
que tres pasos después un Code la lea. En NappAI un componente **sólo ve lo que le entra por sus
conexiones**. Si cableas en línea, esos valores llegan vacíos.

La IR lo avisa: «Lee datos de «X», que NO le llega por conexión directa».

**Qué hacer, en este orden:**
1. **Valores fijos** (umbrales, nombres de campo, URLs): constantes en el PyCode que los usa o,
   si son secretos, variables de entorno.
2. **Datos que cambian en cada ejecución.** Que el paso intermedio los devuelva junto con su
   resultado: `return {"config": cfg, "rows": rows}`. El siguiente lee `data["config"]`.
3. **Dos flujos de datos independientes que hay que cruzar.** `MergeData` (`combine by index` o
   `combine by key`) antes del paso que los necesita.

## 2. Cada rama termina en una salida

La guarda determinista **no deja ejecutar** un flujo con una rama cuya salida no va a ningún
sitio. Finales válidos:

- `ChatOutput`: solo **uno** por flujo (un segundo se rechaza);
- `TextOutput`;
- `WebhookResponse`;
- un componente de servicio con credencial (enviar un correo, escribir en una hoja…).

Un `NoOp` de n8n al final de una rama («Inspect local result») no tiene par: esa rama termina en
su propio resumen o en un `TextOutput`.

`ChatOutput` y `TextOutput` esperan **texto** (`Message`). Un PyCode devuelve `Data`, así que
pon un `ParseData` en medio, con plantilla (`{campo}`) o con el campo de texto que prepare el
propio código. `DataToJSONString` produce `str`, no `Message`, y la guarda lo rechaza.

## 3. Las ramas no se reúnen si una va vacía

**El problema.** En n8n es muy común IF → … → Merge (el Merge aparece 202 veces en el corpus).
En NappAI, un componente que recibe una entrada de una rama **parada** (el router mandó todo
por la otra) **no se ejecuta**. Medido: el `MergeData` tras un router con la rama `true` vacía
salió `skipped`, y con él todo lo que venía detrás.

**Qué hacer:**
- **Lo normal:** cada rama hace su trabajo y termina en su propia salida (patrón 2).
- **Si la salida tiene que ser una sola** (un único `ChatOutput`, una única respuesta de
  webhook): calcula las dos ramas en un PyCode («si X, mensaje A; si no, mensaje B») y quita el
  router.
- **Router en modo lote con varios elementos que van a las dos ramas:** ahí ambas llevan datos
  y el merge sí se ejecuta. Pero no cuentes con ello: si un día todos los elementos van por la
  misma rama, se para.

## 4. El router no compara números, fechas ni regex

`DataConditionalRouter` y `Switch` comparan **una** clave con **un valor fijo**, usando uno de
estos operadores:
- `equals`, `not equals`;
- `contains`, `not contains`;
- `starts with`, `ends with`;
- `is empty`, `is not empty`;
- `boolean validator`.

No hay `>`, `<`, fechas ni regex. Tampoco varias condiciones a la vez, ni comparar con otro
campo.

Según el corpus, el 64 % de las condiciones caben tal cual. La IR te da la configuración exacta:
- `key_name`;
- `operator`;
- `compare_value`;
- y si hay que usar la salida `false` porque la condición estaba negada.

**Lo que no cabe:** calcula antes el booleano en el PyCode que ya produce el dato (o en uno
pequeño) y enruta con `boolean validator`:

```python
return {**registro, "mas_de_100": float(registro.get("total") or 0) > 100}
```

Para clasificar texto en categorías («¿es una queja?»), mejor `Laya` o `Jev` que un agente más un
router.

## 5. Elemento a elemento: modo lote

n8n ejecuta cada nodo una vez **por elemento**. Make, una vez por **bundle**. En NappAI:

- Los componentes con **modo lote** (`mapping_mode`, encendido por defecto) procesan elemento a
  elemento si les llega una lista por `mapping_data`. El dato de cada elemento se nombra con
  `{clave}`.
- **Con el modo lote encendido, `mapping_data` es la ÚNICA entrada que se cablea.** Mezclarla con
  otras falla sin avisar.
- **Un Code de n8n en «Run Once for All Items»** (`$input.all()`) es un PyCode con
  `mapping_mode: false` que recibe la lista entera en `data`.
- **«Run Once for Each Item»** (`$json`) es el modo lote, o un bucle dentro del PyCode.
- **`SplitInBatches` / Loop Over Items, el iterador de Make y Looping de Zapier:** casi siempre
  sobran. El modo lote ya itera. Usa `Loop` sólo si hay estado que acumular entre vueltas.
- **Una clave que en algún elemento viene vacía** revienta el mapeo por elemento. Sondea con
  `nappai_probe`.

## 6. Un LLM usado como parser se puede quitar

Patrón muy repetido: un nodo de OpenAI con «You're a JSON parser», que extrae campos de un JSON
o reformatea una lista. Cuesta dinero en cada ejecución, puede inventar y es más lento. Si la
estructura de entrada es conocida, **propón un PyCode determinista**. Es decisión del usuario, así
que pregúntalo.

**Antes de escribirlo, mira la respuesta REAL con `nappai_probe`.** Medido: un parser escrito
«a ciegas» contaba la `end_time` de un hueco como si fuera un hueco libre.

## 7. Webhooks

- **Entrada:** `Webhook`. Su campo `data` es un payload de prueba: rellénalo con el ejemplo del
  original (`pinData`, o el `{{1.args…}}` que se ve en los parámetros) y así puedes ejecutar el
  flujo entero con `nappai_probe`.
- **La forma de lo que entra no es fija.** Medido: con el payload de prueba del campo `data`, el
  `Webhook` entregaba el JSON tal cual. Con el evento simulado de una ejecución, lo entregaba
  envuelto en `{headers, query_params, body}`. El primer PyCode tiene que aceptar las dos formas:
  `payload = d.get("body", d) if isinstance(d, dict) else d`. Sondéalo con `nappai_probe` antes
  de escribirlo.
- **Respuesta** (Respond to Webhook de n8n, `gateway:WebhookRespond` de Make): `WebhookResponse`,
  con el resultado cableado a su `data`. Es un final válido.
- **La URL cambia.** Dile al usuario exactamente qué tiene que repuntar (Typeform, Stripe, su
  web…).

## 8. Chat y agentes

- El **disparador de chat** de n8n responde solo. En NappAI hace falta `ChatInput` → … →
  `ChatOutput`.
- **Agente** (`AdvancedAgent`):
  - la pregunta entra por **`arg_input`**: `input_value` es una plantilla, no un puerto;
  - el modelo va a **`llm`**;
  - las herramientas, a **`tools`**;
  - la respuesta sale por **`response`**;
  - el «System Message» del original va a `system_prompt`, tal cual o mejorado.
- **Herramientas del agente** (`gmailTool`, `postgresTool`, `httpRequestTool`, toolWorkflow…):
  - el componente va en `tool_mode`, con su `component_as_tool` cableado a `tools`;
  - le pones `tool_name` y `tool_description`;
  - **cada `$fromAI("x", …)` del original es un `tool_args`** con su descripción. Sin `tool_args`
    la herramienta corre con valores fijos y falla en silencio.
  - **Si el original fijaba parte de una consulta** y sólo dejaba al agente un trozo (`WHERE
    table_name = '{{ $fromAI("table_name") }}'`): pon la plantilla en la descripción del arg y
    deja que el agente mande la consulta entera.
- **Memoria** (Window Buffer, Postgres Chat Memory…): no es un componente aquí. Va en el propio
  agente: `memory_strategy` = `Trim`, con `strategy_trim_memory_limit` ≈ la ventana del original.

## 9. Secretos

- **Nada de secretos en el código ni en los campos.** Un PyCode los lee con `env.get("X")`, desde
  un environment asignado al flujo (`nappai_platform(kind="environments")`). Sin environment
  asignado, `env` llega vacío.
- **Una URL «privada» con el token dentro** (webhooks de recibo, URLs de ingest) también es un
  secreto, aunque la clave se llame `receiptUrl`. La IR sólo redacta los `?token=`; las demás
  tienes que detectarlas tú, leyendo las notas del autor.
- **Las credenciales del origen no viajan.** Para un componente con credencial, la elige o crea
  el usuario (`nappai_credentials`), una por turno.

## 10a. Un disparador manual que recibe un valor

El «Manual Trigger» de n8n no recibe nada. Pero si el original se probaba cambiando un valor a
mano (un `demoCase` en un Set) y quieres que el usuario lo elija al ejecutar, la entrada es
**`ChatInput`**. Medido: con `TextInput`, lo escrito al ejecutar no llegaba al flujo y todos los
casos salían iguales.

## 10. Programación y disparadores de sondeo

- **No hay componente de cron.** El flujo arranca con algo autosuficiente: `CurrentDate`, un
  `TextInput`, o el propio lector (Sheets Get, SQL Get). La programación va con
  `nappai_platform(kind="schedules", action="create")` en **UTC**, después de guardar.
- **Disparadores de sondeo** («Watch rows» de Make, «New Spreadsheet Row» de Zapier, Google
  Sheets Trigger de n8n): son una programación más un lector. Hay que guardar qué se procesó ya:
  - una columna «procesado» que el flujo marca;
  - o una tabla;
  - o el `volume_directory` de un PyCode.
  Pregunta al usuario cuál prefiere.
- **Webhook de un servicio con `*Webhook` en el catálogo** (`GmailWebhook`, `TelegramWebhook`,
  `TypeFormWebhook`…): mejor que sondear.

## 11. Errores y reintentos

La IR anota, por paso, lo que hacía el original. La traducción:

| Original | En NappAI |
|---|---|
| `retryOnFail` / `maxTries` (n8n), `builtin:Break` (Make) | Un PyCode con reintentos (`for intento in range(n): try … except … time.sleep(espera)`). Dile al usuario que fuera de un PyCode no hay reintento automático. |
| `continueOnFail` / `onError: continueRegularOutput`, `builtin:Ignore` | `try/except` en el PyCode que devuelve un resultado vacío o con `error`, para que el flujo siga. |
| Salida «si falla» (`continueErrorOutput`), ruta de error de Make | Un campo `ok`/`error` en el resultado y un router con `boolean validator` hacia la rama de error. |
| `builtin:Resume` | `try/except` que devuelve los valores de sustitución. |
| `builtin:Commit` / `Rollback` | Sin par: explícalo. |
| Error Trigger (flujo de errores de n8n) | Sin par directo: el historial de ejecuciones ya registra los fallos. Si quería un aviso, propón un flujo programado que lea `nappai_platform(kind="executions")`. |

## 12. Sub-flujos

`Execute Workflow` (n8n), los sub-escenarios de Make y los Sub-Zaps llaman a OTRO flujo:
1. migra primero el llamado;
2. enlázalo con `RunFlow` o `SubFlow`;
3. si el llamado era una herramienta de un agente (toolWorkflow), usa `FlowTool`.

Lo que se pasa entre ellos se define en la entrada del flujo llamado.

## 13. Lo que no se migra (dilo siempre)

- El historial de ejecuciones del original.
- Los datos guardados en el origen: data stores de Make, Storage by Zapier,
  `$getWorkflowStaticData` y Data Tables de n8n. Se pueden **exportar e importar** a una tabla
  (libSQL o la base del cliente), pero es un paso aparte.
- Las variables de instancia (`$vars` de n8n, variables de equipo de Make).
- Las credenciales.

## 14. Prueba de equivalencia

Migrar sin comparar es adivinar. Medido en una plantilla de n8n con 4 casos preparados (healthy,
empty, invalid, duplicates): ejecutar los cuatro en NappAI y compararlos uno a uno con lo que
calculaba el original es lo que demuestra la migración.

- **Fuentes de casos:**
  - el `pinData` (viene en la IR como «Datos de muestra»);
  - los casos que el autor dejó preparados en un Set o Code;
  - una entrada por rama de cada router;
  - un caso vacío.
- **Guarda los casos con el flujo** (`nappai_platform(kind="tests", action="create")`).
- **Si un paso llama a un servicio sin credencial o con coste,** ejecuta hasta ahí, prueba la
  lógica que viene detrás con los datos de muestra y dilo en el informe.
- **NUNCA metas una puerta de pruebas en el código de producción.** Por ejemplo, «si el payload
  trae `test_slots`, no llames a la API». Medido: el agente la dejó en un webhook público, y
  cualquiera que lo llamara podía inventarse la respuesta. Para probar la lógica sin el servicio:
  1. Separa la llamada externa y la lógica en dos PyCode.
  2. Pon un **andamio temporal en el lienzo**: un PyCode que devuelve la respuesta de ejemplo,
     cableado en lugar de la llamada.
  3. Ejecuta los casos.
  4. **Quita el andamio** (`remove` en `nappai_flow_apply`, o `nappai_flow(action="undo")`) y
     comprueba que el lienzo queda como antes.
