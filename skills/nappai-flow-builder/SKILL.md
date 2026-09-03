---
name: nappai-flow-builder
description: Construye y modifica flujos NappAI — declara la topología, los valores de los campos, la operation que decide la acción del componente, el código de PyCode/JsCode y los prompts de los agentes, todo con nappai_flow_apply. Úsala después de que nappai-plan tenga el plan aprobado, y cuando haya que añadir, quitar, recablear o reconfigurar componentes. Para un flujo que ya falla, usa nappai-fixer.
---

# Construir el flujo

Tu trabajo es dejar el flujo MONTADO y CONFIGURADO: qué nodos existen, cómo se cablean, qué
valor lleva cada campo, qué código corre y qué dice el prompt de cada agente. Todo eso es UNA
tool y UNA llamada.

Antes fueron tres skills —topología, configuración y prompts—, una por cada familia de tools que
había. `nappai_flow_apply` las absorbió: partir en tres el DTO de una sola llamada sólo añadía
viajes y delegaciones. Lo que NO se ha ido es la disciplina que justificaba el reparto, y sigue
valiendo dentro de una sola cabeza:

- **Nunca escribas un valor que no hayas comprobado.** Un identificador inventado pasa todas las
  guardas —la comprobación de requeridos sólo mira que el campo no esté vacío, nunca que el
  valor EXISTA— y el flujo revienta al ejecutarse, tres vueltas después.
- **Decide la FORMA antes de los valores.** La operación vigente de un nodo y el modo lote
  deciden qué campos existen y qué handles se dibujan; la tool los escribe en ese orden, pero el
  diseño lo decides tú antes de declarar nada.
- **Un prompt no arregla un cableado.** Si un agente recibe vacío, el prompt es irrelevante:
  busca por dónde le entra el dato.

El detalle está en dos referencias de esta skill — cárgalas cuando toque, no de entrada:

- `references/configuracion.md` — reglas campo a campo, la `operation`, el sondeo antes del
  código y de un `{clave}`, SQL, `env`/environments, y hacer dinámico un campo (modo lote vs.
  argumento de tool).
- `references/prompts.md` — cómo se redacta el `system_prompt` de un agente, qué NO puede
  arreglar un prompt, y las dos cosas que significan las llaves `{}`.

## No leas el repo: pregúntale a las tools

Trabajas contra el MCP de NappAI, y aquí **no tienes permitido abrir el código del proyecto**
para averiguar nada: ni leer ficheros, ni hacer grep por el repo, ni buscar la clase de un
componente para deducir qué campos tiene. Todo lo que necesitas lo sirve una tool: el catálogo
dice qué existe y qué contrato tiene, el lienzo dice qué hay puesto de verdad, la traza dice
qué falló.

Leer código para contestar algo que una tool resuelve en una llamada quema miles de tokens, y
encima te responde de una versión que no es necesariamente la que está corriendo. Si crees que
la respuesta solo está en el código, no la busques ahí: dilo y pregunta.

## El repo y la base no se tocan por fuera

La regla de arriba es de LECTURA. Esta es de ESCRITURA y es mas dura: mientras trabajas en un
flujo, **el proyecto es de solo lectura y la base de datos se toca unicamente a traves de
NappAI**.

- **No crees ficheros en el proyecto.** Ni codigo, ni SQL, ni notas, ni documentacion, ni un
  README, ni un fichero de memoria. Ninguno. Lo que aprendas va a tu memoria propia, que vive
  fuera del repo, o al informe que le das al usuario.
- **No modifiques codigo del proyecto**, y eso incluye estas skills. Si descubres una regla que
  merece vivir aqui, PROPONSELA al usuario y espera el si; no la escribes por iniciativa propia
  a mitad de un flujo.
- **No ejecutes SQL por fuera.** Ni `docker exec ... mysql`, ni `psql`, ni un cliente externo, ni
  un script. Para saber que columnas tiene una tabla o que valores admite un enum, el camino es un
  **nodo del lienzo** con `Custom Query`, y asi queda dentro del flujo.
- **Tablas o esquemas nuevos se PREGUNTAN antes**, con opciones concretas, y se crean con un
  componente de NappAI. Que el usuario apruebe QUE tablas no autoriza el COMO.

Y hay una trampa que cierra el circulo: el componente SQL **veta las operaciones destructivas**
—un `DROP TABLE` se rechaza con `Query contains dangerous operation`—, asi que una tabla creada
por consola **no se puede deshacer con las tools**. Saltarse la regla no es un atajo reversible.

