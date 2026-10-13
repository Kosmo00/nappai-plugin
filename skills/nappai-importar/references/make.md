# Make (antes Integromat) → NappAI

Las cifras entre paréntesis son apariciones en ~80 blueprints públicos. Para la semántica de
cada pieza sirve también la referencia oficial de Make: módulos, filtros, funciones IML y
directivas de error.

## El formato (blueprint)

```json
{"name": "…",
 "flow": [{"id": 1, "module": "app:Accion", "version": 1,
           "parameters": {"__IMTCONN__": 123, …},   // fijo: conexión, hoja, tabla…
           "mapper": {"campo": "{{1.email}}"},        // lo mapeado, con expresiones IML
           "filter": {"name": "…", "conditions": [[{"a": "{{1.x}}", "o": "text:equal", "b": "…"}]]},
           "routes": [{"flow": […]}],                 // sólo en builtin:BasicRouter
           "onerror": [{"module": "builtin:Break", "mapper": {…}}],
           "metadata": {"designer": {"name": "…"}}}],
 "metadata": {"instant": true, "scenario": {…}, "notes": […]}}
```

- **La secuencia es el orden de la lista.** Un router lleva sus rutas dentro y detrás de él no
  sigue nada.
- **`filter` va en el módulo de DESTINO.** Es la condición de la flecha que entra en él.
- **`metadata.instant: true`** indica un disparador instantáneo (webhook). En ese caso, el
  primer módulo «watch» es sondeo.
- **La programación del escenario NO viene en el blueprint.** Pregunta la cadencia.
- **El blueprint exportado puede empezar con BOM** (los guardados en Windows). La aplicación ya
  lo trata.

## Bundles e iteración

- **Cada módulo se ejecuta una vez por bundle.** Los de búsqueda y listado («Search rows»,
  «Watch…») devuelven un bundle por resultado: son **iteradores implícitos**.
- **`builtin:BasicFeeder` (Iterator, 12):** parte un array en bundles. En NappAI es el modo lote
  del componente siguiente; no hace falta un componente aparte.
- **`builtin:BasicAggregator` (7), `util:TextAggregator` (6), `util:FunctionAggregator2`:**
  vuelven a juntar en uno lo que salía del módulo `feeder` (la IR lo nombra). En NappAI:
  `GroupByKeys`, `CombineText`, o un PyCode que recibe la lista entera (modo lote apagado).
- **`builtin:BasicRepeater`:** genera N bundles. En NappAI, un PyCode que devuelve una lista.

## Router, if-else y filtros

- **`builtin:BasicRouter` (32): CADA bundle va por TODAS las rutas cuyo filtro se cumple**, en
  orden, y las rutas no se reúnen nunca. Es un «haz esto Y esto».
  - Si las rutas tienen filtros complementarios (contiene / no contiene), en realidad es un
    if / else: `DataConditionalRouter`.
  - Si una ruta no tiene filtro, se ejecuta SIEMPRE, también cuando otra ruta coincide.
    Pregunta si eso era intencionado.
- **`builtin:BasicIfElse` + `builtin:BasicMerge`:** la primera rama que cumple gana, y las ramas
  se reúnen. Es un `DataConditionalRouter` o `Switch`, pero el merge **no** se reúne si una rama
  va vacía (patrones §3).
- **Operadores de filtro → router:**

  | Make | Router |
  |---|---|
  | `text:equal` / `text:notequal` (también `:ci`) | `equals` / `not equals` |
  | `text:contain` / `text:notcontain` | `contains` / `not contains` |
  | `text:startwith` / `text:endwith` | `starts with` / `ends with` |
  | `exist` / `notexist` | `is not empty` / `is empty` |
  | `boolean:equal` | `boolean validator` |
  | `number:*`, `date:*`, `text:pattern`, varios grupos (O), o `b` con `{{…}}` | **No cabe**: booleano previo en PyCode |

  La IR ya trae, para cada filtro, la configuración o el «NO cabe».

## Funciones IML → Python

Las expresiones IML van entre `{{ }}`, separan los argumentos con `;` y **los arrays empiezan en
1** (`items[1]` es el primero, y `items[]` también es el primero). La IR traduce las referencias
simples (`{{1.email}}` → `{email}`) y marca el resto con «≈ función de Make…».

