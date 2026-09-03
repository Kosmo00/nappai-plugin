# Configuración: campos, `operation`, código y datos reales

La regla que gobierna todo lo demás: **nunca escribas un valor que no hayas comprobado**.

## Cómo escribes: declarando, y todo de una vez

`nappai_flow_apply` no ejecuta operaciones: le declaras los nodos que quieres configurar y él
escribe cada cosa en el orden en que se queda. **Con `mode="merge"` siempre**, y con los ids
REALES del lienzo:

```
nappai_flow_apply(mode="merge", flow={"nodes": [
  {"id": "GmailMesageComponent-1", "fields": {"Operation": "Send Message", "labels": "INBOX"},
                                   "tool_args": {"recipient": "el destinatario, como lo diga el usuario"}},
  {"id": "PyCode-2", "code": "…"}
]})
```

Tres cosas que cambian cómo trabajas:

- **Varios nodos y varios campos en UNA llamada.** No hagas una llamada por campo: declara todo
  lo que sepas de golpe. Los campos que decidan la FORMA del nodo (`Operation`, `Resource`,
  `mapping_mode`) los escribe antes que el resto, así que no tienes que ordenarlos tú.
- **`mode="merge"` para configurar.** `replace` borra lo que no declares, y aquí estás
  declarando dos nodos de quince: úsalo sólo cuando declares el flujo ENTERO (ver el SKILL). Los
  prompts, aunque quepan en el mismo DTO, se redactan al final y con el flujo ya cableado — sus
  reglas están en `prompts.md`.
- **Lee `operaciones` en la respuesta.** Un `ok: false` con `no_aplicado` significa que la
  reconciliación DESHIZO tu escritura: el valor NO se quedó. Sólo un `ok: true` te autoriza a
  seguir construyendo encima; cualquier otra cosa y estarías trabajando sobre una premisa falsa.
  Tus llamadas cierran con la pasada determinista de reparación (`reparacion`): si repara algo
  que tú acabas de escribir, mírala — no la ignores.

## Lee lo que hay puesto de verdad

`nappai_flow_inspect(scope="component", component_id="…")` es la única forma de ver el valor
real de un campo, las `options` válidas de un desplegable y qué handles ya están conectados.

Esto importa más de lo que parece: **un valor fuera de las `options` de un desplegable no da
error**. El componente compara contra el literal, la condición no se cumple nunca, y el flujo
«va bien» sin hacer nada. Si diagnosticas una mala configuración sin `scope="component"`, estás
adivinando.

`nappai_catalog(action="get")` te da el contrato del TIPO, con los defaults del catálogo. No te
dice qué tiene puesto ESE nodo. No las confundas. Con `names=[...]` te da el de hasta 15 tipos
de golpe, que es lo que quieres antes de configurar un flujo entero.

## La `operation` es la acción

En Gmail, Sheets, libSQL y compañía, el campo `operation` decide **qué hace** el componente.
Configurarlo es lo primero, porque los demás campos disponibles dependen de él.

```
nappai_flow_apply(mode="merge", flow={"nodes": [
  {"id": "Gmail-1", "fields": {"operation": "send_email"}}
]})
```

## Antes de escribir código o un `{clave}`, sondea

Si vas a escribir `data.get("x")` en un PyCode, o `{x}` en un campo mapeado, tienes que saber
qué claves llegan de verdad. Las dos cosas leen el MISMO dict.

```
nappai_probe(component_id="PyCode-1")
```

La misma puerta ejecuta el flujo ENTERO con `mode="run"` (lo usas más abajo para validar SQL por
trozos). Con `component_id` estás midiendo UN nodo; `run` no lo lleva.

Sin `mode`, va en `auto`: te da primero la forma **observada**, que es gratis. Si no consta una
ejecución previa de ese tramo, escala al sondeo, que ejecuta el flujo solo hasta ese componente — y eso
pide permiso: te devolverá la petición con `authorized=false`. **Trasládala al usuario y espera
su sí antes de repetir con `authorized=true`.** No te lo concedas tú.

Un `{clave}` que no existe no se queda como literal: acaba en `None` o en la cadena `"None"`,
sin error. Es el fallo silencioso más caro del producto. Y las rutas marcadas `en_lista` no
sirven como `{clave}`: hay que aplanarlas antes.

