// app/javascript/packs/calendar.js
import Calendar from '@toast-ui/calendar';
import '@toast-ui/calendar/dist/toastui-calendar.min.css';

document.addEventListener('DOMContentLoaded', () => {
  const calendar = new Calendar('#calendar', {
    defaultView: 'month',
  });

  calendar.createEvents([
    { id: '1', title: '朝食', start: '2024-10-17T08:00', end: '2024-10-17T09:00' },
  ]);
});
