WSL の Ubuntu に Python 3.14 と `venv` 用パッケージをインストールし、仮想環境を作成して `pip install` する一連のコマンドは以下の通りです。

### 1. Python 3.14 と venv のインストール

Ubuntu の標準リポジトリに Python 3.14 が含まれていない場合は、`deadsnakes` PPA を追加してインストールします。

```bash
# パッケージリストの更新とPPA追加ツールの導入
sudo apt update && sudo apt install -y software-properties-common

# deadsnakes PPA の追加
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update

# Python 3.14 本体と venv モジュールのインストール
sudo apt install -y python3.14 python3.14-venv

```

※ インストール完了後、`python3.14 --version` を実行して `Python 3.14.x` と表示されれば成功です。

---

### 2. 仮想環境 (venv) の作成と有効化

プロジェクト用のディレクトリに移動してから実行してください。

```bash
# 仮想環境の作成（フォルダ名は任意。ここでは .venv）
python3.14 -m venv .venv

# 仮想環境の有効化
source .venv/bin/activate

```

※ ターミナルのプロンプトの先頭に `(.venv)` と表示されれば有効化されています。

---

### 3. pip の更新とパッケージのインストール

仮想環境が有効な状態で `pip` を実行します（この状態では `pip` コマンドが自動的に Python 3.14 用のものになります）。

```bash
# pip 自体を最新化（推奨）
pip install --upgrade pip

# 任意のパッケージをインストール（例: requests）
pip install パッケージ名

```
