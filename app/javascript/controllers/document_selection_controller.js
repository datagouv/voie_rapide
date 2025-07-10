import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="document-selection"
export default class extends Controller {
  static targets = ["count"]
  
  connect() {
    this.updateCount();
  }
  
  updateCount() {
    const checkedBoxes = this.element.querySelectorAll('input[name*="optional_document_ids"]:checked');
    if (this.hasCountTarget) {
      this.countTarget.textContent = checkedBoxes.length;
    }
  }
}