document.addEventListener('DOMContentLoaded', () => {
  const calendarElement = document.getElementById('calendar');
  if (!calendarElement) {
    console.error('Calendar element not found!');
    return;
  }

  const calendar = new tui.Calendar(calendarElement, {
    defaultView: 'month',  // 月表示を設定
    taskView: false,       // タスク表示を無効化
    scheduleView: ['time'], // スケジュール表示を有効化
    useDetailPopup: true,  // 詳細ポップアップを有効化
  });

});