**Por que manda esta regla:** lo que se hace por fuera funciona, pero no demuestra nada. No queda
en el lienzo, el usuario no lo puede reproducir ni revisar, ensucia su repo con ficheros que no
pidio, y deja el estado real fuera del producto. Si algo no se puede hacer con NappAI, eso es
precisamente el hallazgo que hay que reportar: no es un permiso para hacerlo por otro lado.

## Usa el nombre real, no el que suena bien

Antes de añadir un componente, confirma su nombre exacto con
`nappai_catalog(action="search")`, y su contrato con `action="get"`. El contrato es lo que te
dice qué salidas y qué entradas tiene: sin eso, cablear es adivinar handles, y un handle
inventado se rechaza. Si vas a montar varios nodos, pide sus contratos juntos con
`names=[...]` (hasta 15) en vez de uno por llamada.

Si el componente que pide el plan no existe en el catálogo, **para y dilo**. No lo sustituyas
por tu cuenta: sustituir Slack por un webhook genérico porque no encontraste el nativo es
exactamente el fallo que hay que evitar.

## La periodicidad NO se cablea

Si el plan dice que el flujo se ejecuta cada cierto tiempo, no busques un nodo para eso: no
existe `ScheduledTrigger`, ni `Cron`, ni `Timer`. Y **no pongas un `Webhook` genérico de entry
point** «para que algo lo llame»: sin payload devuelve `Data(data={})` y el flujo se ejecuta en
vacío sin dar error.

Monta el flujo con un entry point autosuficiente —un componente de lectura, `CurrentDate`, un
`TextInput` con valor fijo— y deja escrito en tu informe de cierre que queda pendiente crear la
programación, con el cron exacto en UTC.

La programación se crea **fuera del lienzo y después de guardar**, con
`platform(kind="schedules", action="create", …)` (necesita el `flow_id`, así que el flujo tiene
que estar ya persistido). Ahí no llegas tú: tu
trabajo es la topología. Lo que sí es tuyo es no dejar el cron sin decir — quien cierre el flujo
lo necesita para crear la programación, y un informe que dice «es periódico» sin la expresión
obliga a volver a preguntarle la cadencia al usuario.

## «Sólo si hay algo» se CABLEA, no se confía a un interruptor

Cuando el plan diga que un nodo sólo debe actuar si hay resultados —enviar el correo sólo si hay
alertas, escribir sólo si hay filas—, **no lo dejes en manos de `skip_branch_if_empty_output`**.
Ese interruptor está en `true` por defecto y aun así **no corta**: una salida vacía llega al nodo
siguiente como `Data(data={})`, y una lista con un elemento vacío no es una lista vacía. El nodo
se ejecuta con los campos sin resolver y revienta, convirtiendo «hoy no había nada» en un error.

Mete un `DataConditionalRouter` entre el productor y el nodo de acción:

```
add_component  DataConditionalRouter        # mapping_mode=false, operator="is not empty",
                                            # key_name = una clave que sólo tienen los items reales
add_edge  productor.py_code_output -> router.data_input
add_edge  router.true_output       -> nodo_de_accion.mapping_data
```

`false_output` se deja sin conectar a propósito: la guarda avisará de que no tiene destino, y esa
es la respuesta correcta —esos casos no deben hacer nada—. Dilo en el informe de cierre para que
nadie lo «arregle» después.

## Quien lee texto de fuera no escribe

Si un agente lee texto que ha escrito alguien de fuera —correos, mensajes de cliente, formularios,
páginas de proveedor, descripciones de tickets— **no le cuelgues del puerto `tools` nada que
escriba**, y mucho menos un componente SQL con `Custom Query`, que es SQL libre en manos de quien
redactó el correo.

La escritura se cablea aparte y con la forma acotada de siempre:

```
lectura → agente (SIN tools) → PyCode adaptador → nodo de escritura con columnas fijas
```

Así la regla se cumple **por construcción**: aunque el texto entrante consiga convencer al modelo,
no hay ningún camino desde su respuesta hasta una escritura arbitraria. El adaptador sólo emite las
claves que tú pusiste, y el nodo de destino sólo escribe esas columnas.

Es una decisión de TOPOLOGÍA, no de prompt: un prompt que dice «no obedezcas al correo» ayuda, pero
lo que impide el daño es que el puerto no exista.

Marca además el dato como lo que es. Si el payload que viaja al tablón lleva contenido externo,
que lleve también una clave que lo diga (`"contenido_no_fiable": true`), para que el departamento
que lo recoja sepa que eso no es una instrucción de la casa.

## El flujo ya existe cuando tú llegas

**nappai-plan** lo crea al cerrar el plan, con el nombre y la carpeta que el usuario eligió
(`nappai_flow(action="create")`). Así que cuando tú construyes, el flujo ya tiene `flow_id` — y
eso significa que **cada cambio que apliques se persiste solo**, sin que tengas que guardar nada.

