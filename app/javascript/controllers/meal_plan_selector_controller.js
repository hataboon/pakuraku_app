// app/javascript/controllers/meal_plan_selector_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    id: Number
  }
  
  connect() {
    console.log("献立再利用コントローラーが接続されました")
  }
  
  // 献立を再利用する処理
  reuse(event) {
    event.preventDefault()
    
    // モーダルを作成して日付選択UIを表示
    this.createDateSelectionModal()
  }
  
  createDateSelectionModal() {
    // モーダルの作成
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 bg-gray-800 bg-opacity-75 flex items-center justify-center z-50'
    
    // モーダルの内容
    modal.innerHTML = `
      <div class="bg-white rounded-lg shadow-xl max-w-md w-full p-6 relative">
        <h3 class="text-xl font-bold mb-4 text-gray-800">この献立を別の日付に再利用</h3>
        
        <form id="reuse-form" class="space-y-4">
          <div>
            <label for="reuse-date" class="block text-sm font-medium text-gray-700 mb-1">日付を選択</label>
            <input type="date" id="reuse-date" required
                   class="w-full rounded-md border-gray-300 shadow-sm focus:border-orange-500 focus:ring focus:ring-orange-200 focus:ring-opacity-50">
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">時間帯を選択</label>
            <div class="flex space-x-4">
              <label class="inline-flex items-center">
                <input type="radio" name="reuse-meal-time" value="morning" checked
                       class="text-orange-600 focus:ring-orange-500 h-4 w-4">
                <span class="ml-2 text-gray-700">朝食</span>
              </label>
              <label class="inline-flex items-center">
                <input type="radio" name="reuse-meal-time" value="afternoon"
                       class="text-orange-600 focus:ring-orange-500 h-4 w-4">
                <span class="ml-2 text-gray-700">昼食</span>
              </label>
              <label class="inline-flex items-center">
                <input type="radio" name="reuse-meal-time" value="evening"
                       class="text-orange-600 focus:ring-orange-500 h-4 w-4">
                <span class="ml-2 text-gray-700">夕食</span>
              </label>
            </div>
          </div>
          
          <div class="flex justify-end space-x-3 pt-2">
            <button type="button" id="cancel-reuse-btn"
                    class="px-4 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 transition-colors">
              キャンセル
            </button>
            <button type="submit" id="confirm-reuse-btn"
                    class="px-4 py-2 bg-orange-600 text-white rounded-md hover:bg-orange-700 transition-colors">
              この日に再利用する
            </button>
          </div>
        </form>
      </div>
    `
    
    // モーダルをDOMに追加
    document.body.appendChild(modal)
    
    // 今日の日付をデフォルト値に設定
    const dateInput = document.getElementById('reuse-date')
    const today = new Date()
    const formattedDate = today.toISOString().split('T')[0]
    dateInput.value = formattedDate
    
    // キャンセルボタンのイベント
    document.getElementById('cancel-reuse-btn').addEventListener('click', () => {
      document.body.removeChild(modal)
    })
    
    // フォーム送信のイベント処理
    document.getElementById('reuse-form').addEventListener('submit', (e) => {
      e.preventDefault()
      
      // 選択された値を取得
      const mealPlanId = this.idValue
      const date = document.getElementById('reuse-date').value
      const mealTime = document.querySelector('input[name="reuse-meal-time"]:checked').value
      
      // サーバーに送信
      this.submitReuseRequest(mealPlanId, date, mealTime)
      
      // モーダルを閉じる
      document.body.removeChild(modal)
    })
  }
  
  // 再利用リクエストをサーバーに送信
  submitReuseRequest(mealPlanId, date, mealTime) {
    // CSRFトークンを取得
    const token = document.querySelector('meta[name="csrf-token"]').content
    
    // Fetchを使ってAJAXリクエスト
    fetch('/calendar_plans/reuse', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': token
      },
      body: JSON.stringify({
        calendar_plan_id: mealPlanId,
        date: date,
        meal_time: mealTime
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        // 成功通知
        alert('献立を再利用しました！')
        
        // 必要に応じてページをリロード
        if (data.reload) {
          window.location.reload()
        }
      } else {
        alert(data.error || '献立の再利用に失敗しました')
      }
    })
    .catch(error => {
      console.error('Error:', error)
      alert('献立の再利用中にエラーが発生しました')
    })
  }
}