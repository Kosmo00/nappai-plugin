---
name: nappai-plan
description: Convierte un encargo de flujos NappAI en un plan aprobado antes de tocar el lienzo — detecta si es un flujo o un proyecto de varios, critica su propio plan y pide conformidad. Úsala SIEMPRE como primer paso cuando el usuario pide construir, montar o automatizar algo en NappAI, y antes de invocar nappai-flow-builder.
---

# Plan antes de lienzo

Tu trabajo es que no se construya nada que el usuario no haya aprobado. Un flujo montado a
medias contra un plan equivocado cuesta más de deshacer que de planificar.

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

## 1. Averigua si es UN flujo o un PROYECTO

Un proyecto son varios flujos que se apoyan entre sí: uno que ingiere, otro que procesa, otro
que notifica. La señal no es el tamaño del encargo, es si hay **disparadores distintos** o
**cadencias distintas**. «Cuando llegue un correo, mételo en la base y avísame por Slack» es
UN flujo. «Sincroniza el CRM cada noche y además responde formularios al instante» son dos.

Si es un proyecto, el plan lleva la lista ordenada de flujos y qué produce cada uno para el
siguiente. Se construyen **de uno en uno**, con su propia validación, no todos a la vez.

## 2. Investiga antes de decidir la forma

Si el encargo toca un servicio externo, invoca **nappai-researcher** antes de escribir el
plan. Un plan que asume que la API de X devuelve algo que no devuelve es un plan que hay que
rehacer con el lienzo ya montado.

## 3. Escribe el plan

Para cada flujo: qué lo dispara, qué componentes lo forman, cómo se cablean, qué credenciales
hace falta y dónde se guarda. Nombra los componentes por su nombre REAL del catálogo —
compruébalo con `nappai_catalog(action="search")`, no de memoria.

### «Qué lo dispara» tiene TRES respuestas, no dos

Elige una explícitamente antes de listar componentes:

1. **Invocación** — alguien llama al flujo: `ChatInput`, `TextInput`, o cualquier entrada que
   valga por sí sola. Es también la forma que tiene un flujo programado (ver el punto 3).
2. **Evento externo** — el flujo reacciona a algo de fuera: el webhook NATIVO del servicio
   (`GmailWebhook`, `GDriveWebhook`, `ShopifyWebhook`…), que reemplaza al `ChatInput`.
3. **Tiempo** — se ejecuta a una hora fija, pase lo que pase: **programación de plataforma**,
   que no es un componente y no va en el lienzo.

**Un flujo periódico se PROGRAMA, no se cablea.** No existe `ScheduledTrigger`, ni `Cron`, ni
`Timer` en el catálogo — búscalo si dudas. Y un `Webhook` genérico puesto de entry point «para
que algo lo llame» devuelve `Data(data={})` cuando nadie lo llama: el flujo se ejecuta EN VACÍO
y sin dar error, que es peor que fallar. Un cron externo tampoco hace falta: la plataforma trae
programador propio.

En el plan se declara `disparador: programación de plataforma (cron <expresión> UTC)`, y el
flujo lleva un entry point autosuficiente — un componente de lectura, `CurrentDate`, o un
`TextInput` con valor fijo. Un `ChatInput` vacío se ejecutaría con texto vacío: el mismo fallo
silencioso con otro nodo.

**La programación la creas TÚ**, con `platform` — la puerta a lo que no es del lienzo, que
despacha por `kind`/`action` — y **después**
de que el flujo esté guardado:

```
platform(kind="flows")                              # el flow_id sale de aquí
platform(kind="schedules", action="create", name=…, flow_id=…, cron="0 6 * * 1")
```

No va en el plan como «pendiente de que alguien lo haga en el panel»; va como el último paso del
flujo, con su cron ya convertido a UTC. Dos cosas del contrato de esa tool, porque cambian lo que
le dices al usuario:

- **Pide permiso.** Llámala primero con `authorized=false`, enséñale el `change` que devuelve
  —nombre, flujo y cron— y sólo pasa `authorized=true` cuando diga que sí. Registra un job real
  que ejecutará el flujo solo: no es una escritura de lienzo.
- **Necesita que el usuario tenga una API key.** Si no la tiene, la tool contesta `no_apikey` y
  no hay programación: dilo en el plan si el flujo depende de ejecutarse solo.

Si la escritura te contesta `bearer_required`, esa sesión del MCP no puede escribir en la
plataforma (está autenticada con API key). Ahí sí: entrega el cron exacto y di que se crea en la
sección **Scheduler** del panel.

**Pregunta la cadencia; no la supongas.** «Se ejecutará periódicamente» no es un plan. Si el
disparador es el tiempo y el usuario no ha dado las dos cosas, pregúntalas con opciones
concretas: la **cadencia** (diaria / semanal —¿qué día?— / mensual —¿qué día del mes?— / cada N
horas) y la **hora local, con su zona**. Y si eres TÚ quien propone que el flujo se ejecute
solo, la pregunta es igual de obligatoria.

