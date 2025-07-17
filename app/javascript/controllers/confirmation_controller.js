import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="confirmation"
export default class extends Controller {
  static values = { 
    fastTrackId: String,
    marketTitle: String,
    deadline: String,
    documentsCount: Number
  }

  connect() {
    // For redirect flow, just focus on the main content
    const mainContent = document.querySelector('.buyer-layout');
    if (mainContent) {
      mainContent.focus();
    }
    
    // Log completion for debugging
    console.log('Fast Track configuration completed:', {
      fastTrackId: this.fastTrackIdValue,
      marketTitle: this.marketTitleValue,
      deadline: this.deadlineValue,
      documentsCount: this.documentsCountValue
    });
  }
}