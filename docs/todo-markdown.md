# Enlaces: especificación única

Qué formas de enlace aceptamos, cuáles escribimos y qué falta para que sea así. Vale igual para el
motor de vault (obsidian-ls / Nyabsidian) y para el de markdown suelto (marksman). Si esto y el
código discrepan, manda esto.

## Principios

**1. Leer indulgente, escribir portable.** Aceptamos cualquier forma razonable que alguien haya
escrito, pegado o traído de Obsidian. Cuando escribimos nosotros emitimos siempre la forma que no
se rompe en ningún sitio.

**2. Manda la sintaxis, no el motor.** Un `[texto](destino)` se escribe con reglas de markdown esté
en un vault o fuera; un `[[wiki]]` con reglas de wikilink esté donde esté. El motor decide _qué
sabe resolver_, nunca _cómo se escribe_.

**No existe una forma única válida para las dos sintaxis.** No es decisión nuestra, es del formato.
Perseguirla es lo que nos tenía dando vueltas.

---

# Parte 1 — La especificación

## 1.1 Coordenadas: qué aceptamos al leer

Una coordenada es _qué nota señalas_, independiente de la sintaxis que la envuelve. Las cuatro
resuelven:

| coordenada          | significado                                    |
| ------------------- | ---------------------------------------------- |
| `Nota`              | nombre pelado, buscado en todo el vault        |
| `carpeta/Nota`      | desde la raíz                                  |
| `/carpeta/Nota`     | desde la raíz (igual que la anterior)          |
| `./Nota`, `../Nota` | relativa al fichero actual                     |

Reglas transversales al **leer**:

- **Insensible a mayúsculas.** `software wrapper` encuentra `Software wrapper.md`.
- **Espacios permitidos.** El nombre del fichero manda; no se slugifica nada.
- **Desempate**: gana la más local al fichero de origen; a igualdad, la ruta más corta.

> **Cuidado con la indulgencia.** El nombre pelado resuelve porque buscamos por todo el vault. Eso
> es nuestro, no del formato: GitHub no busca, resuelve la ruta literal. De ahí la restricción de
> §1.6.

## 1.2 Extensión

| escribes      | se busca                                | resultado                 |
| ------------- | --------------------------------------- | ------------------------- |
| `Nota`        | `Nota.md`, `Nota.qmd`, `Nota.base`      | nota                      |
| `Nota.md`     | `Nota.md`                               | nota (nunca `Nota.md.md`) |
| `.luarc.json` | `.luarc.json.md` primero, luego literal | nota si existe            |
| `atlas.png`   | `atlas.png.md` primero, luego literal   | adjunto                   |

**Si la extensión es de nota, apunta a esa nota. Si es cualquier otra, se prueba primero como nota
(`X.md`) y luego como fichero literal. Sin extensión, se prueban las de nota.**

`[[Nota.md]]` equivale a `[[Nota]]`, igual que en Obsidian. La regla cubre a la vez
`[[.luarc.json]]` (nota _sobre_ un fichero de config) y `[[atlas.png]]` (adjunto de verdad): los dos
son casos reales del vault, con 49 enlaces del segundo tipo.

## 1.3 El `!` incrusta

`!` significa **incrustar**, y funciona igual con notas que con adjuntos. Sin `!` es un enlace.
Idéntico a Obsidian.

| forma            | significado                     |
| ---------------- | ------------------------------- |
| `[[Nota]]`       | enlace a nota                   |
| `![[Nota]]`      | incrusta la nota (transclusión) |
| `[[atlas.png]]`  | enlace al adjunto               |
| `![[atlas.png]]` | incrusta la imagen              |

**Neovim no transcluye.** El `!` se parsea, se resuelve, se sigue y se renombra
correctamente en los cuatro casos, pero **el contenido no se pinta en línea**: ni
render-markdown.nvim ni obsidian.nvim implementan transclusión (no la mencionan en
ninguna parte de su código). En la app de Obsidian sí se ve incrustado; aquí un
`![[Nota]]` se comporta como un enlace. Es una diferencia con la app, no un fallo
de esta especificación.

## 1.4 Ambigüedad

