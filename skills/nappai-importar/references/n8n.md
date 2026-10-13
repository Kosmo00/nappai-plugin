# n8n → NappAI

Las cifras entre paréntesis son apariciones en ~740 flujos reales: plantillas de n8n.io y la
colección pública más usada de GitHub. Sirven para priorizar.

## El formato

```json
{"name": "…", "nodes": [{"id", "name", "type", "typeVersion", "parameters", "credentials",
  "disabled", "onError", "retryOnFail", "maxTries", "alwaysOutputData", "executeOnce"}],
 "connections": {"<nombre del nodo origen>": {"main": [[{"node": "<destino>", "index": 0}], […]],
                                             "ai_tool": [[…]], "ai_languageModel": [[…]]}},
 "pinData": {"<nodo>": [{"json": {…}}]}, "settings": {"timezone": "Europe/Madrid"}}
```

- **Las conexiones van por NOMBRE de nodo.** La posición en la lista exterior de `main` es la
  salida:
  - IF: 0 = true, 1 = false.
  - Switch: el número de caso.
  - SplitInBatches: 0 = done, 1 = loop.
  - Con `onError: continueErrorOutput`, la última salida es la de error.
- **Los puertos `ai_*` van del sub-nodo HACIA el agente.** El modelo, la memoria y las
  herramientas «cuelgan» del agente.
- **`pinData`** son datos reales que el autor dejó fijados: tus casos de prueba.
- **`settings.timezone`** es la zona de los horarios del Schedule Trigger. Sólo lo traen 24 de
  744; si no está, es la zona de la instancia, así que pregúntala.

## El modelo de datos: items

n8n pasa entre nodos una **lista de items** `[{json: {…}, binary: {…}}]`, y cada nodo se ejecuta
una vez por item salvo que diga lo contrario.

| n8n | NappAI |
|---|---|
| Lista de items | Lista de `Data` |
| Un nodo normal (por item) | Componente en modo lote, con la lista por `mapping_data` y `{clave}` en sus campos |
| Code «Run Once for All Items» (719) | PyCode con `mapping_mode: false`: `data` es la lista entera |
| Code «Run Once for Each Item» (97) | PyCode en modo lote, o un bucle dentro del PyCode |
| `item.binary` | Entrada Binary del componente, o `File` |
| `executeOnce: true` | El componente se ejecuta con el primer item: modo lote apagado y `data[0]` |
| `alwaysOutputData: true` | El paso devuelve algo aunque no haya items. En PyCode, `return {…}` aunque la lista venga vacía |

**El PyCode recibe `Data` u objetos simples según de dónde venga.** Normaliza siempre al
principio:

```python
def _d(x):
    if isinstance(x, list):
        return [_d(i) for i in x]
    return getattr(x, "data", x)

filas = _d(data)
filas = filas if isinstance(filas, list) else [filas]
```

## Code de JavaScript → PyCode

Hay 839 nodos Code y casi todos son JavaScript. Pórtalo a Python, no lo transcribas.

| JavaScript (n8n) | Python (PyCode) |
|---|---|
| `$input.all()` / `items` | `data` (la lista, ya normalizada con `_d`) |
| `$input.first().json` / `$json` | `filas[0]` / el elemento en curso |
| `$('Nodo').first().json.x` | **No existe**: el dato tiene que llegarte por la entrada (patrones §1) |
| `return [{json: {...}}]` | `return {...}`, o `return [{...}, …]` para varios |
| `return []` | `return []`, que para la rama: cuidado con lo que viene detrás |
| `items.map(i => ({json: {...}}))` | `[{...} for i in filas]` |
| `arr.filter(x => …)` / `.find` / `.some` / `.every` | comprensión / `next((…), None)` / `any()` / `all()` |
| `arr.reduce((a, x) => a + x.n, 0)` | `sum(x["n"] for x in arr)` |
| `new Set(arr)` / `[...new Set(arr)]` | `set(arr)` / `list(dict.fromkeys(arr))` (conserva el orden) |
| `Object.keys(o)` / `Object.entries(o)` | `list(o)` / `o.items()` |
| `x?.a?.b ?? 'def'` | `(x or {}).get("a", {}).get("b", "def")` |
| `JSON.stringify(o)` / `JSON.parse(s)` | `json.dumps(o, ensure_ascii=False)` / `json.loads(s)` |
| `Number(x)` / `parseInt` / `String(x)` | `float(x)` / `int(x)` / `str(x)` |
| `` `Hola ${x}` `` | `f"Hola {x}"` |
| `s.trim()` / `.toLowerCase()` / `.includes()` / `.split()` | `.strip()` / `.lower()` / `in` / `.split()` |
| `throw new Error('…')` | `raise ValueError("…")` |
| `DateTime.now()` / `$now` (Luxon) | `datetime.now(ZoneInfo("Europe/Madrid"))` |
| `$today.minus({days: 7})` / `.plus` | `date.today() - timedelta(days=7)` |
| `dt.toISO()` / `.toFormat('yyyy-MM-dd')` | `.isoformat()` / `.strftime("%Y-%m-%d")` |
| `$workflow.id`, `$execution.id`, `$runIndex` | No hay equivalente: quítalo, o usa `uuid.uuid4()` si sólo era un id único |
| `$env.X` / `$vars.X` | `env.get("X")` (environment asignado al flujo) |
| `$getWorkflowStaticData('global')` | Estado entre ejecuciones: `volume_directory` del PyCode (un fichero) o una tabla |
| `await this.helpers.httpRequest({...})` | `requests.request(...)` (pon `requests` en `packages`) |

