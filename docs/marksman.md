---
id: marksman
aliases: []
tags: []
---

# Marksman — documento de trabajo

## Hechos comprobados

Probe con Marksman `2026-02-08`:

| Forma             | Resolución de Marksman                                                  |
| ----------------- | ----------------------------------------------------------------------- |
| `[x](algo.md)`    | primero el relativo exacto; si no existe, busca candidatos en workspace |
| `[x](./algo.md)`  | relativo exacto; no hace fallback                                       |
| `[x](../algo.md)` | relativo exacto en el padre                                             |
| `[x](/algo.md)`   | path exacto desde la raíz del workspace                                 |
| `[x][algo.md]`    | busca una definición `[algo.md]: destino`; no contiene un path          |

`algo.md` y `./algo.md` coinciden mientras exista el archivo junto a la nota. Si no existe, `algo.md`
puede encontrar varios archivos homónimos en el workspace y produce enlace ambiguo; `./algo.md`
queda roto. No es un simple fallback a la raíz. `[[algo]]` es una extensión wiki, no Markdown
estándar.

CommonMark define destinos, pero no un workspace ni un filesystem. GitHub, MkDocs u otro
consumidor pueden reescribirlos o dar una semántica propia a `/`; esa variación es real y está
fuera de la sintaxis Markdown.

## Qué configura `.marksman.toml`

- Configura extensiones, H1 como título, wikilinks, completado y code actions.
- La configuración del proyecto prevalece sobre la global de Marksman.
- No puede hacer `algo.md` root-relative, cambiar la base inline ni definir aliases de rutas.
- `completion.wiki.style` afecta a `[[wikilinks]]`, no a `[x](path.md)`.

Qué carpeta se entrega como root y si se permite arrancar sin ella son decisiones del cliente
LSP, no de `.marksman.toml`.

## Fronteras

| Capa                    | Decide                                                     |
| ----------------------- | ---------------------------------------------------------- |
| CommonMark              | sintaxis del destino; no define un workspace               |
| Cliente LSP             | root y si admite modo single-file                          |
| Marksman                | resolución observada de inline links y wikilinks           |
| `.marksman.toml`        | títulos, wikilinks, extensiones, completado y code actions |
| Adaptador Sabunv futuro | adjuntos y políticas propias que Marksman no implemente    |

## Decisiones abiertas

1. Qué debe hacer `gx` con `/asset.png`, especialmente en generadores web.
2. Si el adaptador debe seguir exactamente a Marksman o admitir bases/aliases propios.
3. Solo si hace falta lo segundo, crear `.nyamarksman`; no atribuir esas opciones a Marksman.

## Fuentes

[CommonMark](https://spec.commonmark.org/0.31.2/#links), [features de Marksman](https://github.com/artempyanykh/marksman/blob/main/docs/features.md), [configuración](https://github.com/artempyanykh/marksman/blob/main/docs/configuration.md) y [opciones actuales](https://github.com/artempyanykh/marksman/blob/main/Tests/default.marksman.toml).