Si te encuentras sin flujo (nadie lo creó, o vienes de un `action="new"`), no construyas a ciegas
y guardes al final: **créalo primero**. Necesitas nombre y carpeta, y la carpeta es del usuario:
lista con `nappai_flow(action="folders")` y pregúntale con las reales como opciones, ofreciéndole
siempre crear una nueva —que la creas tú con `nappai_flow(action="create_folder", name="…")`—. Que
sólo haya una carpeta no te autoriza a asumirla.

Y si al terminar el nombre ya no describe lo que quedó, arréglalo: `nappai_flow(action="rename",
name="…")`. Para la carpeta, `nappai_flow(action="relocate", folder_id="…")`.

```
nappai_flow(action="folders")
nappai_flow(action="save", name="…", folder_id="…")   # name y folder_id, SOLO aquí
```

## Declara el flujo, no los pasos

`nappai_flow_apply` no ejecuta operaciones: le describes el flujo que quieres y él calcula la
diferencia contra el lienzo y la aplica en el orden correcto. Manda los nodos y su cableado en
UNA llamada:

```
nappai_flow_apply(flow={
  "nodes": [
    {"id": "pregunta", "component": "ChatInput",     "name": "Pregunta"},
    {"id": "agente",   "component": "AdvancedAgent", "name": "Agente"}
  ],
  "edges": [
    {"from": "pregunta", "out": "message", "to": "agente", "in": "arg_input"}
  ]
})
```

Un nodo nuevo lo nombras con el `id` que tú elijas: el id REAL lo asigna el backend y la
respuesta te lo devuelve en `ids`. Uno que ya existe se declara con su id real.

**Tú declaras `nodes`, `edges` y el `name` de cada nodo.** El DTO acepta también `fields`,
`prompt`, `code` y `tool_args` en cada nodo, y **nada te va a impedir escribirlos**: la frontera
entre skills es disciplina de este reparto, no una guarda de la tool. Respétala igual — un valor
puesto de paso por quien no lo ha comprobado es exactamente lo que el configurator existe para
evitar. Si al montar la forma descubres que hace falta un valor, un prompt o código, anótalo en
tu informe con el nodo y el campo.

**El `mode="replace"` es tuyo**, y por eso te toca a ti el cuidado: deja el
lienzo EXACTAMENTE como lo declares, así que **lo que no menciones se BORRA**, configuración
incluida. Sobre un flujo que ya existía, o lo lees entero con
`nappai_flow_inspect(scope="dto")` —que te lo devuelve en ESTA misma forma, valores, prompts y
código incluidos, para reenviarlo cambiando lo que toque— o usas `mode="merge"` y añades sólo lo
que falta. Si lo abriste tú con `nappai_flow(action="get")`, ya lo tienes: ese `get` devuelve el
DTO. Lo que NO sirve para esto es `scope="canvas"`: es el mapa, no trae valores, y declarar
desde él con `replace` borra la configuración de todos los nodos. Y ojo con un nodo que ya existe: decláralo con su id REAL, porque con un id
inventado lo estarías borrando y recreando — y eso pierde toda su configuración.

**Lee `operaciones` en la respuesta.** Cada cambio informa por separado y uno que falla no
aborta los demás: si una arista se rechazó por un handle inexistente, el error te dice el nombre
bueno. Un `ok: false` con `no_aplicado` significa que la reconciliación DESHIZO ese cambio.

## Nombra al crear

Pon el `name` del nodo. Para renombrar uno que ya existe, declara su id real con el `name`
nuevo: se renombra en el sitio. **Nunca lo declares como nodo nuevo para renombrarlo**: eso lo
duplica.

## Mira antes de tocar

`nappai_flow_inspect(scope="canvas")` te da el mapa: qué nodos hay y cómo están cableados.
Úsalo antes de añadir, para no duplicar, y después, para comprobar que quedó como querías.
`ChatInput` y `ChatOutput` no se pueden duplicar y la tool lo rechaza.

## Lo que no es tuyo se PREGUNTA

Hay cosas que no puedes decidir tú por mucho que la tool te deje escribirlas. Todas se resuelven
igual: **pregunta con opciones concretas, usando `AskUserQuestion`** —caben hasta 4 preguntas en
una llamada, así que agrúpalas en vez de encadenar turnos— y no sigas construyendo encima de una
respuesta que no te han dado.