El catálogo declara tipos (`Data`, `Message`), nunca claves — y hay componentes cuya salida es
impredecible por diseño: un PyCode devuelve lo que le escribieron y una API externa lo que le
dé el proveedor. Por eso el sondeo no es opcional.

## El agente opina; el conjunto y los números los pone el código

Cuando un flujo lleva agente, hay que repartir el trabajo antes de escribirlo. El reparto no es de
gusto: hay decisiones que un modelo no puede sostener, y ninguna se arregla con un prompt mejor.

**La pregunta que decide, y vale para cualquier campo de cualquier flujo:**

> si el modelo se equivoca en esto, ¿falla algo de forma RUIDOSA?

Si sí —revienta, da error, alguien lo ve—, déjaselo. Si no —sale un número plausible, una lista más
corta, una etiqueta distinta, y la traza sigue verde—, eso no puede ser suyo. Todos los fallos de
esta familia comparten lo mismo: **el flujo termina en `success`**.

Tres cosas que nunca son del agente:

1. **El conjunto.** Si la lista sale de una consulta, el agente puede enriquecer cada elemento pero
   no decidir cuáles hay. Itera en el `PyCode` sobre las filas de SQL, **nunca sobre la respuesta
   del agente**: busca su criterio por una clave (NIF, código, id) y, si no se pronunció sobre un
   elemento, resuélvelo por regla y márcalo (`"revisado_por_agente": false`). Así el agente sólo
   puede AÑADIR criterio, nunca encoger el conjunto.
2. **Los números.** Totales, recuentos, sumas, porcentajes y diferencias se calculan con `GROUP BY`
   —o en `PyCode` si el dato no está en la base— y el agente los copia. Un modelo al que se le pide
   sumar da cifras distintas en ejecuciones consecutivas, y con la fórmula escrita en el prompt
   también falla. Si el agente devuelve un importe, contrástalo con el de la base, registra la
   discrepancia y **quédate con el de la base**.
3. **Los umbrales.** El límite es política de empresa: vive en el environment, se aplica en código
   y se evalúa **sobre el dato, no sobre la etiqueta que eligió el agente**. Si el umbral mira si
   el agente dijo «abonar», basta con que diga «resolver» para saltárselo con el dinero intacto.
   Mira el importe que consta en la base y decide con él, sea cual sea la acción propuesta.

Y una cuarta, que es la misma idea aplicada a las acciones: **una acción que necesita un referente
no se ejecuta sin él**. Conciliar sin candidato, cerrar un ticket sin haber preguntado, imputar a
una cuenta que no existe. Si el agente lo propone, degrádalo a «investigar» y déjalo dicho.

**Cuando el número no está en ninguna base**, el reparto es otro pero la frontera es la misma:
*extraer* es del modelo, *calcular* es del código. Que lea la factura o el correo y saque base,
cuota y total; que el `PyCode` sume, prorratee y compare. Y entre medias, la comprobación: casi
siempre hay una identidad que tiene que cumplirse —base + cuota = total, suma de líneas = total,
debe = haber— y esa validación va en el código, con excepción si no cuadra. Cuando no hay NADA
contra lo que verificar (una estimación, una previsión), no lo hagas seguro a la fuerza: que ese
número vaya a la cola de firma o al informe con su origen al lado, pero no que actúe solo.

**Dinero en `Decimal`, no en `float`.** En un adaptador que mueve importes,
`from decimal import Decimal` y `quantize(Decimal("0.01"))`. Los céntimos que aparecen de la nada
son de la misma familia de error silencioso que todo lo anterior.

**Esto no es «usar menos agente».** El agente conserva lo que sabe hacer: graduar un tono, valorar
si algo es creíble, clasificar, priorizar, redactar. Se le quita contar y decidir quién está en la
lista, que es justo lo que no aporta. Y el andamiaje **no hace falta** cuando una persona lee la
salida antes de que actúe —un resumen, un borrador— : aparece exactamente cuando quitas al humano
del medio.

## Hacer dinámico un campo: quién decide el valor

Antes de tocar nada, contesta esto: **¿quién decide el valor, el flujo o el agente?** De ahí
salen dos vías que son **excluyentes** — un nodo usado como herramienta no admite modo lote, y
uno en modo lote no tiene puertos de entrada.

