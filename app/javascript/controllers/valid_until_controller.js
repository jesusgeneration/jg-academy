import { Controller } from "@hotwired/stimulus"

// Prefills the valid_until date from the selected coverages carrying a
// validity period (shortest period wins), counted from the end of the
// course. Auto-update stops once the user edits the field manually; the
// server-side fallbacks likewise only ever fill blank values.
export default class extends Controller {
  static targets = ["field", "coverage", "startDate", "startTime", "duration"]

  connect() {
    this.edited = this.fieldTarget.value !== ""
    this.update()
  }

  markEdited() {
    this.edited = true
  }

  update() {
    if (this.edited || !this.hasCoverageTarget) return

    const years = this.selectedValidityYears()
    const endDate = this.courseEndDate()
    this.fieldTarget.value = years === null || endDate === null ? "" : formatDate(addYears(endDate, years))
  }

  selectedValidityYears() {
    const years = this.coverageTargets
      .filter((box) => box.checked)
      .map((box) => parseInt(box.dataset.validityYears, 10))
      .filter((years) => Number.isInteger(years) && years > 0)
    return years.length === 0 ? null : Math.min(...years)
  }

  courseEndDate() {
    const date = this.startDateTarget.value
    const time = this.startTimeTarget.value
    const minutes = parseInt(this.durationTarget.value, 10)
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return null
    if (!/^\d{1,2}:\d{2}$/.test(time)) return null
    if (!Number.isInteger(minutes) || minutes <= 0) return null

    const [hour, minute] = time.split(":").map(Number)
    const [year, month, day] = date.split("-").map(Number)
    return new Date(new Date(year, month - 1, day, hour, minute).getTime() + minutes * 60000)
  }
}

// Adds years like Rails' Date#advance: Feb 29 clamps to Feb 28 so both
// sides agree on leap-day course ends.
function addYears(date, years) {
  const result = new Date(date.getFullYear() + years, date.getMonth(), date.getDate())
  if (result.getMonth() !== date.getMonth()) result.setDate(0)
  return result
}

function formatDate(date) {
  const pad = (number) => String(number).padStart(2, "0")
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}
