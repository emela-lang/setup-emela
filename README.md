# setup-emela

GitHub Actions で Emela のコンパイラを入れ，`PATH` に足す．

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: emela-lang/setup-emela@v1
    with:
      version: 0.24.0
  - run: emela pome install
  - run: emela test
```

## 入力

| 名前 | 既定 | 内容 |
|---|---|---|
| `version` | `latest` | 入れる版．`0.24.0` と `v0.24.0` のどちらでもよい．`latest` は最新の安定版 |
| `playground` | `false` | `true` なら，同じリリースのブラウザ用コンパイラ（Playground の wasm）も取ってくる．0.28.0 以降 |

## 出力

| 名前 | 内容 |
|---|---|
| `version` | 入れた版（`0.24.0` の形） |
| `playground` | `playground: true` のとき，`emela_playground.js` と `emela_playground_bg.wasm` を置いたディレクトリ |

## ブラウザ用コンパイラ（playground）

`playground: true` で，リリースの `emela-playground-<tag>.tar.gz` を取ってくる．中身は wasm-bindgen（`--target web`）の出力で，`check`，`format`，`compile` を公開している．ブラウザで Emela を検査，整形，実行するサイト（docs.emela.dev の Playground など）のビルドで使う．

```yaml
steps:
  - uses: actions/checkout@v4
  - id: emela
    uses: emela-lang/setup-emela@v1
    with:
      version: 0.28.0
      playground: true
  - run: cp ${{ steps.emela.outputs.playground }}/* public/wasm/emela/
```

ブラウザ用コンパイラが入っているのは emela-lang/emela#615 より後のリリースだけ．それより前の版を指定すると失敗する．runner の OS には依らない．

## 対応する runner

- Linux の x64（`ubuntu-latest` など）
- macOS の ARM64（`macos-latest` など）
- Windows の x64（`windows-latest` など）．Windows のリリース物があるのは 0.28.0 以降

コンパイラの [リリース](https://github.com/emela-lang/emela/releases) のアーカイブ（Windows は zip，ほかは tarball）をそのまま使う．ほかの runner の版はリリースにないので，入れられない．

`emela run` と `emela test` は，ターゲットごとに次のものを使う．Action はどれも入れない．

| ターゲット | 使うもの |
|---|---|
| `js` | node（`actions/setup-node` で入れる） |
| `native` | C11 と POSIX.1-2008 のヘッダを持つ C コンパイラ（`cc`，または環境変数 `EMELA_CC`） |
| `wasm` | wasmtime 49 以降（または環境変数 `EMELA_WASMTIME`） |

ターゲット `c` は `native` の古い名前で，0.29 で無くなる．

## Pome.lock の更新（pome-lock）

`emela-lang/setup-emela/pome-lock` は，リポジトリにあるすべての `Pome.lock` について `emela pome install` を実行し，変わった lock を pull request のブランチに push する．

[Renovate](https://docs.renovatebot.com/) と組み合わせて使う．Renovate の preset [emela-lang/renovate-config](https://github.com/emela-lang/renovate-config) は `Pome.toml` の版を上げるが，`Pome.lock` の commit とハッシュは `emela pome` でしか作れない．この Action がその分を補う．

```yaml
name: Pome lock

on:
  pull_request:
    paths: ['**/Pome.toml']

jobs:
  lock:
    if: github.event.pull_request.user.login == 'renovate[bot]'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.head_ref }}
          persist-credentials: false
      - id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.APP_ID }}
          private-key: ${{ secrets.APP_PRIVATE_KEY }}
      - uses: emela-lang/setup-emela/pome-lock@v1
        with:
          token: ${{ steps.app-token.outputs.token }}
          author-name: my-app[bot]
          author-email: 12345+my-app[bot]@users.noreply.github.com
```

checkout は pull request のブランチ（`ref: ${{ github.head_ref }}`）にする．既定の checkout は merge commit なので，この Action は止まる．

`GITHUB_TOKEN` で push すると，ほかの workflow が動かず CI がやり直されない．GitHub App の token か personal access token を渡す．

Renovate は，ほかの人が commit したブランチを rebase しなくなる．commit の author を Renovate の設定 `gitIgnoredAuthors` に書いておくと，rebase を続ける．

```json
{
  "extends": ["config:recommended", "github>emela-lang/renovate-config"],
  "gitIgnoredAuthors": ["12345+my-app[bot]@users.noreply.github.com"]
}
```

### 入力

| 名前 | 既定 | 内容 |
|---|---|---|
| `token` | （必須） | ブランチに push できる token |
| `version` | `latest` | 実行する emela の版 |
| `author-name` | `github-actions[bot]` | commit の author の名前 |
| `author-email` | `41898282+github-actions[bot]@users.noreply.github.com` | commit の author のメールアドレス |

### 出力

| 名前 | 内容 |
|---|---|
| `changed` | lock が変わって push したら `true` |

## ライセンス

Apache License 2.0