**Lo decide el flujo** → el dato viene de arriba. Cablea la entrada… salvo que sea un campo de
**identidad o destino** (`subject`, `recipient`, `to`, `cc`, `table_name`, `spreadsheet_id`,
`channel`…): ésos **no se cablean nunca** —la arista mete el payload entero donde iba una
dirección— y su única vía dinámica es la plantilla, que son cuatro pasos:

```
1. fields: {"mapping_mode": "true"}
2. la arista va a `mapping_data` (con el lote encendido es la ÚNICA entrada válida)
3. si el origen emite Message y mapping_data pide Data → PyCode en medio que
   devuelva [{"clave": valor, ...}] con una clave por campo a poblar
4. fields: {"subject": "{clave}"}  ← la llave envuelve el valor COMPLETO
```

Ojo con el orden si el flujo **ya funcionaba**: hay que quitar antes la arista que alimentaba
el campo antiguo, porque con el lote encendido ese puerto desaparece y la arista queda contra
un handle que no se dibuja.

**Lo decide el agente** (si actuar, cuándo y con qué valores) → el componente cuelga del puerto
`tools` del agente, y entonces **cada campo dinámico hay que declararlo**:

```
nappai_flow_apply(mode="merge", flow={"nodes": [
  {"id": "Gmail-1", "tool_args": {
    "subject": "asunto del correo, una linea, sin la palabra Urgente"
  }}
]})
```

Sin esa declaración la herramienta tiene **cero argumentos**: el agente la llama, el componente
se ejecuta con sus valores estáticos y falla por un campo vacío sin que nada diga por qué. La
descripción no es decorativa — es lo único que el agente lee para decidir qué escribir ahí.

El modo lote hace **dos trabajos** con un solo interruptor: fan-out sobre una lista, y plantilla
para poblar varios campos desde un mismo payload. El segundo es legítimo con un solo elemento.
Si el `diagnostico`/`reparacion` de la guarda te dice «apaga el lote» y tus campos llevan `{clave}`, no lo apagues: mueve
la entrada a `mapping_data`.

## Si tu código lee `env`, el flujo necesita un environment ASIGNADO

Dentro de un PyCode/JsCode, `env` es el dict con las variables del environment del flujo. Un
flujo **sin environment asignado recibe `env` vacío**: `env.get('X')` devuelve `None` y
`env['X']` revienta con un `KeyError` que no menciona los environments. El diagnóstico acaba
apuntando a tu código cuando el problema es una asignación que falta.

Y esa asignación **no es un nodo**: no sale en `nappai_flow_inspect` ni en ningún dibujo del
grafo, así que revisando el lienzo entero no se ve que falte. Sale en el informe de la guarda (`reparacion` de `nappai_flow_apply`), como
aviso.

Que el environment EXISTA en la cuenta no basta — hay que atarlo a ESE flujo:

```
nappai_platform(kind="environments")                      # coge el id (los valores van tapados)
nappai_platform(kind="flows", action="update",
                flow_id="…", environment_id="…")          # pide permiso: authorized=false primero
```

El flujo tiene que estar guardado (sin id no hay nada que asignar). Escribe el código
defensivo de todas formas: si la variable no está, falla con un mensaje que diga QUÉ variable
falta y que el flujo necesita environment — vale más que un `None` que se propaga en silencio.

## Pregúntale al servicio, no al usuario

Cuando te falte un nombre de tabla, de columna, de hoja, de canal o de etiqueta, **consúltalo**
en vez de preguntar:

```
nappai_read_service(
  component_id="Postgres-1",
  code="import psycopg2\n...\nreturn tablas",
  looking_for="las tablas de la base de candidatos"
)
```

Ejecuta Python de solo lectura en un contenedor aislado, con la credencial del componente en el
dict `env`. Las dependencias se deducen de tus `import`, así que `packages` solo sirve para
fijar versiones. La condición de solo lectura se **verifica**: el código que escribe se rechaza
antes de descifrar la credencial.

Pide permiso **por sesión y por servicio** — autorizar Postgres no autoriza Gmail. Y si la
consulta no da el dato, la propia tool habla con el usuario.

Los fallos vienen clasificados, y cada clase se trata distinto:

- **credencial** — el servicio rechazó la clave o no se le alcanza. La tool emite el listado de
  credenciales del usuario. No reescribas el SQL: la consulta estaba bien.
