# Software Wrapper

Volver a [README.md](/README.md)

## Brief

En `Software wrapper` se explican dos cosas fundamentalmente:

- [Exponer un binario como comando](#exponer-un-binario-como-comando) → Cómo hacer que un binario sea reconocido por Linux y pueda
  ejecutarse directamente como un comando.
- [Priorizar un binario sobre otro](#priorizar-un-binario-sobre-otro) → Cómo hacer que un binario tenga preferencia sobre otro
  binario existente.

## Exponer un binario como comando

Cuando instalamos manualmente un programa que no ha sido instalado mediante el gestor de
paquetes, tenemos que hacer que su binario esté disponible en una ubicación incluida en el `PATH`
de nuestra shell. De esta forma podemos ejecutarlo simplemente escribiendo su nombre, sin tener
que indicar la ruta completa al binario.

Para ello tenemos varias opciones:

1. Agregar la ubicación donde se encuentra el binario al `PATH` de la shell.
2. Poner el binario en una ubicación que ya forme parte del `PATH`; normalmente `/usr/local/bin`
   (nivel de sistema) o `~/.local/bin` (nivel de usuario).

Lo habitual es utilizar `2`, ya que permite instalar el programa sin modificar la configuración de
la shell.

### Programa autocontenido

Si el programa consta de un único binario autocontenido, podemos copiarlo directamente a
`/usr/local/bin` y darle el nombre con el que queremos ejecutarlo.

Por ejemplo, para instalar manualmente Neovim desde un AppImage:

```text
nvim.AppImage → /usr/local/bin/nvim
```

De esta forma podremos ejecutarlo simplemente con:

```bash
nvim
```

El binario debe tener permisos de ejecución. Véase [Permisos de ejecución](#permisos-de-ejecución).

#### Programa autocontenido compuesto por varios archivos

Si el programa consta de varios archivos, puede ser más conveniente mantenerlos juntos en una
ubicación propia, por ejemplo `/opt/nvim`, y exponer únicamente el ejecutable mediante un _launcher_
en `/usr/local/bin`:

```text
/opt/nvim/
├── bin/
├── lib/
└── ...

/usr/local/bin/nvim → launcher
```

El _launcher_ puede ser un pequeño script que ejecute el binario real:

```sh
#!/bin/sh
exec /opt/nvim/bin/nvim "$@"
```

El _launcher_ debe tener permisos de ejecución. Véase [Permisos de ejecución](/permisos-de-ejecución.md).

También podemos utilizar un enlace simbólico cuando no necesitamos lógica adicional:

```bash
sudo ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim
```

### Exponer varias versiones

Si queremos mantener varias versiones del mismo programa instaladas simultáneamente, podemos
exponerlas utilizando nombres de comando diferentes.

Por ejemplo:

```text
/usr/local/bin/nvim12 → Neovim 0.12
```

De esta forma podemos ejecutar explícitamente esa versión con:

```bash
nvim12
```

La entrada `/usr/local/bin/nvim12` puede ser un enlace simbólico al binario real:

```text
/usr/local/bin/nvim12 → /opt/nvim12/bin/nvim
```

o un _launcher_ que ejecute el binario:

```sh
#!/bin/sh
exec /opt/nvim12/bin/nvim "$@"
```

En este último caso, el _launcher_ debe tener permisos de ejecución. Véase [Permisos de ejecución](/permisos-de-ejecución.md).

> [!NOTE]
>
> `/usr/local/bin` es apropiado para software instalado manualmente a nivel de sistema, mientras
> que `~/.local/bin` es preferible cuando queremos instalar el software únicamente para nuestro
> usuario.

### Permisos de ejecución

Los binarios y _launchers_ que queramos ejecutar directamente deben tener el permiso de ejecución.

Para concederlo:

```bash
chmod +x <archivo>
```

Por ejemplo, si el archivo se encuentra en una ubicación del sistema:

```bash
sudo chmod +x /usr/local/bin/nvim
```

## Priorizar un binario sobre otro

Cuando tenemos varios binarios con el mismo nombre, la shell tiene que determinar cuál ejecutar.
Para ello, busca el comando en las distintas ubicaciones de su `PATH`, siguiendo el orden en el que
aparecen.

Por ejemplo, si tenemos:

```text
/usr/bin/nvim
/usr/local/bin/nvim
```

y nuestro `PATH` contiene:

```text
/usr/local/bin:/usr/bin:...
```

entonces:

```bash
nvim
```

ejecutará:

```text
/usr/local/bin/nvim
```

porque `/usr/local/bin` aparece antes que `/usr/bin`.

### Identificar qué binario se está ejecutando

Podemos comprobar qué ejecutable se utilizará con:

```bash
command -v nvim
```

que devolverá la primera coincidencia:

```text
/usr/local/bin/nvim
```

También podemos utilizar:

```bash
type -a nvim
```

que muestra todas las coincidencias encontradas:

```text
nvim is /usr/local/bin/nvim
nvim is /usr/bin/nvim
```

Esto resulta especialmente útil cuando queremos comprobar qué versión tiene prioridad y cuáles
otras versiones están disponibles.

### Resolver la prioridad

Para hacer que un binario tenga preferencia sobre otro tenemos dos opciones:

1. **Colocar el binario o su _wrapper_ en una ubicación que ya aparezca antes en el `PATH`.**
2. **Modificar el `PATH` para que la ubicación deseada tenga mayor prioridad.**

La primera opción suele ser preferible cuando tenemos una ubicación adecuada que ya tiene
prioridad.

Por ejemplo, si queremos que una instalación manual de Neovim tenga preferencia sobre la versión
proporcionada por la distribución:

```text
/usr/local/bin/nvim  ← versión que queremos utilizar
/usr/bin/nvim        ← versión del sistema
```

y `/usr/local/bin` ya aparece antes que `/usr/bin` en el `PATH`, no necesitamos modificar la
configuración de la shell.

Si no disponemos de una ubicación adecuada, podemos modificar el `PATH` para colocar la ubicación
deseada antes que las demás.

> [!IMPORTANT]
>
> No es necesario eliminar ni sobrescribir el binario original. Mientras existan varias
> versiones, el orden del `PATH` determina cuál se ejecuta cuando escribimos el comando sin
> especificar una ruta completa.

Después de modificar el `PATH`, si la shell tenía información almacenada sobre la ubicación
anterior del comando, puede ser necesario limpiar su caché:

```bash
hash -r
```

En Bash y shells compatibles, o simplemente abrir una nueva sesión de shell.
