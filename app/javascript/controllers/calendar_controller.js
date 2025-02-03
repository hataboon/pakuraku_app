import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthDisplay"]

  connect() {
    this.currentDate = new Date()
  }

  previousMonth(event) {
    event.preventDefault()
    this.currentDate.setMonth(this.currentDate.getMonth() - 1)
    this.updateCalendar()
  }

  nextMonth(event) {
    event.preventDefault()
    this.currentDate.setMonth(this.currentDate.getMonth() + 1)
    this.updateCalendar()
  }

  currentMonth(event) {
    event.preventDefault()
    this.currentDate = new Date()
    this.updateCalendar()
  }

  async updateCalendar() {
    const year = this.currentDate.getFullYear()
    const month = this.currentDate.getMonth() + 1
    const response = await fetch(`/foods?date=${year}-${month}-01`, {
      headers: {
        Accept: "text/vnd.turbo-stream.html"
      }
    })
    const html = await response.text()
    Turbo.renderStreamMessage(html)
  }
}