| IML | Python |
|---|---|
| `{{1.a.b}}` / ``{{1.`Nombre Cliente`}}`` | `d["a"]["b"]` / `d["Nombre Cliente"]` |
| `{{1.items[1].x}}`, `{{1.items[].x}}` | `d["items"][0]["x"]` (¡de 1 a 0!) |
| `if(c; a; b)` / `ifempty(a; b)` / `switch(…)` | `a if c else b` / `a or b` / `dict.get` |
| `formatDate(now; "YYYY-MM-DD"; "Europe/Madrid")` | `datetime.now(ZoneInfo("Europe/Madrid")).strftime("%Y-%m-%d")` |
| `parseDate(t; "DD/MM/YYYY")` | `datetime.strptime(t, "%d/%m/%Y")` |
| `addDays(d; n)` / `addHours` / `addMonths` | `d + timedelta(days=n)` / `hours=n` / `dateutil.relativedelta` |
| `substring(t; 0; 4)` (desde 0) | `t[0:4]` |
| `replace(t; a; b)` / `split(t; ",")` / `join(arr; ", ")` | `t.replace(a, b)` / `t.split(",")` / `", ".join(arr)` |
| `lower` / `upper` / `trim` / `length` | `.lower()` / `.upper()` / `.strip()` / `len()` |
| `contains(t; x)` / `indexOf` | `x in t` / `t.find(x)` |
| `toString(x)` / `parseNumber(t; ",")` | `json.dumps(x)` o `str(x)` / `float(t.replace(".", "").replace(",", "."))` |
| `formatNumber(n; 2; ","; ".")` | `f"{n:,.2f}"` con los separadores cambiados |
| `round` / `ceil` / `floor` / `sum` / `average` | `round` / `math.ceil` / `math.floor` / `sum` / `statistics.mean` |
| `map(arr; "k")` / `first` / `last` / `distinct` | `[x["k"] for x in arr]` / `arr[0]` / `arr[-1]` / `list(dict.fromkeys(arr))` |
| `now` / `timestamp` / `uuid` | `datetime.now(timezone.utc)` / `int(time.time())` / `uuid.uuid4()` |
| `stripHTML` / `md5` / `sha256` / `base64` | BeautifulSoup `.get_text()` / `hashlib` / `base64` |
| `{{AIRTABLE_BASE_ID}}` (mayúsculas sueltas) | Un valor de plantilla sin rellenar: pídeselo al usuario |

## Módulos frecuentes

| Make | NappAI |
|---|---|
| `http:ActionSendData` (71), `…APIKeyAuth` (24), `http:ActionGetFile` | PyCode con `requests`. La clave, en `env`; la conexión `__IMTCONN__`/`auth` no viaja |
| `openai-gpt-3:CreateCompletion` (53) y demás | `OpenAIModel` / `AdvancedAgent`. Si sólo parsea JSON, propón PyCode (patrones §6) |
| `anthropic-claude:*`, `perplexity-ai:*` | `AnthropicModel`, `PerplexityModel` |
| `gateway:CustomWebHook` (28) / `gateway:WebhookRespond` (9) | `Webhook` / `WebhookResponse`. La URL cambia |
| `gateway:CustomMailHook` | Buzón de entrada: `SmtpImap` con una programación |
| `util:SetVariables` (28), `util:SetVariable2` (21), `util:GetVariable2` | Valores que viajan con el dato (patrones §1), o constantes |
| `util:FunctionSleep` (13) | `Wait` |
| `json:ParseJSON` (15) / `json:CreateJSON` | `ParseJSONData`/`JSONtoData` / `DataToJSON` |
| `regexp:*`, `text-parser:*`, `markdown:Compile`, `math:EvaluateExpression` | PyCode |
| `custom-js:execute`, `onesaas:codejavascript` | PyCode (JS → Python, ver la chuleta de n8n.md) |
| `gmail:*`, `google-email:*` | Gmail (`GmailMesageComponent`…), `GmailWebhook` |
| `email:*` | `SmtpImap` |
| `google-sheets:*` | `GoogleSheetReader`/`GoogleSheetWriter`/`GSheetCellComponent`. Ojo: en Make las columnas se mapean por letra o índice (`{{1.\`0\`}}` = columna A) |
| `airtable:*` (54) | `Airtable` |
| `slack:*` | Componentes de Slack si están en la plataforma; si no, PyCode |
| `datastore:*` | Una tabla SQL (libSQL o la base del cliente). Los datos guardados no se migran solos |
| `hubspotcrm:*`, `instantly:*`, `vapi:*`, `contentful:*`… | PyCode con su API |

## Directivas de error

Las `onerror` del blueprint vienen en la IR como «Si fallaba: …» en el paso que falla. La
traducción está en patrones §11.

| Directiva | Qué hacía |
|---|---|
| `builtin:Break` | Reintento con `count` e `interval` en minutos |
| `builtin:Ignore` | Seguir con el resto |
| `builtin:Resume` | Valores de sustitución |
| `builtin:Commit` / `Rollback` | Sin par |

## Conexiones, data stores y programación

- **`__IMTCONN__` / `account`:** la conexión de Make. No viaja: la credencial de NappAI la elige
  o crea el usuario.
- **Los data stores y las variables de equipo no vienen en el blueprint.** Hay que exportarlos
  aparte.
- **Programación:** no viene, así que pregúntala, junto con la zona horaria (el cron va en
  UTC). Un escenario «instant» con webhook no necesita programación.
