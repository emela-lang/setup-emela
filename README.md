# setup-emela

GitHub Actions で Emela のコンパイラを入れ，`PATH` に足す．

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: emela-lang/setup-emela@v1
    with:
      version: 0.22.0
  - run: emela pome install
  - run: emela test
```

## 入力

| 名前 | 既定 | 内容 |
|---|---|---|
| `version` | `latest` | 入れる版．`0.22.0` と `v0.22.0` のどちらでもよい．`latest` は最新の安定版 |

## 出力

| 名前 | 内容 |
|---|---|
| `version` | 入れた版（`0.22.0` の形） |

## 対応する runner

- Linux の x64（`ubuntu-latest` など）
- macOS の ARM64（`macos-latest` など）

コンパイラの [リリース](https://github.com/emela-lang/emela/releases) の tarball をそのまま使う．ほかの runner の版はリリースにないので，入れられない．

`emela run` と `emela test` の JS ターゲットは node を，C ターゲットは C コンパイラを使う．node は `actions/setup-node` で入れる．

## ライセンス

Apache License 2.0
