# saburou-nvim

Notas del proyecto — [Neovim](neovim.md)

## Estado

- Versión de Neovim: 0.12+.
- Versión de saburou-nvim: 0.1.0-alpha.8.
- Desarrollo funcional de la alpha: terminado.
- Validación pendiente: Windows 11.

Esta configuración queda congelada salvo correcciones de errores o de seguridad. La siguiente etapa no continuará
añadiendo capas sobre la arquitectura actual: volverá a partir de una base limpia, pequeña y explícita.

## Motivo de la reconstrucción

La alpha comenzó buscando mucha capacidad de configuración. Esa flexibilidad obligó a crear adaptadores y estados
intermedios antes de saber qué decisiones eran realmente variables. Con el tiempo, comprender una función empezó a
exigir conocer detalles de varios plugins y sistemas a la vez.

Los casos más claros son la persistencia durante el reinicio, la reordenación de buffers y el tema. Funcionan, pero su
comportamiento está distribuido entre parches e integraciones que se condicionan mutuamente. La reconstrucción fijará
primero los comportamientos invariables y sólo expondrá opciones que tengan un caso de uso demostrado.

## Core previsto

### Estado y persistencia

- Un almacén con tipos y formato versionado.
- Ciclo de vida explícito: consulta, escritura, restauración y descarte.
- Persistencia completa del estado elegido, no parches independientes durante el reinicio.
- Migraciones o rechazo claro cuando un estado antiguo sea incompatible.

### Buffers y MRU

- Un único modelo para historial, orden y selección de buffers.
- Comportamiento definido para abrir, cerrar, guardar, recargar y reemplazar buffers.
- MRU propio, actualizado desde el inicio de Neovim y utilizable por el resto del core.
- Eliminación del hardcode necesario actualmente para reordenar `bufferline`.

### Temas

- Sistema propio de paletas, variantes e integraciones.
- Temas cerrados y coherentes en lugar de combinaciones arbitrarias.
- Separación entre estado visual, configuración funcional y adaptadores de plugins.
- Integración del tema con la persistencia sin acoplarla al mecanismo de reinicio.

### Plugins

- Eliminación de `lua/lzy/plg.lua`.
- Una especificación por archivo junto a su carga y configuración.
- Dependencias y relaciones visibles, sin registros centralizados difíciles de recorrer.

### LSP, formatters e indentación

- Responsabilidades explícitas para Neovim, Mason, LSP y Conform.
- Perfiles por lenguaje que definan servidor, formatter y política de indentación.
- Sustitución del sistema actual de indentación por una fuente más sencilla de mantener.
- Comportamiento equivalente de rutas, ejecutables y argumentos en Linux y Windows.

## Condiciones de calidad

- Pruebas pequeñas sobre las invariantes del core: persistencia, orden de buffers, MRU, rutas y procesos.
- Sin abstracciones anticipadas: los adaptadores se incorporan después del comportamiento principal.
- Errores explícitos cuando no se pueda restaurar estado o resolver una herramienta.
- Windows 11 tratado como plataforma real, no como compatibilidad inferida desde Linux.

El resto —selección concreta de plugins, keymaps y detalles visuales— es intercambiable. Debe apoyarse en este núcleo y
no determinar su diseño.
