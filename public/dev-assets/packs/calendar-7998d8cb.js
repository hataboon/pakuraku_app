document.addEventListener('DOMContentLoaded', () => {
  const calendarElement = document.getElementById('calendar');
  const calendarPlans = window.calendarPlans || []; // サーバーから受け取ったデータ

  if (calendarElement) {
    const calendar = new tui.Calendar(calendarElement, {
      defaultView: 'month',
      taskView: false,
      scheduleView: false,
      useDetailPopup: true,
      template: {
        monthGrid(date) {
          const formattedDate = date.toISOString().split('T')[0];
          const plansForDate = calendarPlans.filter(plan => plan.date === formattedDate);

          return plansForDate.map(plan => `
            <div>
              <strong>${plan.meal_time}:</strong> ${plan.recipe_name}
            </div>
          `).join('');
        }
      }
    });
  }
});
