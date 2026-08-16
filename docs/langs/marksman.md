# marksman

## Sintaxis Wiki

Hay dos formatos de Wiki:

- A) `[[mi-nota]]`
- B) `[[Mi nota]]`

Por defecto se utiliza A, si quieres utilizar B) entonces tienes que crear un `.marksman.toml` y
modificar la siguiente clave:

```toml
[completion.wiki]
style = "file-stem"     # -> [[Mi Nota]]
```
