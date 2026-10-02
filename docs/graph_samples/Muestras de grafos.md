# Muestras de grafos

## Brief

Los mismos tres diagramas escritos en los cuatro lenguajes de grafos que soporta esta configuración, cada uno con el código y el PNG que genera. No forman parte de la configuración: están para comparar los lenguajes viendo a la vez lo que cuesta escribirlos y cómo quedan.

| Diagrama | Qué muestra |
| --- | --- |
| `clases` | El paquete `incremental`: un `Graph` de `Unit` con dependencias, un `Manifest` con el estado de la última compilación y un `Tracker` que los cruza para saber qué regenerar |
| `flujo` | El algoritmo de `Graph.Affected`: recorre en anchura los dependientes de las unidades cambiadas |
| `casos_de_uso` | Quién hace qué con un sitio personal, desde escribir una entrada hasta leerla |

Cada lenguaje tiene tres variantes:

- **`sin_estilo/`**: sólo lo que el diagrama necesita para decir lo que dice: la forma de cada nodo (rombo de decisión, persona, óvalo de caso de uso), la línea discontinua de `«include»` y `«extend»`, el rombo de composición. Ni colores, ni fuentes, ni dirección, ni motor de layout. Es lo que da el lenguaje por sí solo.
- **`con_estilo/`**: lo mismo, ajustado a mano para que quede bien.
- **`con_plantilla/`**: los diagramas de `sin_estilo/` con una plantilla de estilos compartida al lado, que se aplica al renderizar o con una línea de import. Sirve para ver cuánto se puede arreglar sin tocar cada diagrama.

| Lenguaje | Clases | Flujo | Casos de uso |
| --- | --- | --- | --- |
| [D2](d2/) | nativo (`shape: class`) | nativo | imitado: personas, óvalos y un contenedor |
| [DOT](dot/) | imitado: tablas HTML | nativo | imitado: actores como cajas `«actor»` y un cluster |
| [Mermaid](mermaid/) | nativo (`classDiagram`) | nativo (`flowchart`) | imitado: un `flowchart` con estadios y un subgraph |
| [PlantUML](plantuml/) | nativo | nativo (diagrama de actividad) | nativo |

## Cuál elegir

Los cuatro sirven: con los tres diagramas de muestra, todos dan un resultado correcto, y el aspecto se arregla con una plantilla (ver [analisis.md](analisis.md)). Así que esto no compara estilos, sino lo que de verdad separa a uno de otro: cuánto hay que escribir, qué tipos de diagrama sabe hacer y qué pasa cuando el diagrama se complica.

Lo que hay que escribir en cada uno, sin estilos (líneas / caracteres sin espacios, de las carpetas `sin_estilo/`):

|          | Clases        | Flujo        | Casos de uso |
| -------- | ------------- | ------------ | ------------ |
| D2       | 43 / 719      | 21 / 650     | 24 / 787     |
| DOT      | 41 / **2154** | 24 / 750     | 30 / 797     |
| Mermaid  | 38 / 647      | 22 / 558     | 25 / 606     |
| PlantUML | 37 / 655      | 23 / **416** | 26 / 660     |

Casi todo está empatado. Hay dos excepciones, y las dos dicen mucho: las clases en DOT cuestan el triple, porque cada clase es una tabla HTML escrita a mano, y no quedan mejor por ello; y el flujo en PlantUML es el más corto, porque se escribe con `if` y `while` en vez de dibujar cada flecha.

### Por tipo de diagrama

| Diagrama | Elige | Por qué |
| --- | --- | --- |
| Arquitectura, estructura, cajas dentro de cajas | D2 | Contenedores anidados y formas propias; sale limpio sin pensar en nada |
| Clases | D2, Mermaid o PlantUML | Empatados; DOT no, por el coste de las tablas |
| Flujo con lógica (bucles, condiciones anidadas) | PlantUML | El único que tiene estructuras de control, y el layout sale solo |
| Casos de uso y UML formal en general | PlantUML | El único que los tiene de verdad; los demás los imitan |
| Un diagrama que vive dentro de un markdown | Mermaid | GitHub, GitLab y Obsidian lo dibujan solos, sin generar imagen |
| Un grafo generado por un programa, o muy grande | DOT | Es el formato que emiten otras herramientas, y el que más control da sobre el layout |

### D2

**A favor**

- Es el que menos hay que pensar: sin una línea de estilo ya queda bien, y escribir un nodo es `nombre: etiqueta {shape: …}`.
- En Neovim es el único con formatter (`d2 fmt`), que de paso valida el archivo.

**En contra**

- **El layout no está bajo tu control.** Con un bucle, cada motor da un resultado distinto: en el flujo de muestra, ELK lo enreda, TALA lo dibuja de abajo arriba y sólo dagre lo deja bien. En diagramas de estructura (clases, arquitectura) esto apenas se nota; en un flujo que se complica, sí. _Cómo suplirlo:_ fijar el motor que mejor quede en cada diagrama (`vars.d2-config.layout-engine`). Si el flujo tiene mucha lógica, mejor PlantUML.
- **No es UML.** No tiene casos de uso ni estructuras de control: los primeros se imitan bien con personas y óvalos, pero un flujo se dibuja flecha a flecha. _Cómo suplirlo:_ para UML formal, PlantUML directamente.

