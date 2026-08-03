# Comprobación de Conform y los ignores de Prettier

## Problema observado

El archivo
`/rin/act/cod/anki_related/kizuna-core/.reference/docs/yomidict-loader-plan.md`
no cambiaba al ejecutar `Alt+F`, pero la copia en
`~/.config/nvim/.mine/docs/yomidict-loader-plan.md` sí se formateaba. No aparecía
ningún error.

La causa era `/.reference` en el `.gitignore` de `kizuna-core`. Desde Prettier 3,
el CLI consulta `.gitignore` además de `.prettierignore`. Con el archivo original:

```text
prettier --file-info yomidict-loader-plan.md
{ "ignored": true, "inferredParser": null }
```

Al procesar por `stdin`, Prettier devolvía el mismo texto y código de salida cero.
Conform recibía un resultado válido sin cambios, de modo que no existía un error
que pudiera notificar.

La presencia simultánea de dos clientes Marksman, uno con raíz `kizuna-core` y
otro con raíz `~/.config/nvim`, es normal y no interviene en este comportamiento.

## Solución aplicada

- El formatter `prettier` recibe un `--ignore-path` explícito.
- Se usa el `.prettierignore` más cercano al archivo o `/dev/null` cuando no
  existe ninguno. Esto reemplaza los ignores predeterminados del CLI y evita que
  `.gitignore` cancele el formateo manual.
- `Alt+F` y `<leader>fm` notifican si el formato se aplicó, no produjo cambios o
  falló. El callback muestra el error concreto.
- Conform configura `log_level = vim.log.levels.DEBUG` mediante su API actual;
  el antiguo `vim.g.conform_log_level` no era leído por la versión instalada.

## Cómo revisarlo después

1. Abrir Neovim desde la raíz de `kizuna-core`.
2. Abrir `.reference/docs/yomidict-loader-plan.md`.
3. Introducir temporalmente una diferencia inequívoca de formato, por ejemplo
   varios espacios entre palabras de un párrafo.
4. Ejecutar `Alt+F` y comprobar que el texto cambia y aparece `Formato aplicado`.
5. Ejecutarlo de nuevo y comprobar el mensaje `Sin cambios`.
6. Ejecutar `:ConformInfo` y confirmar que `prettier` y `markdown_tabs` están
   disponibles y que el log contiene la invocación.
7. Crear temporalmente un `.prettierignore` que excluya el archivo y confirmar
   que esa exclusión específica de Prettier sigue respetándose; el mensaje de
   `Sin cambios` menciona también esta posibilidad.

No confundir esta prueba con el contador `Attached buffers` de `:LspInfo`: ese
contador pertenece al cliente LSP y no determina si Conform o Prettier procesan
el buffer.