- **contenido** — la tabla o la columna no existe, o el resultado vino vacío. Un `[]` es una
  respuesta VÁLIDA («he mirado y no hay»), no un error. No pruebes variantes del nombre a
  ciegas: la tool ya le está preguntando al usuario cómo seguir.
- **código** — `NameError`, `SyntaxError`, `KeyError`. Este sí es tuyo: corrígelo y reintenta.

Cuando el usuario te dé un dato que sí conocías que faltaba y no está en el servicio,
pregúntaselo con `AskUserQuestion` y opciones concretas — agrupa hasta 4 en una sola llamada
en vez de encadenar turnos.

## SQL: los nombres de columna NO te dicen el tipo

Cuando configures una `Custom Query`, saber que existe `candidate_experiences.technologies` no es
saber configurarla. **Descubre los TIPOS antes de escribir la consulta**, con una consulta de
solo lectura al catálogo del propio motor:

```
nappai_flow_apply(mode="merge", flow={"nodes": [
  {"id": "Postgres-1", "fields": {
    "Operation": "Custom Query",
    "custom_query": "SELECT table_name, column_name, data_type, udt_name FROM information_schema.columns WHERE table_schema='X' AND (data_type='ARRAY' OR udt_name IN ('json','jsonb'))"
  }}
]})
nappai_probe(mode="run")
```

Es de solo lectura, así que pasa la guarda de escritura. Vía `nappai_read_service` también sale,
pero necesita runner y permiso por servicio; el `information_schema` no necesita ninguno de los
dos. Los componentes SQL además ya traen `get_table_columns_with_types`, que es lo que alimenta
`describe_table` del asistente de código: ahí el `data_type` de un `text[]` sale como `ARRAY`.

**Por qué es obligatorio y no una buena práctica:** en Postgres, `COALESCE(col, 'sin datos')`
resuelve el tipo del literal por la PRIMERA rama. Si `col` es `text[]`, el literal se fuerza a
array y la consulta —que parsea y planifica sin queja— muere al EJECUTARSE:

```
malformed array literal: "sin datos"
DETAIL: Array value must start with "{" or dimension information.
```

Columnas que suenan a texto y casi nunca lo son: `technologies`, `achievements`, `languages`,
`tags`, `skills`, `emails`. La regla, independiente del motor:

- Arma texto con `concat_ws(', ', a, b, c)` o `format('%s', col)` en vez de `||`: castean solas y
  no propagan NULL, así que matan de paso el clásico «una columna NULL deja la fila entera en
  blanco». En SQL Server, `CONCAT`.
- Si usas `||`, castea explícito: arrays con
  `COALESCE(NULLIF(array_to_string(col, ', '), ''), 'sin datos')` —el `NULLIF` porque `{}` no es
  NULL—, `jsonb` con `jsonb_array_elements_text`, y el resto con `COALESCE(col::text, …)`.
- **Valida por trozos.** Cada CTE sola con `LIMIT 5` y su `nappai_probe(mode="run")` antes de
  encadenarlas. Una
  consulta de 100 líneas ejecutada una sola vez esconde todos sus fallos detrás de un error.

### Un `%` literal rompe la consulta antes de llegar al motor

En MySQL el driver interpola los parámetros con `%s`, así que **cualquier `%` literal dentro de
`custom_query` se toma por un marcador** y la consulta muere sin llegar a la base:

```
Error executing custom query: not enough arguments for format string
```

El caso de siempre es `LIKE 'ag%'`. Se arregla **duplicándolo** —`LIKE 'ag%%'`, comprobado: da el
mismo resultado que el equivalente sin comodín— o esquivándolo con `LEFT(col, n) = '...'`.
Ojo con `format('%s', col)` de más arriba: eso es de Postgres, y en MySQL hay que escribirlo
`'%%s'` o cambiarlo por `CONCAT`.

**Por qué merece regla propia:** el mensaje habla de un «format string», así que suena a fallo de
Python y no de SQL, y se pierde el rato buscando el error en el sitio equivocado. Si lo ves,
busca el `%` antes de tocar nada más.

### Una sentencia por nodo: las demás se ignoran en silencio

`custom_query` **acepta varias sentencias separadas por `;` y ejecuta sólo la PRIMERA**, sin error y
sin aviso. Comprobado con `SELECT 1 AS primera; SELECT 2 AS segunda`: devuelve únicamente `primera`.

