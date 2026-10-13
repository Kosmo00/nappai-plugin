# Zapier → NappAI

Zapier no publica un formato de export estable, y no hay exports públicos con los que medir.
Lo que sigue sale de su Workflow API documentada y del formato de «Export Zaps» de las cuentas
de equipo. **Confirma siempre con el usuario** que los pasos y su orden son los que ve en el
editor de Zapier.

## Los dos formatos que llegan

1. **«Export Zaps» de la cuenta** (Team/Enterprise):

   ```json
   {"zaps": [{"title": "…", "nodes": {"10": {"id": 10, "parent_id": null, "type_of": "read",
                                               "selected_api": "GoogleSheetsV2CLIAPI",
                                               "action": "new_spreadsheet_row", "params": {…},
                                               "authentication_id": 44}}}]}
   ```

   - El orden es el **árbol de `parent_id`**, no el de las claves.
   - Varios hijos del mismo padre son **Paths**.
   - `type_of: read` en la raíz es el disparador.
   - `selected_api` es la app: `GmailV2CLIAPI`, `WebHookCLIAPI`, `BranchingAPI`…

2. **Workflow API** (`/v2/zaps`):

   ```json
   {"data": {"title": "…", "steps": [{"action": "<id>" | {…, "app": {"title", "selected_api"}},
                                     "inputs": {…}, "authentication": "…", "alias": "slack_msg"}]}}
   ```

   - Los pasos van en orden, sin árbol.
   - Si `action` es un **id opaco** (`core:9QKq…`), no dice qué app es: la IR lo avisa.
     Pregunta al usuario la app y la acción de cada paso, o pídele el export con
     `expand=steps.action`.

## Referencias entre pasos

- `{{123__campo}}` (paso por id) y `{{alias.campo}}` (Workflow API).
- **El doble guion bajo es anidamiento:** `{{10__data__email}}` es `data.email`.
- La IR traduce las dos formas a `{campo.sub}`, con el paso del que salen.
- **Columnas de Sheets** como `{{10__COL$A}}`: la IR las deja sin traducir. En NappAI el lector
  de Sheets devuelve las columnas por su CABECERA, así que pregunta cuál es.

## Disparadores

- **Casi todos los disparadores de Zapier son de SONDEO**, con un intervalo de 1 a 15 minutos
  según el plan: «New Spreadsheet Row», «New Email Matching Search»…
- En NappAI son el `*Webhook` del servicio si existe (Gmail, Typeform, Trello, Jira, Drive,
  Calendar, Airtable, WhatsApp…). Si no, una **programación + lector** que recuerda lo ya
  procesado (patrones §10).
- **Los instant** («Catch Hook» de Webhooks by Zapier) son `Webhook`. La URL cambia.

## Apps de Zapier (las «built-in»)

| Zapier | NappAI |
|---|---|
| Webhooks by Zapier — Catch Hook / Catch Raw Hook | `Webhook` |
| Webhooks by Zapier — POST / GET / PUT / Custom Request | PyCode con `requests` (la autenticación, en `env`) |
| Schedule by Zapier | Entrada autosuficiente + `nappai_platform(kind="schedules")`, en UTC |
| Filter by Zapier | `DataConditionalRouter` con la salida `true`. Las reglas que no caben → booleano previo (patrones §4) |
| Paths by Zapier | `DataConditionalRouter` (2 caminos) / `Switch` (más). Como en Make, **un elemento puede ir por varios Paths** si cumple varias reglas: confírmalo |
| Formatter by Zapier — Text | PyCode: `split`, `replace`, `title()`, `strip`, extraer email/URL/número con `re`, truncar, quitar HTML con BeautifulSoup |
| Formatter — Numbers | PyCode: aritmética, formato (`f"{n:,.2f}"`), conversión de moneda con su API |
| Formatter — Date / Time | PyCode con `datetime`/`zoneinfo`: formatear, sumar, cambiar de zona |
| Formatter — Utilities | Line-item to text → `", ".join`; Lookup table → `dict.get`; Pick from list → índice; Import CSV → `CSVtoData` |
| Code by Zapier (JavaScript / Python) | PyCode. `input_data` (un dict de strings) → `data`; `output = {…}` / `return {…}` → `return {…}`. El JS, con la chuleta de n8n.md |
| Delay by Zapier | `Wait`. «Delay until» una fecha → no tiene par en un flujo: programa la ejecución |
| Looping by Zapier | Modo lote (patrones §5) |
| Storage by Zapier | Una tabla SQL (libSQL). Los datos guardados no se migran solos |
| Digest by Zapier | Una tabla donde se acumula + un flujo programado que la vacía y envía el resumen |
| Email by Zapier | `SmtpImap` con una cuenta del usuario: Zapier enviaba desde sus servidores |
| Sub-Zap | Un flujo aparte llamado con `RunFlow` (patrones §12) |
| ChatGPT / AI by Zapier | `OpenAIModel` / `AdvancedAgent`. Si sólo parsea, propón PyCode (patrones §6) |

## Lo que pierde la migración

- **Las autenticaciones** (`authentication_id`): se eligen o crean en NappAI.
- **El historial y la deduplicación interna.** Zapier recordaba qué filas o correos ya había
  visto, y eso hay que reconstruirlo (patrones §10).
- **La «Autoreplay»** (reintentos automáticos de Zapier): se reconstruye con reintentos
  explícitos en el PyCode (patrones §11).
