// app/javascript/application.js
import "@hotwired/turbo-rails"
import "./controllers"
import "./packs/calendar"

// Turboの明示的な初期化
document.addEventListener("DOMContentLoaded", () => {
  console.log("DOM読み込み完了");

  document.querySelectorAll('a[data-turbo-method]').forEach(link => {
    console.log("Turboリンク発見:", link);
    link.removeEventListener("click", handleClick);
    link.addEventListener("click", handleClick);
  });
});

function handleClick(e) {
  console.log("リンクがクリックされました", e.target);
}
