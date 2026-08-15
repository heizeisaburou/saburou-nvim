# Mio

Este archivo es porque Codex se aproxima a los limites y voy a cambiar a ti claude. Le he hecho
este prompt y me ha dado lo que hay en [[#Esto]]

› Vale si lo entiendo y por eso estoy instalando Windows. Lo obvio es lo obvio, para probar X
cosas de Windows/Microsoft estamos obligados a tener un Windows. Todo bien, la cosa es, si el
usuario lo tiene tiene una manera fácil de decir "Este proyecto es un proyecto de 5.1, y quiero
que se reconozca como tal" tal vez porque es un proyecto antiguo que quiere recuperar o usar como
tal no? A esto me refiero, a sí podemos hacer algo por el usuario.

Y también incluye a si podemos hacer algo para que en ese proyecto A-i que abre una terminal y
A-v y A-v (en cfg.lua están) se abra la shell correcta y quede todo congruente o no deberíamos
meternos ahí, etc. Tu explicame que podemos hacer y entonces te digo haz X y empezamos.

Lo que quiero es que organices este archivo (deja esto limpio para ti y para mi), y luego que
revises la decisión y lo que ha propuesto a ver si está todo okay para proceder, puedes modificar
la propuesta.

También revisa next-languages.md que es el plan general pero no empieces a instalar todos los
lenguajes. Avanzamos poco a poco.

# Esto

• Sí, podemos darle al usuario una forma sencilla y coherente. Mi recomendación es hacerlo
mediante una convención explícita del proyecto, porque PowerShell no tiene un archivo estándar
equivalente a .python-version o global.json.

## Propuesta

Un archivo versionable en la raíz:

.powershell-version

Para Windows PowerShell:

5.1

Para PowerShell moderno:

7

Este archivo sería una convención de nuestra configuración, no de Microsoft. Tiene varias
ventajas:

- Es trivial de crear y leer.
- No ejecutamos código procedente del proyecto.
- Funciona aunque el proyecto no sea un módulo.
- No depende de VS Code.
- Puede gobernar LSP, análisis y terminal desde una sola fuente.

El proyecto seguiría incluyendo los mecanismos estándar:

.powershell-version PSScriptAnalyzerSettings.psd1 Modulo.psd1 Modulo.psm1 scripts/*.ps1

El marcador gobierna el editor; #Requires, el manifiesto y PSScriptAnalyzer hacen que el proyecto
también se describa correctamente fuera de Neovim.

## Qué controlaría

.powershell-version LSP en Windows Terminales integradas Análisis ━━━━━━━━━━━━━━━━━━━━━
━━━━━━━━━━━━━━━━━━━━ ━━━━━━━━━━━━━━━━━━━━━━━ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 5.1 powershell.exe
powershell.exe Compatibilidad con 5.1 ───────────────────── ────────────────────
─────────────────────── ──────────────────────────── 7 pwsh.exe pwsh.exe Compatibilidad con 7.x
───────────────────── ──────────────────── ─────────────────────── ────────────────────────────
No existe Preferencia global windows_shell=auto Comportamiento por defecto

El mismo resolver sería utilizado por PowerShell Editor Services y por las terminales. Así
evitamos que cada componente interprete el proyecto de manera diferente.

Además:

- En un proyecto 5.1, PSScriptAnalyzerSettings.psd1 apuntaría a sintaxis y comandos de 5.1.
- Los scripts podrían declarar:

#Requires -Version 5.1 #Requires -PSEdition Desktop

- El módulo declararía PowerShellVersion = '5.1' y CompatiblePSEditions = @('Desktop').

Estas declaraciones son mecanismos oficiales; el archivo .powershell-version sería únicamente
nuestra capa de coordinación. PSScriptAnalyzer permite elegir versiones objetivo
(https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/rules/usecompatiblesyntax)
y #Requires controla versión y edición
(https://learn.microsoft.com/powershell/module/Microsoft.PowerShell.Core/about/about_requires?view=powershell-5.1).

## Las terminales A-i, A-v y A-b

Actualmente:

- A-i abre la terminal flotante.
- A-v abre la vertical.
- A-b abre la horizontal.
- Las tres usan una shell decidida globalmente al iniciar Neovim.
- Cada tipo conserva su propio proceso y lo reutiliza aunque después cambies de proyecto.
- No arrancan explícitamente en la raíz del proyecto.

Esto está en lua/user/cfg.lua:168 y lua/sabunv/terminal.lua:168.

Creo que sí debemos integrarlas, pero solo cuando el proyecto lo solicite explícitamente mediante
el marcador. Abrir cualquier .ps1 suelto no debería cambiarte la terminal.

El comportamiento adecuado sería:

1. Resolver el proyecto desde el buffer actual.
2. Buscar .powershell-version.
3. Elegir powershell.exe o pwsh.exe.
4. Arrancar la terminal con cwd igual a la raíz del proyecto.
5. Mantener terminales separadas por proyecto, para no reutilizar una sesión 7 dentro de un
   proyecto 5.1.
6. Fuera de proyectos marcados, conservar exactamente el comportamiento actual.

No modificaría vim.o.shell: :!, :make y otros plugins seguirían usando la shell normal de Neovim.

## Ejecutables ausentes

En un proyecto declarado explícitamente no conviene hacer fallback silencioso:

- Proyecto 5.1 sin powershell.exe: mostrar error claro.
- Proyecto 7 sin pwsh.exe: mostrar error claro.
- Proyecto sin marcador: mantener el fallback global actual.

En Linux, un proyecto marcado como 5.1 podría conservar análisis estático ejecutando Editor
Services sobre pwsh, pero debería avisar que no es ejecución real. Las terminales no deberían
fingir ser 5.1.

También sería útil ampliar :TerminalInfo o crear :PowerShellInfo:

raíz: C:\proyectos\legacy objetivo: Windows PowerShell 5.1 LSP host: powershell.exe terminal:
powershell.exe analyzer: PSScriptAnalyzerSettings.psd1

Esta es la opción que implementaría: marcador explícito, resolver compartido y terminales por
proyecto. No he realizado cambios todavía.
