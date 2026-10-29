# mpv config

Мой конфиг для [mpv](https://mpv.io).

## Установка

Linux / macOS:

```sh
git clone <repo-url> ~/.config/mpv
```

Windows:

```bat
git clone <repo-url> %APPDATA%\mpv
```

## Что внутри

- `mpv.conf`: встроенный OSC выключен (`osc=no`), вместо него ModernZ
- `input.conf`: громкость стрелками ↑/↓ (±5), `Ctrl+g` включает и выключает мягкий переход между файлами
- `scripts/modernz.lua` и `fonts/modernz-icons.ttf`: [ModernZ](https://github.com/Samillion/ModernZ) v0.3.3 (LGPL-2.1)
- `scripts/autoload.lua`: автозагрузка соседних файлов из папки в плейлист (из [mpv](https://github.com/mpv-player/mpv/tree/master/TOOLS/lua))
- `scripts/playlist-gap.lua` и `script-opts/playlist-gap.conf`: пауза с обратным отсчётом между файлами плейлиста
