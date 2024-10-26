document.addEventListener('DOMContentLoaded', () => {
  const calendarElement = document.getElementById('calendar');
  if (calendarElement) {
    const calendar = new tui.Calendar(calendarElement, {
      defaultView: 'month',
      taskView: false,
      scheduleView: ['time'],
      useDetailPopup: true,
    });
    console.log("カレンダーが初期化されました:", calendar);
  } else {
    console.error("カレンダーの要素が見つかりません！");
  }
});
