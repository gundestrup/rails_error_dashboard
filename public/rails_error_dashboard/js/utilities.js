/**
 * Utility Functions
 * Includes clipboard copy, toast notifications, and timezone conversion
 */

document.addEventListener('DOMContentLoaded', function() {

  // Initialize Bootstrap tooltips
  function initializeTooltips() {
    const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]');
    const tooltipList = [...tooltipTriggerList].map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl));
  }

  // Initialize tooltips on page load
  initializeTooltips();

  // Re-initialize tooltips after dynamic content changes
  // (useful for AJAX-loaded content)
  if (typeof Turbo !== 'undefined') {
    document.addEventListener('turbo:load', initializeTooltips);
    document.addEventListener('turbo:frame-load', initializeTooltips);
  }

  // Copy to clipboard functionality
  window.copyToClipboard = function(text, button) {
    navigator.clipboard.writeText(text).then(function() {
      // Store original button HTML
      const originalHTML = button.innerHTML;

      // Show success state on button
      button.innerHTML = '<i class="bi bi-check"></i> Copied!';
      button.classList.remove('btn-outline-secondary');
      button.classList.add('btn-success');

      // Show toast notification
      showToast('Copied to clipboard!', 'success');

      // Reset button after 2 seconds
      setTimeout(function() {
        button.innerHTML = originalHTML;
        button.classList.remove('btn-success');
        button.classList.add('btn-outline-secondary');
      }, 2000);
    }).catch(function(err) {
      console.error('Failed to copy:', err);
      button.innerHTML = '<i class="bi bi-x"></i> Failed';
      showToast('Failed to copy to clipboard', 'danger');
    });
  };

  // Toast notification functionality
  window.showToast = function(message, type) {
    type = type || 'success';

    const toastId = 'toast-' + Date.now();
    const iconClass = type === 'success' ? 'bi-check-circle-fill' :
                     type === 'danger' ? 'bi-exclamation-circle-fill' :
                     'bi-info-circle-fill';
    const bgClass = type === 'success' ? 'bg-success' :
                   type === 'danger' ? 'bg-danger' :
                   'bg-info';

    const toastHTML = `
      <div id="${toastId}" class="toast align-items-center text-white ${bgClass} border-0" role="alert" aria-live="assertive" aria-atomic="true">
        <div class="d-flex">
          <div class="toast-body">
            <i class="bi ${iconClass} me-2"></i>
            ${message}
          </div>
          <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button>
        </div>
      </div>
    `;

    const container = document.querySelector('.toast-container');
    container.insertAdjacentHTML('beforeend', toastHTML);

    const toastElement = document.getElementById(toastId);
    const toast = new bootstrap.Toast(toastElement, { delay: 4000 });
    toast.show();

    // Remove toast element after it's hidden
    toastElement.addEventListener('hidden.bs.toast', function() {
      toastElement.remove();
    });
  };

  // Local Timezone Conversion
  // Converts UTC timestamps to user's local timezone on page load
  function convertToLocalTime() {
    // Convert all .local-time elements (formatted timestamps)
    document.querySelectorAll('.local-time').forEach(function(element) {
      const utcString = element.dataset.utc;
      const formatString = element.dataset.format;

      if (!utcString) return;

      try {
        const date = new Date(utcString);
        if (isNaN(date.getTime())) return; // Invalid date

        // Parse the format string and convert to local time
        const formatted = formatDateTime(date, formatString);

        // Get timezone abbreviation
        const timezone = getTimezoneAbbreviation(date);

        // Update element text
        element.textContent = formatted + ' ' + timezone;
        element.title = 'Your local time (click to see UTC)';

        // Add click handler to toggle between local and UTC
        element.style.cursor = 'pointer';
        element.dataset.originalUtc = utcString;
        element.dataset.localFormatted = formatted + ' ' + timezone;
        element.dataset.showingLocal = 'true';

        element.addEventListener('click', function() {
          if (this.dataset.showingLocal === 'true') {
            // Show UTC
            const utcDate = new Date(this.dataset.originalUtc);
            const utcFormatted = formatDateTime(utcDate, formatString);
            this.textContent = utcFormatted + ' UTC';
            this.title = 'UTC time (click to see local time)';
            this.dataset.showingLocal = 'false';
          } else {
            // Show local
            this.textContent = this.dataset.localFormatted;
            this.title = 'Your local time (click to see UTC)';
            this.dataset.showingLocal = 'true';
          }
        });
      } catch (e) {
        console.error('Error converting timestamp:', e);
      }
    });

    // Convert all .local-time-ago elements (relative time)
    document.querySelectorAll('.local-time-ago').forEach(function(element) {
      const utcString = element.dataset.utc;
      if (!utcString) return;

      try {
        const date = new Date(utcString);
        if (isNaN(date.getTime())) return; // Invalid date

        // Calculate relative time
        const now = new Date();
        const diffMs = now - date;
        const formatted = formatRelativeTime(diffMs);

        // Update element text
        element.textContent = formatted;
        element.title = 'Click to see exact time';

        // Add click handler to toggle between relative and absolute
        element.style.cursor = 'pointer';
        element.dataset.originalUtc = utcString;
        element.dataset.showingRelative = 'true';

        element.addEventListener('click', function() {
          if (this.dataset.showingRelative === 'true') {
            // Show absolute time
            const absoluteDate = new Date(this.dataset.originalUtc);
            const absoluteFormatted = formatDateTime(absoluteDate, '%B %d, %Y %I:%M:%S %p');
            const timezone = getTimezoneAbbreviation(absoluteDate);
            this.textContent = absoluteFormatted + ' ' + timezone;
            this.title = 'Click to see relative time';
            this.dataset.showingRelative = 'false';
          } else {
            // Show relative time
            const now = new Date();
            const date = new Date(this.dataset.originalUtc);
            const diffMs = now - date;
            this.textContent = formatRelativeTime(diffMs);
            this.title = 'Click to see exact time';
            this.dataset.showingRelative = 'true';
          }
        });
      } catch (e) {
        console.error('Error converting relative time:', e);
      }
    });
  }

  // Format date according to strftime-like format string
  function formatDateTime(date, formatString) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    const monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                         'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const daysShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    const year = date.getFullYear();
    const month = date.getMonth();
    const day = date.getDate();
    const hours = date.getHours();
    const minutes = date.getMinutes();
    const seconds = date.getSeconds();
    const dayOfWeek = date.getDay();

    // 12-hour format
    const hours12 = hours % 12 || 12;
    const ampm = hours >= 12 ? 'PM' : 'AM';

    // Padding helper
    const pad = (n) => n.toString().padStart(2, '0');

    // Replace format specifiers
    let result = formatString
      .replace('%Y', year)
      .replace('%y', year.toString().substr(2))
      .replace('%B', months[month])
      .replace('%b', monthsShort[month])
      .replace('%m', pad(month + 1))
      .replace('%d', pad(day))
      .replace('%e', day)
      .replace('%A', days[dayOfWeek])
      .replace('%a', daysShort[dayOfWeek])
      .replace('%H', pad(hours))
      .replace('%I', pad(hours12))
      .replace('%M', pad(minutes))
      .replace('%S', pad(seconds))
      .replace('%p', ampm)
      .replace('%P', ampm.toLowerCase());

    return result;
  }

  // Get timezone abbreviation (e.g., "PST", "EST", "UTC+2")
  function getTimezoneAbbreviation(date) {
    const timeZoneString = date.toLocaleTimeString('en-US', { timeZoneName: 'short' });
    const parts = timeZoneString.split(' ');
    return parts[parts.length - 1]; // Last part is timezone abbreviation
  }

  // Format relative time ("3 hours ago", "2 days ago")
  function formatRelativeTime(diffMs) {
    const seconds = Math.floor(diffMs / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    const months = Math.floor(days / 30);
    const years = Math.floor(days / 365);

    if (seconds < 60) {
      return seconds <= 1 ? '1 second ago' : seconds + ' seconds ago';
    } else if (minutes < 60) {
      return minutes === 1 ? '1 minute ago' : minutes + ' minutes ago';
    } else if (hours < 24) {
      return hours === 1 ? '1 hour ago' : hours + ' hours ago';
    } else if (days < 30) {
      return days === 1 ? '1 day ago' : days + ' days ago';
    } else if (months < 12) {
      return months === 1 ? '1 month ago' : months + ' months ago';
    } else {
      return years === 1 ? '1 year ago' : years + ' years ago';
    }
  }

  // Run conversion on page load
  convertToLocalTime();

  // Also run after Turbo navigation (if using Turbo/Hotwire)
  if (typeof Turbo !== 'undefined') {
    document.addEventListener('turbo:load', convertToLocalTime);
    document.addEventListener('turbo:frame-load', convertToLocalTime);
  }
});
