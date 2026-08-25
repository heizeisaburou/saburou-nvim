# Go

Volver a [README.md](/README.md)  
<https://go.dev/>

## Brief

Go es un lenguaje de programación compilado, desarrollado por Google, diseñado para
ser sencillo, eficiente y especialmente adecuado para aplicaciones de sistemas y
servicios.

Muchas de las herramientas de linting y formateo que no están activadas por defecto
en esta configuración están desarrolladas en Go o requieren Go para funcionar.

## Installation

### Windows

Puedes instalar Go mediante `winget`:

```powershell
winget install GoLang.Go
```

Comprueba la instalación con:

```powershell
go version
```

### Linux

Instala el paquete `go` mediante el gestor de paquetes de tu distribución.

Comprueba la instalación con:

```sh
go version
```

#### Arch Linux

```sh
sudo pacman -S --needed go
```

```sh
sudo apt install -y golang-go
```

### macOS

Puedes instalar Go mediante Homebrew:

```sh
brew install go
```

Comprueba la instalación con:

```sh
go version
```

El resto de la configuración es igual que en Linux y Windows.

## Activation

- [lua/lzy/conform.lua](/lua/lzy/conform.lua) ― descomenta:

	- `go = { "gofmt" }`
	- `gotmpl = { "prettier_gotmpl" }`

- [lua/lzy/treesitter.lua](/lua/lzy/treesitter.lua) ― descomenta:

	- `"go"`
	- `"gomod"`
	- `"gosum"`
	- `"gotmpl"`
	- `"gowork"`

- [lua/lzy/lspconfig.lua](/lua/lzy/lspconfig.lua) ― descomenta `gopls`.