Aplica igual a **notas y adjuntos**, y en las dos sintaxis.

**Forma mínima inequívoca.** Al escribir usamos la coordenada más corta que siga siendo
inequívoca, ampliando carpeta a carpeta sólo lo necesario:

```
Nota                    si el nombre aparece una sola vez
carpeta/Nota            si aparece más de una
carpeta/otra/Nota       y así, con el mínimo de carpetas
```

- La ambigüedad se calcula contra **nombres y alias** (los `reference_ids`), no sólo basenames. Una
  nota con alias colisiona igual que una que se llame así.
- Al reescribir **se conserva el `|alias`**: `[[Nota|como se lee]]` → `[[carpeta/Nota|como se lee]]`.

**Creada vs preexistente.** Regla que decide qué hacer cuando algo se vuelve ambiguo:

> Ambigüedad **creada** por una operación nuestra → la resolvemos, porque conocemos el destino
> original. Ambigüedad **preexistente** → no se toca y se avisa.

Adivinar en el segundo caso sería peor que no hacer nada: si `[x](guia.md)` ya casaba con dos
ficheros, nadie sabe cuál quiso decir el autor.

**Re-minimización.** Crear o borrar puede cambiar la ambigüedad de enlaces que ya existían. Si hay
`carpeta/Mi Nota.md` referenciada como `[[Mi Nota]]` y aparece otra `Mi Nota.md`, esos enlaces
dejan de ser inequívocos. Se reescriben en los dos sentidos —ampliando al colisionar, acortando
cuando la colisión desaparece— conservando alias.

## 1.5 Wikilinks `[[...]]`

No son CommonMark. Los reconocen Obsidian, Foam, Logseq, Dendron y los _wikis_ de GitHub. **El
markdown normal de un repo de GitHub no los renderiza**: salen como corchetes crudos.

| forma                                   | uso              |
| --------------------------------------- | ---------------- |
| `[[Nota]]`                              | enlace a nota    |
| `[[carpeta/Nota]]`, `[[/carpeta/Nota]]` | desambiguada     |
| `[[Nota\|Alias]]`                       | con etiqueta     |
| `[[Nota#Mi Heading]]`                   | a un heading     |
| `[[Nota#Padre#Hijo]]`                   | heading anidado  |
| `[[atlas.png]]`                         | enlace a adjunto |
| `![[Nota]]`, `![[atlas.png]]`           | incrusta         |

**Forma canónica al escribir:**

- Nombre pelado, **sin extensión**, ampliado según §1.4.
- Espacios **literales**; nada de `%20`, aquí sería ruido.
- Anchors con el texto del heading tal cual, espacios y mayúsculas incluidos.
- Caja exacta del fichero.

```
[[Nota mía]]          [[carpeta/Nota mía|alias]]          [[Nota mía#Mi Heading]]
```

## 1.6 Enlaces markdown `[texto](destino)`

| forma                   | uso                                    |
| ----------------------- | -------------------------------------- |
| `[texto](destino)`      | enlace                                 |
| `![alt](src)`           | imagen                                 |
| `[![alt](src)](url)`    | imagen enlazada (badge) — dos destinos |
| `<https://ejemplo.com>` | autolink                               |

**Forma canónica al escribir:**

- **Ruta posicional desde la raíz**: `/carpeta/Nota.md`. Nunca un basename pelado — ver el aviso de
  abajo.
- **Extensión `.md` obligatoria.** Sin ella GitHub da 404: resuelve rutas literales, no adivina
  extensiones.
- **Espacios como `%20`.** Un espacio crudo **corta el destino** en CommonMark:
  `[x](/docs/Software wrapper.md)` se parsea como `/docs/Software` y el resto se pierde. Rompe en
  GitHub, pandoc, mdBook y marksman.

  Las dos formas válidas son `%20` y los ángulos `<...>`. **Aceptamos las dos al leer** —
  `[x](</docs/Guía rápida.md>)` resuelve, y `:NyabsidianRelink` lo deja como está, porque ya es
  portable. Al escribir emitimos `%20`, por coherencia con los anchors. Si prefieres ver el espacio
  en claro, escribe los ángulos a mano: nada te los va a tocar.

  Lo único que no se puede es el espacio suelto, y no por regla nuestra: ese texto no nos llega
  entero.

