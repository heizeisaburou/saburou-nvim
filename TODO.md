# Prioridad Alta

- Configurar C++, C, Rust, GO, Ruby, Flask
- Control + n para abrir el cmp en el modo insert. He probado CTRL+N pero se abre una ventana de cmp distinta
  (Probar también a usar CTRL+q para ver si es cómodo, pero asegurate de comprobar que real mente CTRL+Q es lo
  mismo que CTRL+V -> No es necesario CTRL+Q original)

# Prioridad Media

- Configurar DAP.
- Refactorizar
  - Cuidado con los require de configs cuyo archivo se llama igual que el require del plugin. Poner nombres
    distintos.
  - Unificar las configuraciones para que todas utilicen un modulo y permitan reconfigurar opts.
- Crear plugin de reporte de errores (estilo diagnostico de líneas) que combine las funcionalidades del
  diagnostico de líneas y del plugin de lsp-lines ya que lsp-lines lleva 3-4 años sin actualizarse y genera
  problemas. (De momento se puede activar/desactivar con `<leader>lv`
- Posibilidad de activar líneas en nvim.

# Prioridad Baja

- Crear software de sumas/restas para no depender de columnas con posiciones relativas.
  - (de paso) de multiplicaciones
- Configurar: render-markdown.nvim
- Configurar: obsidian.nvim
- Configurar: menús personalizados de base46/ui.
- Ver como hace snacks.nvim para mostrar imágenes, y ver la compatibilidad con archinstall.
- Reemplazar barbar por tabufline (el sistema original, en cuanto sea posible).
- Permitir de alguna manera cargar los paths de nvim (paths en lua_ls)solo cuándo se tengan que utilizar.
- Preparar `ansible` para poder instalar rápidamente esta configuración por ssh a máquinas virtuales.
- Crear método para indicar el ROOT para ciertos lenguajes ahí donde sea complicado hacerlo.
