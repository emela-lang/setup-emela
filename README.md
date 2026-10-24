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

## 出力

| 名前 | 内容 |
|---|---|
| `version` | 入れた版（`0.24.0` の形） |

## 対応する runner

- Linux の x64（`ubuntu-latest` など）
- macOS の ARM64（`macos-latest` など）

コンパイラの [リリース](https://github.com/emela-lang/emela/releases) の tarball をそのまま使う．ほかの runner の版はリリースにないので，入れられない．

`emela run` と `emela test` の JS ターゲットは node を，C ターゲットは C コンパイラを使う．node は `actions/setup-node` で入れる．

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