- **Se escapa lo mínimo.** Sólo lo que rompería el parseo: espacio y tabulador, `()` que cierran el
  destino, `<>` que lo delimitan, `"'` que abrirían un título, y `[]{}|\`^`. Todo lo demás se
  conserva legible — **los acentos no se tocan**: `/docs/Guía%20rápida.md`, no
  `/docs/Gu%C3%ADa%20r%C3%A1pida.md`. GitHub sirve UTF-8 en la ruta igual de bien y
  percent-encodearlo sólo ensucia el enlace.

  Vive en un solo sitio, `lzy.link_target.encode`, y lo usan los dos motores. Antes había dos
  codificadores y el resultado dependía de por qué ruta hubieras llegado: la misma nota se
  enlazaba con la `ú` literal o en bytes según si el candidato venía de la búsqueda de notas o del
  recorrido de carpetas.
- **Anchors también `%20`**: `#Mi%20Heading`.
- Caja exacta del fichero.

```
[Software wrapper](/docs/Software%20wrapper.md)
[Software wrapper](/docs/Software%20wrapper.md#Mi%20Heading)
```

> **Un basename pelado no vale aquí.** `[x](Nota.md)` resuelve en nuestro motor porque buscamos por
> todo el vault, pero GitHub sólo lo encuentra si está en la misma carpeta que el fichero que
> enlaza. Es el peor de los fallos: local se ve bien, publicado da 404. Al leer lo seguimos
> aceptando; al escribir, nunca.

## 1.7 Referencias CommonMark y notas al pie

| forma                    | uso           |
| ------------------------ | ------------- |
| `[id]: destino "título"` | definición    |
| `[texto][id]`            | uso completo  |
| `[id][]`                 | uso colapsado |
| `[id]`                   | uso abreviado |

El destino de la definición sigue **las mismas reglas que §1.6**. El identificador es insensible a
mayúsculas y a espacios repetidos por spec CommonMark; eso no lo tocamos.

`[^1]` y `[^1]: texto` son notas al pie, no enlaces a notas. Fuera de estas reglas.

## 1.8 Quién escribe qué sintaxis

No se elige: la fija el contexto.

| quién escribe                    | sintaxis                                        |
| -------------------------------- | ----------------------------------------------- |
| completion tras `[[`             | wikilink                                        |
| completion tras `[texto](`       | enlace markdown                                 |
| rename, convert, re-minimización | **la que ya tenía el enlace**, nunca la cambian  |
| copia inteligente                | wikilink en el vault, Markdown fuera (ver abajo) |

La copia inteligente es la única que fabrica un enlace donde no había ninguno, así que es la única
que elige. Dentro de un vault emite `[[Nota#Mi Heading]]`; fuera, donde los wikilinks no son la
lengua franca, emite `[Mi Heading](/docs/Nota.md#mi-heading)` — etiqueta legible, destino escapado
y anchor en la forma canónica de marksman, que es la que renderiza GitHub. Lo decide sola mirando
si el buffer pertenece a un vault; está en `<leader>ns` en los dos motores.

El par donde es fácil resbalar, porque las formas canónicas **no** coinciden:

```
[[n        ->  [[Nota mía]]                        sin .md, espacio literal
[Nota](n   ->  [Nota](/docs/Nota%20mía.md)         con .md, ruta desde la raíz, %20
```

## 1.9 Compatibilidad

| forma                                    | Obsidian | GitHub                | marksman |
| ---------------------------------------- | -------- | --------------------- | -------- |
| `[[Nota]]`, `[[carpeta/Nota]]`           | sí       | **no renderiza**      | sí       |
| `[x](/docs/Nota.md)`                     | sí       | sí                    | sí       |
| `[x](docs/Nota.md)`                      | sí       | sí, si es relativa OK | sí       |
| `[x](Nota.md)` desde otra carpeta        | sí       | **404**               | sí       |
| `[x](/docs/Nota%20con%20espacio.md)`     | sí       | sí                    | sí       |
| `[x](/docs/Nota con espacio.md)`         | **no**   | **no**                | **no**   |
| `[x](/docs/Nota)` sin `.md`              | sí       | **404**               | sí       |