Así que un nodo, una sentencia. Cuando hagan falta varias en orden —crear, luego sembrar, luego
comprobar— se ponen en nodos distintos y **se encadenan por `mapping_data`**, que es lo que fuerza
el orden de ejecución: la traza los numera 1, 2, 3. Un nodo DML devuelve
`{status, query_type: "DML", affected_rows, message}`, así que el siguiente puede leer cuántas filas
tocó el anterior, y con `UPDATE … LIMIT 1` eso da la reserva de trabajo de una cola.

Para que la cadena no se corte a mitad, los nodos DML llevan `skip_if_empty_input=false` y
`skip_branch_if_empty_output=false`: un `UPDATE` que no toca ninguna fila no debe matar el resto.

**Y el componente veta el DDL, no sólo el borrado.** `CREATE TABLE` se rechaza igual que `DROP` con
`Query contains dangerous operation`, así que **NappAI no puede crear el esquema donde va a
escribir**. Si un proyecto necesita tablas nuevas, eso se reporta al usuario como lo que es —una
cosa que el producto no hace— y se decide con él; no se resuelve por consola.

## Credenciales: la elige el USUARIO, no tú

`nappai_credentials(action="list")` te dice qué tiene el usuario. Lo que se hace con esa lista es
**preguntar**, no elegir. Aunque haya una sola credencial de ese proveedor, y aunque el nombre
encaje perfectamente con lo que estás montando: una credencial apunta a un sitio REAL —una tienda,
una base, un buzón— y tú no sabes cuál es el bueno. Dos credenciales llamadas `MySQL` y `MySQL 2`
pueden ser producción y pruebas, y elegir por el usuario es elegir contra qué empresa escribe su
flujo.

Pregunta con las reales como opciones y **añade siempre la de crear una nueva**:

```
nappai_credentials(action="list", provider="mysqlApi")   # las que hay, con su nombre
→ pregunta al usuario: ¿cuál de éstas, o creamos una nueva para esto?
nappai_credentials(action="apply", provider="mysqlApi", credential_id="…", component_id="…")
```

`action="apply"` **sin** `credential_id` no aplica nada: te devuelve las opciones para que
preguntes. Y ojo con la diferencia entre clientes, porque cambia quién pregunta:

- **En el chat del dashboard** se pinta un selector nativo y el turno se suspende hasta que el
  usuario elige; si no tiene ninguna de ese proveedor, se abre el modal de creación.
- **Por MCP no hay ni selector ni modal**: ese stream no existe, así que la tool te devuelve las
  opciones como DATOS y **preguntas tú**.

Y si elige crear una nueva, **la creas desde aquí**: no lo mandes al panel.

```
nappai_credentials(action="create", provider="mysqlDinamic", name="MySQL soporte",
                   data={"url": "mysql://usuario:clave@host:3306/base"})
```

`data` son los campos propios de esa credencial —`{"api_key": "…"}`, `{"url": "…"}`— y se guardan
cifrados; la llamada devuelve el `id`, que ya puedes pasar a `action="apply"`. Lo único que hay
que respetar es de dónde sale el secreto: **viaja por la conversación**, así que se lo pides al
usuario, nunca te lo inventas ni lo sacas de otro sitio. Y si prefiere no pegarlo en el chat,
ENTONCES sí: que la cree en el panel y tú vuelves a llamar con `action="list"`.

Nunca digas «te he mostrado tus credenciales» si no hay una pregunta tuya en pantalla: reportar
una pregunta que no se ha hecho deja el flujo esperando una respuesta que nadie vio venir.

**No te fíes del `applied: true`.** Puede contestar que la aplicó, dejar el `credential_id` escrito
en el nodo y que el `validate` no reporte nada pendiente, y aun así la conexión no está en
ejecución: el flujo muere con un `... URL is required` que parece un fallo de la consulta y no lo
es. Cuando pase, la credencial se asigna **a mano en el panel**. Se comprueba EJECUTANDO, nunca por
el valor que devuelve la tool.

**Nunca escribas una credencial en `fields`**: esos campos se rechazan ahí a propósito.

## Un valor no arregla una forma

Si para que un campo tenga sentido hace falta un componente que no está, o una arista que no
existe, el arreglo es la TOPOLOGÍA — vuelve al SKILL y decláralo. Rellenar un campo para tapar un
hueco de cableado deja un flujo que se ejecuta sin error y no hace nada, que es la forma de
fallar más cara de este producto.
