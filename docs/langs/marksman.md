# marksman

## Sintaxis Wiki

Marksman permite utilizar dos estilos de sintaxis para los enlaces Wiki:

- `[[mi-nota]]` — utiliza el nombre del archivo como identificador.
- `[[Mi nota]]` — utiliza el _file stem_ como identificador.

Por defecto, Marksman utiliza el estilo `file-path`. Si prefieres utilizar `file-stem`, crea un
archivo `.marksman.toml` y configura:

```toml
[completion.wiki]
style = "file-stem"
```

Los valores disponibles para `style` son:

```text
file-path
file-stem
```
