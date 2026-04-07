import { Controller } from "@hotwired/stimulus"

// Handles toggling between table and card view on mobile
export default class extends Controller {
  static targets = ["wrapper", "tableBtn", "cardBtn"]

  connect() {
    // Check localStorage for saved preference
    const savedView = localStorage.getItem("db-ide-view-mode")
    if (savedView === "cards") {
      this.showCards()
    }
  }

  showTable() {
    if (this.hasWrapperTarget) {
      this.wrapperTarget.dataset.view = "table"
    }

    // Update button states
    if (this.hasTableBtnTarget) {
      this.tableBtnTarget.classList.add("is-active")
      this.tableBtnTarget.setAttribute("aria-pressed", "true")
    }
    if (this.hasCardBtnTarget) {
      this.cardBtnTarget.classList.remove("is-active")
      this.cardBtnTarget.setAttribute("aria-pressed", "false")
    }

    // Save preference
    localStorage.setItem("db-ide-view-mode", "table")
  }

  showCards() {
    if (this.hasWrapperTarget) {
      this.wrapperTarget.dataset.view = "cards"
    }

    // Update button states
    if (this.hasTableBtnTarget) {
      this.tableBtnTarget.classList.remove("is-active")
      this.tableBtnTarget.setAttribute("aria-pressed", "false")
    }
    if (this.hasCardBtnTarget) {
      this.cardBtnTarget.classList.add("is-active")
      this.cardBtnTarget.setAttribute("aria-pressed", "true")
    }

    // Save preference
    localStorage.setItem("db-ide-view-mode", "cards")
  }
}
