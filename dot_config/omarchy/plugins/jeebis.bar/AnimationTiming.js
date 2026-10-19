.pragma library

// カスタムバーの演出時間。単位はすべてミリ秒（1000 ms = 1秒）。
// グループは演出、プロパティ名はフェーズを表す。
// Object.freeze により実行中の書き換えを防ぐ。調整はこのファイルで行う。
// 編集後は `omarchy restart shell` で全ウィジェットを再読み込みする。

var centerCompanions = Object.freeze({
  // ワークスペース島が隠れている間、Agent/App島を中央へ寄せ、もう一方が現れたら左右へ退く。
  movingMs: 240
})

var appIsland = Object.freeze({
  // アプリ島がワークスペース島側から右へ流れ、幅と不透明度を増して現れる。
  enteringMs: 240,
  // アプリ島がワークスペース島側（左）へ戻りながら縮小して隠れる。
  leavingMs: 240,
  // 通常のアイコン数変更に合わせて島の幅を変える。
  resizingMs: 180,
  // 通常のワークスペース選択・ウィンドウ変更後に表示を保つ。
  presentMs: 2000,
  // カーソルがアプリ島とワークスペース島を離れてから隠し始める猶予。
  releasingMs: 150
})

var appArrival = Object.freeze({
  // 既存アプリがある場合、新規アプリを除いたアプリ島を先に表示する。空なら省略。
  preparingMs: 240,
  // 右側の独立島がフェード・移動しながら現れる。
  enteringMs: 240,
  // 完全に現れた独立島を表示し続ける。
  presentMs: 240,
  // 既存島へ合流する。受け皿が空の場合は独立島だけが通常位置へ移動する。
  joiningMs: 320,
  // 合流完了後にアプリ島を表示し続ける。
  settledMs: 1000
})

var appDeparture = Object.freeze({
  // 閉じるアイコンを右端へ並べ替える。連続終了時も移動完了後に順番に分離する。
  reorderingMs: 320,
  // 閉じたアプリのアイコンを含むアプリ島を、分離前に表示する。
  preparingMs: 400,
  // 閉じたアイコンがアプリ島から右へ分離する。島の幅変更も同期する。
  separatingMs: 320,
  // 分離した独立島が縮小・フェードアウトする。
  leavingMs: 240,
  // 分離・消滅後に残ったアプリ島を表示し続ける。
  settledMs: 1000
})

var agentIsland = Object.freeze({
  // Agentアイコンの島がワークスペース島側から左へ流れて現れる。
  enteringMs: 240,
  // Agentアイコンの島がワークスペース島側（右）へ戻りながら縮小して隠れる。
  leavingMs: 240,
  // 起動演出を伴わないワークスペース選択などでAgent島を表示する。
  presentMs: 2000,
  // Agent島・ワークスペース島からカーソルが離れた後の猶予。
  releasingMs: 100,
  // 使用量メニューを閉じ、カーソル判定がバーへ戻るまで表示を保つ。
  returningMs: 150
})

var agentActivity = Object.freeze({
  // 起動・終了時、展開したボタンを色変更前の状態で表示する。
  preparingMs: 400,
  // ChatGPT/Codexボタンの文字色を未起動色と起動中色の間で変える。
  changingMs: 400,
  // 変更後の文字色を表示し続ける。
  presentMs: 600,
  // ChatGPT/CodexボタンをAgentアイコンの左へ展開する。
  expandingMs: 240,
  // ChatGPT/CodexボタンをAgentアイコンへ収納する。
  collapsingMs: 240,
  // ボタン収納後、Agentアイコンだけを表示し続ける。
  settledMs: 240,
  // ボタン列からカーソルが離れてから収納を始める猶予。
  releasingMs: 150
})

var workspaceIsland = Object.freeze({
  // ワークスペース島が形を保ったまま画面上端から下りて現れる。
  enteringMs: 240,
  // ワークスペース島が形を保ったまま画面上端へ戻って隠れる。
  leavingMs: 240,
  // ドット数の増減に合わせて島の幅・高さを変える。
  resizingMs: 220
})

var workspaceActivity = Object.freeze({
  // 処理中スピナーを次のコマへ進める間隔。
  cyclingMs: 90,
  // ウィンドウ起動後のスピナー表示を保つ。
  settlingMs: 1800
})

var notificationIsland = Object.freeze({
  // 未読通知の島が現れる。
  enteringMs: 240,
  // 未読がなくなった通知の島が隠れる。
  leavingMs: 240
})

var notificationClear = Object.freeze({
  // ホバー・通知表示時に「すべて既読」ボタンを展開する。
  enteringMs: 180,
  // ホバー・通知表示が終わり「すべて既読」ボタンを収納する。
  leavingMs: 180
})

var notificationHistory = Object.freeze({
  // 通知を開いたとき、履歴ボタンを展開する。
  enteringMs: 180,
  // 通知を閉じたとき、履歴ボタンを収納する。
  leavingMs: 180
})

var loadIsland = Object.freeze({
  // 高負荷の項目が発生して情報島が現れる。
  enteringMs: 240,
  // 高負荷が解消して情報島が隠れる。
  leavingMs: 240,
  // 表示する負荷項目数の変化に合わせて幅を変える。
  resizingMs: 180
})

var themeTransition = Object.freeze({
  // テーマ切り替え時にバーの文字・背景・強調色を変える。
  changingMs: 420
})

var panelSelection = Object.freeze({
  // 開いたメニューに対応するアイコンの下線を表示する。
  enteringMs: 120,
  // メニューを閉じ、下線を隠す。
  leavingMs: 120
})

var barInteraction = Object.freeze({
  // 中央セクションのホバー表示を解除するまでの猶予。
  releasingMs: 120
})

var tooltip = Object.freeze({
  // カーソルを合わせてからツールチップを出すまで待つ。
  preparingMs: 400,
  // カーソル離脱時にツールチップを閉じるための確認間隔。
  releasingMs: 100
})

var edgePreview = Object.freeze({
  // バー配置先のプレビューを切り替えるフェード。
  changingMs: 140
})

var activeWindow = Object.freeze({
  // アクティブウィンドウのタイトル長に合わせて幅を変える。
  resizingMs: 180
})

var trayDrawer = Object.freeze({
  // トレイの引き出しを展開・収納する。
  changingMs: 600
})

var powerMessage = Object.freeze({
  // 充電状態の説明文を次の文へ切り替えるまで表示する。
  presentMs: 2800,
  // 現在の充電説明文をフェードアウトする。
  leavingMs: 180,
  // 次の充電説明文をフェードインする。
  enteringMs: 260
})

var powerStatus = Object.freeze({
  // 電源パネルのアイコンと残量の色を変える。
  changingMs: 200
})

var powerGauge = Object.freeze({
  // 電源パネルのバッテリー残量バーの長さを変える。
  resizingMs: 320,
  // バッテリー残量バーの色を変える。
  changingMs: 220,
  // 充電中の残量バーを暗くする半周期。
  dimmingMs: 950,
  // 充電中の残量バーを明るくする半周期。
  brighteningMs: 950
})

var calendarProgress = Object.freeze({
  // カレンダーパネルの日・年の進捗バーの長さを変える。
  changingMs: 160
})
