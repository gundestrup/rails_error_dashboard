/**
 * Theme Toggle and Chart Theming
 * Handles dark/light mode switching and applies theme to Chart.js instances
 */

// Load saved theme on page load (before DOMContentLoaded to prevent flash)
(function() {
  const savedTheme = localStorage.getItem('theme');
  if (savedTheme === 'dark') {
    document.body.classList.add('dark-mode');
  }
})();

// Theme toggle after DOM loads
document.addEventListener('DOMContentLoaded', function() {
  const themeToggle = document.getElementById('themeToggle');
  const themeIcon = document.getElementById('themeIcon');

  // Update icon based on current theme
  function updateIcon() {
    if (document.body.classList.contains('dark-mode')) {
      themeIcon.className = 'bi bi-sun-fill';
    } else {
      themeIcon.className = 'bi bi-moon-fill';
    }
  }

  // Set initial icon
  updateIcon();

  // Toggle theme on button click
  themeToggle.addEventListener('click', function() {
    console.log('🎨 Theme toggle clicked');

    document.body.classList.toggle('dark-mode');
    const isDark = document.body.classList.contains('dark-mode');

    console.log('Dark mode:', isDark);

    // Save preference
    localStorage.setItem('theme', isDark ? 'dark' : 'light');
    console.log('💾 Saved to localStorage:', isDark ? 'dark' : 'light');

    // Update icon
    updateIcon();
    console.log('✅ Theme toggled successfully');

    // Reapply chart theme
    applyChartTheme();

    // Reload page to update charts properly
    setTimeout(() => location.reload(), 300);
  });

  // Chart.js theme colors - ULTRA AGGRESSIVE setup
  function applyChartTheme() {
    if (typeof Chart !== 'undefined') {
      const isDark = document.body.classList.contains('dark-mode');
      const textColor = isDark ? '#cdd6f4' : '#1f2937';
      const gridColor = isDark ? 'rgba(88, 91, 112, 0.2)' : 'rgba(0, 0, 0, 0.1)';

      console.log('📊 Setting Chart.js theme:', isDark ? 'DARK' : 'light', '| Text:', textColor);

      // Global defaults
      Chart.defaults.color = textColor;
      Chart.defaults.borderColor = gridColor;
      Chart.defaults.font = Chart.defaults.font || {};
      Chart.defaults.font.color = textColor;

      // Scale defaults (axes) - AGGRESSIVE
      if (Chart.defaults.scale) {
        Chart.defaults.scale.ticks = Chart.defaults.scale.ticks || {};
        Chart.defaults.scale.ticks.color = textColor;
        Chart.defaults.scale.ticks.font = Chart.defaults.scale.ticks.font || {};
        Chart.defaults.scale.ticks.font.color = textColor;

        Chart.defaults.scale.grid = Chart.defaults.scale.grid || {};
        Chart.defaults.scale.grid.color = gridColor;

        // Axis title (xtitle, ytitle)
        Chart.defaults.scale.title = Chart.defaults.scale.title || {};
        Chart.defaults.scale.title.color = textColor;
        Chart.defaults.scale.title.font = Chart.defaults.scale.title.font || {};
        Chart.defaults.scale.title.font.size = 14;
      }

      // X and Y axis specific
      if (Chart.defaults.scales) {
        // X axis
        Chart.defaults.scales.x = Chart.defaults.scales.x || {};
        Chart.defaults.scales.x.ticks = Chart.defaults.scales.x.ticks || {};
        Chart.defaults.scales.x.ticks.color = textColor;
        Chart.defaults.scales.x.title = Chart.defaults.scales.x.title || {};
        Chart.defaults.scales.x.title.color = textColor;
        Chart.defaults.scales.x.grid = Chart.defaults.scales.x.grid || {};
        Chart.defaults.scales.x.grid.color = gridColor;

        // Y axis
        Chart.defaults.scales.y = Chart.defaults.scales.y || {};
        Chart.defaults.scales.y.ticks = Chart.defaults.scales.y.ticks || {};
        Chart.defaults.scales.y.ticks.color = textColor;
        Chart.defaults.scales.y.title = Chart.defaults.scales.y.title || {};
        Chart.defaults.scales.y.title.color = textColor;
        Chart.defaults.scales.y.grid = Chart.defaults.scales.y.grid || {};
        Chart.defaults.scales.y.grid.color = gridColor;
      }

      // Plugin defaults
      if (Chart.defaults.plugins) {
        // Legend
        if (Chart.defaults.plugins.legend) {
          Chart.defaults.plugins.legend.labels = Chart.defaults.plugins.legend.labels || {};
          Chart.defaults.plugins.legend.labels.color = textColor;
          Chart.defaults.plugins.legend.labels.font = Chart.defaults.plugins.legend.labels.font || {};
          Chart.defaults.plugins.legend.labels.font.color = textColor;
        }

        // Tooltip
        if (Chart.defaults.plugins.tooltip) {
          Chart.defaults.plugins.tooltip.backgroundColor = isDark ? '#313244' : 'rgba(255, 255, 255, 0.95)';
          Chart.defaults.plugins.tooltip.titleColor = isDark ? textColor : '#1f2937';
          Chart.defaults.plugins.tooltip.bodyColor = isDark ? textColor : '#1f2937';
          Chart.defaults.plugins.tooltip.borderColor = isDark ? '#585b70' : 'rgba(0, 0, 0, 0.2)';
          Chart.defaults.plugins.tooltip.borderWidth = 1;
        }

        // Title plugin
        if (Chart.defaults.plugins.title) {
          Chart.defaults.plugins.title.color = textColor;
          Chart.defaults.plugins.title.font = Chart.defaults.plugins.title.font || {};
          Chart.defaults.plugins.title.font.color = textColor;
        }
      }

      console.log('✅ Chart.js theme applied - all text should be:', textColor);
    } else {
      console.warn('⚠️ Chart.js not loaded yet');
    }

    // Also update Google Charts if present
    if (typeof google !== 'undefined' && google.visualization) {
      console.log('📊 Google Charts detected - applying theme');
    }
  }

  // Apply chart theme on load
  applyChartTheme();

  // NUCLEAR OPTION: Watch for chart creation and force colors
  const observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(mutation) {
      mutation.addedNodes.forEach(function(node) {
        if (node.tagName === 'CANVAS') {
          console.log('🎨 New chart detected, forcing theme...');
          setTimeout(applyChartTheme, 100);
        }
      });
    });
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });

  // Also listen for Chartkick chart creation events
  document.addEventListener('chartkick:load', function() {
    console.log('📊 Chartkick loaded, applying theme');
    applyChartTheme();
  });

  // Force reapply every 500ms for the first 3 seconds (in case charts load late)
  let attempts = 0;
  const forceInterval = setInterval(function() {
    attempts++;
    applyChartTheme();
    console.log('🔄 Force applying theme (attempt', attempts, ')');
    if (attempts >= 6) {
      clearInterval(forceInterval);
      console.log('✅ Stopped force applying');
    }
  }, 500);
});