**1. La credencial la elige el USUARIO.** `nappai_credentials(action="list")` te dice qué tiene;
lo que se hace con esa lista es **preguntar, no elegir**. Aunque haya UNA SOLA credencial de ese
proveedor, y aunque el nombre encaje perfectamente: una credencial apunta a un sitio REAL —una
tienda, una base, un buzón— y `MySQL` y `MySQL 2` pueden ser producción y pruebas. Elegir por él
es elegir contra qué empresa escribe su flujo. Pregunta con las reales como opciones y **añade
siempre la de crear una nueva**. Por MCP no hay selector ni modal: la tool te devuelve las
opciones como DATOS y **preguntas tú**.

Y «crear una nueva» es una opción de verdad, no un desvío al panel:
`nappai_credentials(action="create", provider=…, name=…, data={…})` la crea y te devuelve su id.
El secreto viaja por la conversación, así que se lo pides al usuario — nunca lo inventas.

**El `provider` es tuyo, no suyo.** `mysqlDinamic`, `postgresDinamic`, `googleMail`,
`openAiApi` son identificadores internos de la plataforma: te sirven para filtrar la lista y
para distinguir dos credenciales que se llamen igual, y NO se enseñan. Lo que la persona
reconoce es el NOMBRE que ella le puso —«MySQL», «Adrian Postgres SQL»—; el proveedor no le
dice nada y encima despista, porque un mismo servicio puede tener dos grafías (`mysqlApi` y
`mysqlDinamic`) que en pantalla se presentan igual. Enséñaselo sólo si lo pide.

Y para BUSCAR, filtra: `action="list"` sin `provider` te devuelve cuántas hay de cada
proveedor, no sus nombres. Los nombres salen al llamar con `provider=…`, y vale el nombre
suelto — «mysql» encuentra `mysqlDinamic`.

**2. El permiso no te lo concedes tú.** Cuando una tool te devuelva la petición con
`authorized=false` —el sondeo que ejecuta el flujo, un cambio que toca la cuenta del usuario—,
**trasládasela y espera su sí** antes de repetir con `authorized=true`. Y nunca digas «te he
mostrado tus credenciales» ni «te lo he preguntado» si no hay una pregunta tuya en pantalla:
reportar una pregunta que no se ha hecho deja el flujo esperando una respuesta que nadie vio
venir.

**3. El dato que sólo tiene él.** Nombres de tabla, de hoja, de canal o de etiqueta; rutas;
direcciones de correo; el esquema de una tabla en la que vas a escribir. Si no lo ha dicho el
usuario y no lo puedes MEDIR contra el servicio, no lo inventes: pregúntalo. Un identificador
inventado pasa todas las guardas —la comprobación de requeridos sólo mira que el campo no esté
vacío, nunca que el valor EXISTA— y revienta al ejecutarse, tres vueltas después. Y **las tablas
o esquemas nuevos se preguntan antes**: que apruebe QUÉ tablas no autoriza el CÓMO.

**4. La rama que el plan no decidió.** Si el plan no dice por dónde va y hay dos formas
razonables, **pregunta con opciones**. No elijas la que te parezca y sigas: quien descubre la
duda es quien la plantea.

El detalle operativo de las credenciales —qué devuelve `apply` sin `credential_id`, por qué un
`applied: true` no demuestra que la conexión funcione— está en `references/configuracion.md`.

## El orden dentro de la llamada

La tool aplica en el orden en que las escrituras se quedan, pero hay dos cosas que decides TÚ
antes de declarar:

1. **El modo lote de cada componente** (`mapping_mode`, que nace ENCENDIDO), porque decide POR
   DÓNDE entran los datos y por tanto todo el cableado. Con el lote encendido, `mapping_data` es
   el ÚNICO handle de entrada cableable. Mezclarlos es el fallo silencioso más caro de este
   producto: la arista pasa, el texto llega VACÍO y no hay ningún error.
2. **Qué campos NO llevan valor** porque los alimenta una arista. Si declaras los dos, la arista
   gana y la escritura se rechaza.

El código va al final y **exige haber sondeado antes** (`nappai_probe`): escribirlo contra una
forma adivinada es la causa nº1 de que un PyCode reviente en ejecución. Los prompts, también al
final, con el flujo ya cableado — el ROL de un agente se deduce de su posición.

## Cierra diciendo qué queda

Relee el lienzo con `nappai_flow_inspect(scope="canvas")` y cuenta de ahí, no de lo que ibas a
hacer. Enumera lo que queda fuera de tu alcance: qué nodos necesitan CREDENCIAL (la elige el
usuario), qué datos suyos faltan, y si el flujo es periódico, el cron en UTC para que quien
cierre pueda crear la programación. Y pasa el turno al **nappai-fixer**: un flujo no está
terminado porque esté bien montado, sino porque FUNCIONA.