Las tres filas en negrita son las que nuestro motor acepta y el mundo no. Son exactamente lo que
§1.6 prohíbe escribir.

---

# Parte 2 — Estado

## Hecho

Todo esto está implementado y con test.

- **Coordenadas** `Nota` / `carpeta/Nota` / `/carpeta/Nota`, insensibles a mayúsculas, con espacios.
- **Regla de extensión** completa (§1.2): `[[Nota.md]]`, `[[.luarc.json]]` y `[[atlas.png]]`.
- **Nombres de nota verbatim**, sin slug ("Mi Nota" → `Mi Nota.md`), y anchors verbatim en wiki con
  `%20` en markdown.
- **Ambigüedad creada vs preexistente** (§1.4): los dos motores cualifican cuando pueden y avisan
  cuando no (`rename.lua:496`, `headings.lua:583`).
- **A1 · Barra inicial = raíz** en todos los resolutores. Estaba roto en dos sitios, no en uno:
  `link_actions.lua` y `attachments.resolve` la leían como raíz del disco. Ahora las dos prueban
  primero bajo el vault y sólo después como ruta del sistema, que es como se enlaza algo de fuera.
- **A2 · `lzy.obsidian.coordinate`**, la primitiva de forma mínima inequívoca. Amplía carpeta a
  carpeta (`Nota` → `deep/nested/a`) en vez de saltar a la ruta completa, y sólo cuenta un rival
  como colisión en frontera de carpeta (`miotra/Nota` no colisiona con `otra/Nota`). Va sobre el
  índice cacheado, así que además es más rápida que el recorrido del vault que hacía antes por cada
  enlace.
- **A3 · Desempate local-first para notas**, el mismo criterio que ya usaban los adjuntos.
- **A6 · Escritores por sintaxis.** La completion emitía `%20` y `.md` también dentro de `[[`;
  ahora cada sintaxis inserta su forma canónica.
- **A7 · Diagnósticos de portabilidad.** Avisan de enlaces que resuelven aquí y se rompen fuera:
  espacio crudo en el destino (error), destino que sólo existe con `.md` (warning) y nombre suelto
  que no está en esta carpeta (hint). Calibrados contra los 1257 ficheros reales: **0 errores, 0
  warnings y 1 hint**, y ese hint es un acierto — `docs/caos/README.md` enlaza a `LICENSE`, que
  vive en la raíz del repo y no a su lado.
- **P1 · Política unificada.** `.nyabsidian` acepta `link_paths` con la misma forma que el antiguo
  `attachment_paths` (que se sigue admitiendo), y gobierna notas y adjuntos por igual.

### La frescura del índice

`coordinate` acepta `fresh`. La razón: un índice rancio al que le falta una nota hace escribir una
coordenada **más corta de lo debido**, y ése es el error peligroso — el enlace queda ambiguo en
silencio, mientras que equivocarse al revés sólo deja una ruta más larga de la necesaria. Las
acciones sueltas del usuario piden `fresh`; las masivas invalidan una vez y reutilizan el índice.

- **A5 · `:NyabsidianRelink`** (`lzy.obsidian.relink`). Recorre el vault, recalcula la forma
  canónica de cada enlace y aplica un único workspace edit tras confirmar. Nunca toca un enlace que
  no resuelva o que resuelva a más de una cosa: en una pasada masiva, no saber es razón para no
  tocar. Sobre el vault real (1237 notas, 9101 enlaces) tarda ~1,8 s.
- **A4 · Re-minimización al alta.** `relink.on_note_added` corre al crear una nota, con la puerta
  barata delante: si el nombre no colisiona (lo normal) es un lookup y no hace nada. Si colisiona,
  amplía los enlaces que la nota nueva acabaría de secuestrar — y **sólo** los amplía: corre sin que
  nadie lo pida, así que se limita a la corrección y no reordena por estilo. Enganchado a las tres
  puertas de creación: seguir un enlace inexistente, `:Obsidian new` y `new_from_template`.
