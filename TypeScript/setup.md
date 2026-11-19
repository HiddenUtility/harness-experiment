
## node 環境

### インストール

```bash
sudo apt install nodejs
```

### 1. まず nvm が入っているか確認

```bash
command -v nvm
```

`nvm` と表示されれば、次の手順に進みます。

### 2. nvm がない場合はインストール

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | bash
```

インストール後、設定を読み込みます。

```bash
source ~/.bashrc
```

確認します。

```bash
nvm --version
```

### 3. Node.js を更新

#### 最新の LTS 版をインストールする場合

```bash
# インストール
nvm install --lts
# ltsに切り替え
nvm use --lts
# 確認
nvm alias default 'lts/*'
```

#### nmp 用に prox 設定が必要な場合

```bash
npm config set proxy http://ユーザー名:パスワード@proxy.example.co.jp:8080
npm config set https-proxy http://ユーザー名:パスワード@proxy.example.co.jp:8080
```

確認

```bash
npm config get proxy
npm config get https-proxy
```
