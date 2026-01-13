import { Controller } from "@hotwired/stimulus"

// Handles the mobile sidebar drawer navigation
export default class extends Controller {
  static targets = ["toggle", "drawer", "overlay", "iconMenu", "iconClose"]

  connect() {
    this.isOpen = false
    this.handleEscape = this.handleEscape.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleEscape)
    document.body.classList.remove("sidebar-open")
  }

  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.isOpen = true
    this.drawerTarget.classList.add("is-open")
    this.overlayTarget.classList.add("is-active")
    this.toggleTarget.classList.add("db-ide__menu-toggle--close")
    this.toggleTarget.setAttribute("aria-expanded", "true")
    document.body.classList.add("sidebar-open")

    // Show close icon, hide menu icon
    if (this.hasIconMenuTarget) this.iconMenuTarget.style.display = "none"
    if (this.hasIconCloseTarget) this.iconCloseTarget.style.display = "block"

    // Listen for escape key
    document.addEventListener("keydown", this.handleEscape)

    // Focus first link in sidebar for accessibility
    const firstLink = this.drawerTarget.querySelector("a")
    if (firstLink) {
      setTimeout(() => firstLink.focus(), 100)
    }
  }

  close() {
    this.isOpen = false
    this.drawerTarget.classList.remove("is-open")
    this.overlayTarget.classList.remove("is-active")
    this.toggleTarget.classList.remove("db-ide__menu-toggle--close")
    this.toggleTarget.setAttribute("aria-expanded", "false")
    document.body.classList.remove("sidebar-open")

    // Show menu icon, hide close icon
    if (this.hasIconMenuTarget) this.iconMenuTarget.style.display = "block"
    if (this.hasIconCloseTarget) this.iconCloseTarget.style.display = "none"

    // Remove escape key listener
    document.removeEventListener("keydown", this.handleEscape)

    // Return focus to toggle button
    this.toggleTarget.focus()
  }

  handleEscape(event) {
    if (event.key === "Escape" && this.isOpen) {
      this.close()
    }
  }
}