- **Wikilinks en marksman.** Nuestro completado inserta el nombre legible (`Espacios y mayús`), no
  la ruta escapada con `.md` que metía antes. Y `workspace.resolve` acepta además la forma en
  **slug** que escribe el propio servidor (`espacios-y-mayús`), que no era el nombre de ningún
  fichero y por tanto no resolvía ni se podía crear. El slug es su default y **no se puede cambiar
  desde Neovim**, sólo con un `.marksman.toml` por proyecto: ver `docs/caos/marksman.md`.
- **Crear nota desde enlace, también fuera del vault.** `lzy.marksman.new_note`: seguir un
  `[[Nota]]` inexistente ofrece crearla, con el fichero llamado exactamente como el enlace.
- **Marksman comparte la primitiva.** `safe_replacement_path` desambiguaba saltando a la ruta
  entera; ahora llama a `coordinate.minimal` igual que el lado Obsidian. Y distingue sintaxis, que
  es lo que se me había escapado: un `[[wiki]]` recibe el sufijo mínimo (`c/renamed`) porque lo
  resuelve un motor que busca, y un destino Markdown la ruta desde la raíz (`/a/b/c/renamed.md`)
  porque lo resuelve GitHub siguiendo la ruta literal. Los dos motores desambiguan ya igual.

### Tres fallos que salieron en la revisión

**Caja en wikilinks: se corregía y no debía.** El primer `:NyabsidianRelink` sobre el vault real
proponía 10 cambios, todos de caja (`[[Unix]]` → `[[UNIX]]`, `[[QuickShell]]` → `[[Quickshell]]`).
Pero en un `[[Destino]]` sin alias **el destino es también el texto que se lee**, así que eso
reescribe la prosa. Y no gana nada: la caja sólo importa para GitHub, que ni siquiera renderiza
wikilinks. Ahora la caja se corrige en enlaces Markdown —donde decide si resuelve o da 404— y se
respeta en los wiki. Con eso, el plan sobre el vault real pasó de 10 cambios a **0**: ya estaba
todo bien.

**Colisión por alias.** La ambigüedad se calcula contra nombres **y alias**, pero la ampliación
comparaba _sufijos de ruta_ empezando en profundidad 1. Un rival que colisiona por alias no lleva
ese nombre en su ruta, así que no se detectaba y se emitía el nombre pelado — ambiguo, en silencio.
Con `frontmatter.func` añadiendo el título como alias, ése es el caso común. Ahora, si hay rivales,
el nombre pelado se descarta de entrada; y una nota ambigua en la raíz del vault, que no tiene
carpeta que añadir, sale como `/Nombre`, que es posicional y por tanto inequívoca.

**Diagnósticos mal calibrados.** La primera versión era puramente sintáctica y disparaba 35 avisos
en 20 ficheros, la mayoría falsos: `` `[x](a.md)` `` dentro de backticks (documentación _sobre_ la
sintaxis), destinos que son directorios, y nombres sueltos que sí estaban en la misma carpeta.
Ahora salta los spans de código y los fences, y comprueba el disco antes de avisar.

### `preserve` no desactiva la corrección

Si una operación nuestra vuelve ambiguo un enlace, se amplía **siempre**, tenga la política que
tenga: eso no es estilo, es un enlace que ha pasado a apuntar a otro sitio. La política sólo
gobierna el acortado y el cambio de forma.

## Pendiente

Nada de la lista original. Queda un cabo suelto conocido, anotado por si algún día molesta:

**La baja no re-simplifica.** Borrar o mover la nota que colisionaba deja los enlaces ampliados
(`[[carpeta/Nota]]`) aunque `[[Nota]]` ya volvería a ser inequívoco. No es incorrecto —el enlace
sigue apuntando a donde debe—, sólo más largo de lo necesario, y `:NyabsidianRelink` lo arregla
cuando se ejecute. Engancharlo a la baja pedía detectar borrados de fichero de forma fiable, que
es bastante más frágil que engancharse al alta.

---

# Parte 3 — Decisiones pendientes

Ninguna. P1 se cerró extendiendo la política a notas y adjuntos, conservando `attachment_paths`
como alias para no romper los `.nyabsidian` ya escritos.
