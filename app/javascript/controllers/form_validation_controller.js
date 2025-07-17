import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form-validation"
export default class extends Controller {
  connect() {
    console.log("Form validation controller connected")
  }

  validateField(event) {
    const field = event.target;
    const isValid = field.checkValidity();
    
    // Visual feedback
    if (isValid) {
      field.style.borderColor = '#059669';
    } else {
      field.style.borderColor = '#dc2626';
    }
    
    // Reset to default after 2 seconds
    setTimeout(() => {
      if (field.style.borderColor !== '#2563eb') {
        field.style.borderColor = '#d1d5db';
      }
    }, 2000);
  }
}