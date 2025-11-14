# comm-gnome-theme-everforest

Everforest Medium Dark é um tema GNOME inspirado no esquema de cores Everforest, incluindo temas GTK3/GTK4, assets para libadwaita e um wallpaper HEIC exclusivo. Este repositório empacota a versão personalizada usada pela comunidade BigLinux.

## O que está incluído
- Build automatizado do repositório upstream [Fausto-Korpsvart/Everforest-GTK-Theme](https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme) com tweaks `Dark + Medium`.
- Wallpaper `bokeh-small-plant.avif` em `/usr/share/backgrounds/comm-gnome-theme-everforest/`.
- Script auxiliar (`/usr/share/comm-gnome-theme-everforest/install.sh`) para aplicar, atualizar ou remover as personalizações por usuário.

## Dependências principais
- Runtime: `gtk3`, `gtk4`, `gnome-shell`, `gtk-engine-murrine`.
- Build: `git`, `sassc`.
- Opcional: `heif` para converter o wallpaper AVIF automaticamente ao aplicá-lo.

## Como usar o helper
Execute o script como o usuário da sessão gráfica (sem `sudo`). Ele afeta apenas os arquivos no `$HOME`.

### Aplicar (instalação inicial)
```bash
/usr/share/comm-gnome-theme-everforest/install.sh
```

### Atualizar após upgrade do pacote
```bash
/usr/share/comm-gnome-theme-everforest/install.sh --upgrade
```

### Remover personalizações
```bash
/usr/share/comm-gnome-theme-everforest/install.sh --uninstall
```

O helper cria backups de `~/.config/gtk-3.0/settings.ini` e `~/.config/gtk-4.0/settings.ini` antes de alterar qualquer coisa e restaura a última cópia durante a remoção.

### Opções disponíveis
```
--install, --apply   Aplica o tema (padrão)
--upgrade            Reaplica o tema após atualização do pacote
--uninstall, --remove
                     Remove configurações e restaura backups
--help               Mostra a ajuda
```

## Processo de build
O `PKGBUILD` baixa duas fontes:
1. `Everforest-GTK-Theme`: usado para compilar o tema com `themes/install.sh --dest "$srcdir/theme-build" --color dark --tweaks medium`.
2. Este repositório (`comm-gnome-theme-everforest`): contém o helper, wallpaper e documentação.

Durante `package()` são instalados:
- `/usr/share/themes/Everforest-Dark-Medium-B` com os arquivos gerados.
- `/usr/share/comm-gnome-theme-everforest/install.sh` (755).
- Documentação e licença em `/usr/share/doc` e `/usr/share/licenses`.
- Wallpapers em `/usr/share/backgrounds/comm-gnome-theme-everforest/`.

## Créditos
- Tema original: [Fausto-Korpsvart](https://github.com/Fausto-Korpsvart).
- Empacotamento BigLinux Community.
