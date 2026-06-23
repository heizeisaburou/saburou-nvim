# saburou-nvim

Notas del proyecto — [Neovim](neovim.md)

## Brief

Versión Neovim (testeada): 0.12+
Versión de saburou-nvim: 0.1.0-alpha.3

## TODOs

### TODO Configuración

- Elegir componentes **CORE** de nuestra configuración, que sean inamovibles con el fin de evitar tener que crear
  adaptadores desde el principio. Los adaptadores deberían llegar al final.

- Sistema de persistencia simple basado en un diccionario de variable con consulta, escritura, y reconocimiento de
  tipos.

- Terminal: Al redimensionar la ventana de nvim debería redimensionarse la terminal de ALT+I también, ya que si la
  terminal era muy baja, entonces la terminal queda muy baja también.

- Sistema de MRU completo que se refresque desde el momento en el que se abre Neovim ya que es necesario para un
  correcto funcionamiento de sistemas como reload etc.

- Sistema para que al abrir un nuevo archivo te permita elegir donde lo quieres mostrar si hay más de una ventana
  normal.
  - Hacer que no colisione recursivamente con `nvim-tree` claro.

- Sistema de guardado/cerrado:
  - Guardar todo no debería pedir confirmación por defecto.

- Sistema de temas:
  - Crear un sistema de temas propio que incluya todos nuestros componentes core. Sin alternativas, cada tema es
    independiente —transparente, roja, azul, y la clara la dejamos para un futuro—
  - Crear un tema propio idéntico al que ya tenemos, pulido, con variante roja y azul, y transparente de ambas.

- Zoom in/out del buffer actual.

- Adaptadores / Integraciones:
  - Crear un sistema centralizado para elegir el `indent` y `tab-width` en medida de lo posible que unifique los flags
    de neovim con conform.

  - Crear un adaptador para `qmlformat` en conform que permita formatear qml tanto en Windows como en Linux.

#### Arreglo de bugs y/o mejoras leves

- `:Luarc` trata de *generar* `.luarc.json` en `~/.config/nvim` incluso si la `NVIM_APPNAME` != `nvim`.
- Volver a meter en `todo-comments` la necesidad de prefijar las tags con `:` de alguna manera: `TODO:` > `:TODO:`.
- Keybind para buscar en la configuración `<leader>fc`.

### TODO No Configuración

- Anotar todas las dependencias reales utilizando máquinas virtuales para probar la configuración desde sistemas base.

- Hacer una guía completa de instalación y configuración para tanto Windows como Linux, y pedir donaciones específicas
  para dar soporte a macOS, Android, iOS, utilizando VPS con entorno gráfico que cuestan como `20$-30$` al mes.

- Guía de uso unificada bajo las mismas condiciones.