Los Code en Python de n8n (16) se pasan casi tal cual: `_input.all()` es `data`, e `item.json`
es el elemento.

## Nodo a nodo

### Disparadores

| n8n | NappAI |
|---|---|
| Manual Trigger (223) | `ChatInput` o `TextInput` |
| Schedule Trigger (183), Cron, Interval | Entrada autosuficiente + `nappai_platform(kind="schedules")`, en UTC. Formato de `rule.interval[]`: `field` = days (88), hours (30), minutes (25), weeks (22), cronExpression (15); hora en `triggerAtHour`/`triggerAtMinute`, zona en `settings.timezone` |
| Webhook (145) | `Webhook`. `responseMode`: `responseNode` (90) → un `WebhookResponse` al final; `onReceived` (48) → responde al instante, sin `WebhookResponse`; `lastNode` → el último paso es la respuesta |
| Chat Trigger (107) | `ChatInput` + `ChatOutput` al final (en n8n el chat responde solo) |
| Form Trigger (77) | `Webhook`: el formulario lo pone el usuario (Typeform, Google Forms, su web). Si era Google Forms o Typeform, sus `*Webhook` |
| `<Servicio>Trigger` (Gmail, Telegram, Drive, WhatsApp…) | Su `*Webhook` si existe; si no, programación + lector |
| Google Sheets Trigger (26) | Programación + `GoogleSheetReader`, y marcar lo procesado (patrones §10) |
| Execute Workflow Trigger (58) | Entrada del sub-flujo: `TextInput`/`ChatInput`. Se llama con `RunFlow` o `SubFlow` |
| Error Trigger (17) | Sin par (patrones §11) |

### Datos y control

| n8n | NappAI |
|---|---|
| Set / Edit Fields (1071) | Valores fijos → constantes del PyCode que los usa. Añadir o renombrar campos → `CreateData`/`UpdateData`, o un PyCode de una línea. Modo `raw` (60) = un objeto JSON → PyCode. `include: none` = sólo los campos nuevos |
| IF (498), Filter (87), Switch (140) | `DataConditionalRouter` / `Switch`, con la configuración que trae la IR. Lo que «NO cabe» → booleano previo (patrones §4). Filter sólo deja pasar: router con la salida `true` |
| Merge (202) | `combineByPosition`/`mergeByPosition` (85) → `MergeData` «combine by index». `append` (57) → «append». `combineByFields`/`enrich*` → «combine by key» (inner/outer). `chooseBranch` (21) → es un rejoin de ramas, ver patrones §3. `multiplex`/`combineAll` → PyCode (producto cartesiano) |
| Split Out (172) | Modo lote del siguiente componente, o `FlattenByKey` |
| Aggregate (93), Summarize | `GroupByKeys`, o un PyCode |
| Split In Batches / Loop Over Items (132) | Casi siempre sobra: modo lote. `Loop`/`LoopEnd` sólo con estado entre vueltas. Un «batch + Wait» para no saturar una API → un PyCode con `time.sleep` entre llamadas |
| Wait (210) | `Wait`. Si espera un webhook de reanudación («resume on webhook»), no tiene par: explícalo |
| Limit, Sort, Remove Duplicates | `SliceData` / PyCode |
| Date & Time | PyCode con `datetime`, o `CurrentDate` |
| HTML (61) / Markdown / XML | `WebScraper` o un PyCode con BeautifulSoup / `markdown` / `xml_to_data` |
| Extract From File (83) / Convert To File (38) | `File`, `PdfExtractor`, `CSVtoData` / `CsvWriter`, `XlsWriter`, `PdfWriter` |
| No Op (130) | Se quita. Si cerraba una rama, esa rama termina en su propia salida (patrones §2) |
| Stop and Error (26) | PyCode que hace `raise` |
| Execute Workflow (43) | `RunFlow`/`SubFlow`, migrando antes el llamado |
| Respond to Webhook (148) | `WebhookResponse` |

### HTTP Request (1298: el nodo más usado)