### DOT (Graphviz)

**A favor**

- Es el formato común: lo emiten otras herramientas (por ejemplo `terraform graph` o `go tool pprof`) y tiene motores para grafos que no son jerárquicos (`neato`, `fdp`, `circo`, `twopi`). Para dibujar un grafo que sale de un programa, no tiene rival.

**En contra**

- **Todo lo que no sea un nodo con aristas se escribe a mano.** Una clase es una tabla HTML (el triple de texto que en los demás) y un actor es una caja con `«actor»`. _Cómo suplirlo:_ no se suple; para UML o diagramas a mano, usa otro.

### Mermaid

**A favor**

- GitHub, GitLab y Obsidian lo dibujan dentro del markdown. Para documentación es decisivo: no hay que generar ni subir imágenes, y el diagrama se edita en el mismo archivo que el texto.

**En contra**

- **Fuera del markdown cuesta más que los demás.** Generar una imagen exige `mmdc`, que dibuja con un navegador headless y arrastra `chromium`. _Cómo suplirlo:_ si el diagrama no va a vivir en un markdown, cualquiera de los otros es más ligero.
- **Imita peor lo que no tiene.** No hay casos de uso, y las formas que harían de actor salen mal (los círculos, enormes). _Cómo suplirlo:_ para casos de uso, PlantUML.

### PlantUML

**A favor**

- UML completo y de verdad: casos de uso con monigotes, `«include»` y `«extend»`, y diagramas de actividad con `if`, `while` y `repeat`. El flujo con un bucle anidado es el más corto de los cuatro y el layout sale solo, sin elegir motor.

**En contra**

- **Peor integrado fuera del render.** Necesita Java, en Neovim no tiene parser de Tree-sitter (así que sus bloques en un markdown salen sin color) y GitHub no lo dibuja dentro del markdown. _Cómo suplirlo:_ generar la imagen y enlazarla; si el diagrama tiene que vivir en un markdown, Mermaid.

## Qué se ve al comparar

- **D2** es el único que sin estilo ya queda bien: colores, fuente y forma de clase salen solos. Lo que añade la variante con estilo es poco: el motor de layout ELK, el sentido de izquierda a derecha en los casos de uso y color en los nodos de salida del flujo.
- **DOT** sin estilo es correcto pero austero: fuente serif y todo en blanco y negro. En el flujo hay que declarar `shape=box`, porque su forma por defecto es la elipse.
- **Mermaid** sin estilo trae su propio tema con colores. Su punto débil son los actores: el círculo (`((Autor))`) sale enorme incluso en un diagrama de dos nodos, así que con estilo son cajas con un 👤.
- **PlantUML** sin estilo tiene el aspecto UML clásico y es el único con casos de uso de verdad, monigotes incluidos. Con estilo cambia mucho con pocas líneas de `skinparam`.
- En los cuatro, los casos de uso sin estilo salen apretados: todos dibujan de arriba abajo, y este diagrama pide ir de izquierda a derecha.

## Regenerar los PNG

Desde cada carpeta. Los únicos parámetros que se pasan son de resolución (`dpi`, escala) y el fondo blanco de Mermaid, que por defecto es transparente.

```bash
for f in *.d2; do d2 --pad 40 "$f" "${f%.d2}.png"; done
for f in *.dot; do dot -Tpng -Gdpi=150 "$f" -o "${f%.dot}.png"; done
for f in *.mmd; do mmdc -s 2 -b white -i "$f" -o "${f%.mmd}.png"; done
plantuml -tpng -Sdpi=200 *.puml
```

En `con_plantilla/`, la plantilla entra así (D2 la importa desde el propio diagrama con `...@estilo`). Cada carpeta lo repite en su `renderizar.txt`:

```bash
for f in *.dot; do dot -Tpng -Gdpi=150 $(cat estilo.args) "$f" -o "${f%.dot}.png"; done
for f in *.mmd; do mmdc -s 2 -b white -c config.json -i "$f" -o "${f%.mmd}.png"; done
plantuml -tpng -Sdpi=200 -config estilo.puml *.puml
```

El análisis de cada lenguaje, con su dificultad de uso, está en [analisis.md](analisis.md). Qué hay que instalar para cada uno está en [language-dependencies.md](../language-dependencies.md).

## Tropiezos al escribirlos

- **D2**: los métodos con parámetros variádicos (`...UnitID`) tienen que ir entre comillas, o el parser falla. En clases, los métodos sin retorno salen con un `void` que en Go no existe.
- **DOT**: `graph` es palabra reservada y no distingue mayúsculas, así que el nodo `Graph` va entre comillas.
- **Mermaid**: una línea `%%` vacía en un comentario rompe el parser. En `classDiagram`, los retornos con paréntesis (`(Entry, bool)`) se pegan al método sin los `:`. Con el tema `base`, `fontFamily: sans-serif` acaba en una fuente serif.
- **PlantUML**: en el diagrama de actividad, una acción con color (`#color:texto;`) justo después de `endwhile` da error de sintaxis; los colores van por estereotipo y `<style>`. En clases, el color de fuente del bloque `class` no se aplica al nombre de la clase.
