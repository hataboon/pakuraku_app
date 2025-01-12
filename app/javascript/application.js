// app/javascript/application.js

// 基本的なインポート
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"

// Stimulusの初期化
const application = Application.start()

// 必要なコントローラーのインポート
import "./controllers"
import "./packs/calendar"

// DOMContentLoadedとTurbo関連のイベントリスナー
document.addEventListener("turbo:load", () => {
  console.log("Turbo load completed");
});

document.addEventListener("DOMContentLoaded", () => {
  console.log("DOM読み込み完了");

  // データ属性を使用したリンクの処理
  document.querySelectorAll('a[data-turbo-method]').forEach(link => {
    console.log("Turboリンク発見:", link);
    link.removeEventListener("click", handleClick);
    link.addEventListener("click", handleClick);
  });
});

function handleClick(e) {
  console.log("リンクがクリックされました", e.target);
  // 必要に応じてイベントの処理を追加
}

// Turboのデバッグモード（開発時のみ）
if (process.env.NODE_ENV === 'development') {
  console.log("Development mode: Turbo debugging enabled");
}