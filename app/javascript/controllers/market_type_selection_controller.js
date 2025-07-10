import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="market-type-selection"
export default class extends Controller {
  selectType(event) {
    // Visual feedback for label selection
    const label = event.currentTarget;
    const radio = label.querySelector('input[type="radio"]');
    if (radio) {
      radio.checked = true;
      this.updateSelection({ target: radio });
    }
  }
  
  updateSelection(event) {
    // Update visual state of all options
    const allLabels = this.element.querySelectorAll('label[data-action*="selectType"]');
    allLabels.forEach(label => {
      const radio = label.querySelector('input[type="radio"]');
      if (radio.checked) {
        label.style.borderColor = '#2563eb';
        label.style.backgroundColor = '#eff6ff';
      } else {
        label.style.borderColor = '#e5e7eb';
        label.style.backgroundColor = 'transparent';
      }
    });
  }
}