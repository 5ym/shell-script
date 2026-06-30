#!/bin/sh

sudo dnf install -y fish

# ユーザーのデフォルトシェルを fish に変更（root を巻き込まない）
chsh -s /usr/bin/fish $USER

# starship インストール
curl -sS https://starship.rs/install.sh | sh

# fish の設定ディレクトリを確実に作成
mkdir -p ~/.config/fish

# starship を fish に読み込ませる
echo "starship init fish | source" >> ~/.config/fish/config.fish
