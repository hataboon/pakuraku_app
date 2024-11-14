// app\javascript\packs\calendar.js
document.addEventListener('DOMContentLoaded', () => {
  const calendarElement = document.getElementById('calendar');
  const selectedDates = JSON.parse(localStorage.getItem('selectedDates')) || {};

  if (calendarElement) {
    const calendar = new tui.Calendar(calendarElement, {
      defaultView: 'month',
      taskView: false,
      scheduleView: false,
      useDetailPopup: true,
      template: {
        monthDayname(dayname) {
          return `<span class="tui-full-calendar-dayname-name">${dayname}</span>`;
        },
        monthGrid(date) {
          const formattedDate = date.toISOString().split('T')[0];
          const dayPlan = selectedDates[formattedDate] || {};
          const mealInputs = ['朝','昼','夜'].map(meal => `
            <label><input type="checkbox" class="time-checkbox" data-date="${formattedDate}" data-time="${meal}" ${dayPlan[meal] ? 'checked' : ''}> ${meal}</label>
            `).join('<br>');
          const customPlan = dayPlan.customPlan || '';
          return `
            <div class="tui-full-calendar-month-grid">
              <div>${date.getDate()}</div>
              <div>
                ${mealInputs}
                <textarea class="custom-plan-input" data-date="${formattedDate}" placeholder="献立手入力">${customPlan}</textarea>
              </div>
            </div>
          `;
        }
      }
    });

    // チェックボックスの選択を保存
    calendarElement.addEventListener('change', (event) => {
      const date = event.target.getAttribute('data-date');
      const time = event.target.getAttribute('data-time');

      if (time) {
        if (!selectedDates[date]) selectedDates[date] = { 朝: false, 昼: false, 夜: false };
        selectedDates[date][time] = event.target.checked;
      } else {
        selectedDates[date].customPlan = event.target.value;
      }

      localStorage.setItem('selectedDates', JSON.stringify(selectedDates));
    });
  }
  // すでに選択済みの情報も含めて、ローカルストレージにデータを反映
  document.querySelectorAll('.custom-plan-input').forEach(input => {
    input.addEventListener('input', (event) => {
      const date = event.target.getAttribute('data-date');
      if (!selectedDates[date]) selectedDates[date] = {};
      selectedDates[date].customPlan = event.target.value;
      localStorage.setItem('selectedDates', JSON.stringify(selectedDates));
    });
  });
});