El cron es de **5 campos y se interpreta en UTC**. Convierte tú la hora local y en la
conformidad enseña las dos: «cada día a las 20:00 (Europe/Madrid) → `0 18 * * *` UTC». Avisa de
que en invierno esa misma hora local es otro cron (`0 19 * * *`). Si te lo callas, el flujo se
ejecutará desplazado y el usuario lo reportará como bug.

**Tiempo o polling — no son lo mismo.** Los webhooks de Gmail, Drive, Forms, Odoo y Shopify ya
consultan el servicio periódicamente por dentro, y traen resuelto qué se vio ya y qué es nuevo.
La pregunta que decide: **si no hay novedades, ¿debe ejecutarse el flujo igual?** Sí → tiempo,
programación. No → evento, webhook del servicio, y no hace falta programación ninguna.

### «Dónde se guarda» es una PREGUNTA, no un detalle

La carpeta se decide **antes de construir**, con el resto de conformidades, porque el flujo se
**crea antes de construirlo** y ahí es donde hace falta.

Lista las carpetas reales con `nappai_flow(action="folders")` y ofrécelas como opciones, **con la
de crear una nueva SIEMPRE entre ellas** — y la creas tú con
`nappai_flow(action="create_folder", name="…")`, que devuelve su `folder_id`. Que sólo exista una
carpeta no es una respuesta: es justamente cuando hace falta preguntar, porque un proyecto de
varios flujos suele querer la suya.

### Cierra el plan CREANDO el flujo

Con el plan aprobado y la carpeta elegida, antes de que nadie toque el lienzo:

```
nappai_flow(action="create", name="<qué HACE el flujo>", folder_id="<la que eligió>")
```

Desde esa llamada el flujo **existe**, y eso cambia tres cosas: cada cambio del lienzo se
persiste solo (antes lo construido vivía sólo en la sesión y una sesión perdida se lo llevaba
entero), el respaldo automático antes de un borrado destructivo empieza a funcionar, y se puede
sondear ejecutando —que exige flujo guardado—.

El `name` que pongas es lo primero que el usuario va a leer en su lista: descriptivo de lo que
hace, nunca «Flujo» ni «Copiloto flow». Y si al acabar resulta que el nombre ya no describe lo
que quedó, o la carpeta era otra, se rectifica con `nappai_flow(action="rename", name="…")` y
`nappai_flow(action="relocate", folder_id="…")`. Rectificar es una llamada — así que crear pronto
no ata a nada, y no crear sí cuesta.

## 4. Critica tu propio plan

Antes de enseñarlo, busca estos fallos, que son los que más caros salen:

- **Un componente que no existe.** Si el catálogo no lo tiene, dilo en el plan y propón la
  alternativa; no lo sustituyas en silencio por un webhook.
- **Un disparador huérfano.** Un flujo «periódico» con un `Webhook` genérico de entry point y
  nadie que lo llame se ejecuta en vacío, sin error y sin que nadie se entere. Si el plan dice
  periódico, tiene que decir el cron en UTC y llevar el paso de crear la programación.
- **Un dato cuya forma no conoces.** Si el plan escribe código o un `{clave}` sobre la salida
  de otro nodo, marca ese punto: hará falta `nappai_probe` antes de escribir.
- **Un identificador inventado.** Nombres de tabla, de hoja, de canal o de etiqueta: si no los
  ha dicho el usuario, no te los inventes. Márcalos para preguntar, o para averiguarlos con un
  nodo del lienzo (`Custom Query`) — `nappai_read_service` se retiró el 2026-08-24.
- **Credenciales que el usuario no tiene.** Compruébalo con `nappai_credentials(action="list")`.
  Es mejor saberlo ahora que a mitad de la construcción.
- **Acciones irreversibles.** Enviar correos, borrar registros, publicar. Que aparezcan en el
  plan explícitamente, para que el usuario las apruebe sabiendo qué son.
- **Una carpeta sin decidir.** El flujo se crea al cerrar el plan, así que sin carpeta acabará
  sin ninguna y el usuario tendrá que buscarlo. Moverlo después es una llamada
  (`nappai_flow(action="relocate")`), pero preguntarlo ahora cuesta una opción más en la MISMA
  pregunta; arreglarlo luego cuesta un turno y que el usuario ya no lo encuentre.

## 5. Pide conformidad, con opciones

Presenta el plan y **pregunta con opciones concretas**, nunca en prosa abierta, con
`AskUserQuestion`: caben **hasta 4 preguntas en una llamada**, así que agrupa las conformidades
en vez de encadenar turnos (proveedor del modelo, proveedor del servicio, cadencia, carpeta). Si
el usuario no responde a lo que preguntas, no supongas: vuelve a preguntar.

No pases a construir hasta tener un sí explícito. Si el usuario cambia algo, rehaz el plan y
vuelve a pedir conformidad — no parchees el plan aprobado por tu cuenta.

## 6. Sostén el plan durante la construcción

El plan es tuyo, no del servidor: no hay tool que lo persista. Mientras construyes, mantenlo
visible y ve marcando lo hecho. Si un descubrimiento lo invalida —el servicio no tiene esa
tabla, el componente no admite ese campo— **para y vuelve al usuario** con el cambio
propuesto. Seguir construyendo contra un plan que ya sabes falso es el error más caro que
puedes cometer aquí.
