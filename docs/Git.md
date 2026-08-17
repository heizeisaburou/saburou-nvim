# Git

Volver a [README.md](/README.md)  
<https://git-scm.com/>

## Brief

Git es el sistema de control de versiones distribuido: guarda el historial de un proyecto en
_commits_ y permite trabajar con ramas y remotos.

Esta nota solo cubre cómo instalarlo, en Windows y Linux; para macOS remite a [macOS support](/docs/macOS%20support.md).

## Installation

### Windows

#### Using winget

```powershell
winget install Git.Git
```

### Linux

En todas las distribuciones de Linux que conozco el paquete se llama `git`.

### macOS

```sh
brew install git
```

### macOS

Git se incluye en las **Xcode Command Line Tools** y después es recomendable instalarlo en el paso
[Compilador de C#macOS](/docs/Compilador%20de%20C.md#macos), así que recomiendo instalarlo:

```sh
xcode-select --install
```

También puedes instalar Git mediante Homebrew:

```sh
brew install git
```

Comprueba la versión de git:

```sh
git version
```
