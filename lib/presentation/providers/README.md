# presentation/providers

Riverpodの Provider / Notifier を置く。`watch`は値の変化に応じてUIを再描画したい場合、
`read`はボタンタップ等イベント時に1回だけ呼ぶ場合に使う。`build()`内で`read`は使わない。