- **Sin componente nativo para ese servicio:** PyCode con `requests`, **nunca** `APIRequest`.
- **Si la URL es de un servicio con componente** (Notion, Sheets, Slack, OpenAI…): usa el
  componente. Pista: `authentication: predefinedCredentialType` con `nodeCredentialType`
  (`openAiApi`, `wordpressApi`, `qdrantApi`…) dice qué servicio era.
- **Autenticación:**

  | n8n | En el PyCode |
  |---|---|
  | `httpHeaderAuth` (339) | `headers={"Authorization": env["…"]}` o la cabecera que fuera |
  | `httpQueryAuth` (20) | `params={"api_key": env["…"]}` |
  | `httpBearerAuth` (22) | `headers={"Authorization": f"Bearer {env['…']}"}` |
  | `httpBasicAuth` (10) | `auth=(env["…_USER"], env["…_PASS"])` |
  | `httpCustomAuth` (32) | Lo que diga su JSON |

  El valor del secreto lo pide el agente al usuario y va al environment.
- **Paginación** (`options.pagination`, en 12 flujos): un bucle en el PyCode.
- **`jsonBody` con expresiones `={{ … }}`:** constrúyelo como `dict` en Python.

### IA (paquete `@n8n/n8n-nodes-langchain`)

| n8n | NappAI |
|---|---|
| AI Agent (390) | `AdvancedAgent` (patrones §8). `options.systemMessage` → `system_prompt`. `promptType: define` + `text` → lo que entra por `arg_input` |
| OpenAI / Anthropic / Gemini / Groq / Ollama / OpenRouter Chat Model | `OpenAIModel`, `AnthropicModel`, `GoogleGenerativeAIModel`, `GroqModel`, `OllamaModel`, `OpenRouter` → puerto `llm`. El modelo exacto, en `model.value` |
| OpenAI (nodo de acción, 271) | `OpenAIModel` o `AdvancedAgent` según la operación (texto, imagen → `DallEImageGenerator`, audio → `OpenAISTT`/`OpenAITTS`) |
| Basic LLM Chain (134) | `AdvancedAgent` sin tools, o modelo + `Prompt` |
| Window Buffer / Postgres / Redis Memory | Dentro del agente: `memory_strategy` (patrones §8) |
| Structured Output Parser (157) | `StructuredOutputComponent`, o `structured_output_schema` del agente |
| Text Classifier, Sentiment Analysis | `Laya` / `Jev` |
| Information Extractor | `ExtractData` / `TrustcallExtractor` |
| Summarization Chain | `Summarizer` |
| Vector Store (Qdrant, Pinecone, Supabase, PGVector, In-Memory) | `Qdrant`, `Pinecone`, `SupabaseVectorStore`, `pgvector`, `FAISS` |
| Embeddings | `OpenAIEmbeddings`, `GoogleGenerativeAIEmbeddings`, `MistalAIEmbeddings`, `OllamaEmbeddings`… |
| Default Data Loader + Text Splitter | `File` + `RecursiveCharacterTextSplitter` |
| `*Tool` (gmailTool, postgresTool, googleSheetsTool, httpRequestTool…) | El componente del servicio en `tool_mode`, con `tool_args` (patrones §8) |
| Call n8n Workflow Tool (90) | `FlowTool` |
| MCP Client Tool | `MCPTools` |
| Think Tool | `ThinkToolComponent` |
| Calculator / Wikipedia / SerpAPI | `CalculatorTool` / `WikipediaAPI` / `SerpAPI` |

## Expresiones

La IR traduce lo traducible y da pistas («≈») para el resto:

| n8n | NappAI |
|---|---|
| `{{ $json.campo }}` | `{campo}` (campo mapeado en modo lote, plantilla de ParseData, prompt) |
| `{{ $json["con espacio"] }}` | `{con espacio}` |
| `{{ $('Nodo').item.json.x }}` | `{x}`, si ese dato te llega por la entrada (patrones §1) |
| `{{ $json.lista[0].x }}` | `{lista.0.x}` según la IR, pero compruébalo con `nappai_probe` |
| `{{ $fromAI("x", "desc") }}` | Un `tool_args` `x` con esa descripción |
| `{{ $now }}`, `{{ $today… }}` | `CurrentDate` o un PyCode |
| `{{ $env.X }}` | `env.get("X")` en un PyCode |
| Cualquier otra con métodos JS (`.toUpperCase()`, `.split()`, ternarios…) | Un campo calculado antes en un PyCode |

## Errores y reintentos del nodo

`retryOnFail`/`maxTries`/`waitBetweenTries`, `onError` (`continueRegularOutput`,
`continueErrorOutput`) y `continueOnFail` vienen anotados en cada paso de la IR. La traducción
está en patrones §11.
