/**
 * Syntax Highlighting Initialization
 * Uses Highlight.js with line numbers plugin for source code display
 */
(function() {
  'use strict';
  console.log('[HLJS] Starting initialization...');

  if (typeof hljs === 'undefined') {
    console.error('[HLJS] Highlight.js not loaded!');
    return;
  }
  console.log('[HLJS] Highlight.js loaded');

  function initHighlighting() {
    const codeBlocks = document.querySelectorAll('.source-code-content pre code');
    console.log('[HLJS] Found', codeBlocks.length, 'code blocks');

    if (codeBlocks.length === 0) return;

    codeBlocks.forEach((block, index) => {
      const lang = block.className.replace('language-', '');
      console.log(`[HLJS] Block ${index}: lang=${lang}`);

      try {
        hljs.highlightElement(block);
        console.log(`[HLJS] ✓ Highlighted block ${index}`);
      } catch (e) {
        console.error(`[HLJS] ✗ Failed block ${index}:`, e);
      }
    });

    console.log('[HLJS] Adding line numbers...');
    if (typeof hljs.lineNumbersBlock === 'function') {
      codeBlocks.forEach((block) => hljs.lineNumbersBlock(block));
      console.log('[HLJS] ✓ Line numbers added');
    } else if (typeof hljs.initLineNumbersOnLoad === 'function') {
      hljs.initLineNumbersOnLoad();
      console.log('[HLJS] ✓ Line numbers initialized');
    } else {
      console.warn('[HLJS] Line numbers plugin not found');
    }

    setTimeout(() => {
      codeBlocks.forEach((codeBlock) => {
        const errorLine = parseInt(codeBlock.dataset.errorLine);
        const startLine = parseInt(codeBlock.dataset.startLine) || 1;

        if (errorLine && !isNaN(errorLine)) {
          const table = codeBlock.querySelector('table.hljs-ln');
          if (table) {
            const rows = table.querySelectorAll('tr');
            rows.forEach((row, index) => {
              if ((startLine + index) === errorLine) {
                row.classList.add('error-line');
                console.log(`[HLJS] ✓ Marked row ${index} as error`);
              }
            });
          }
        }
      });
    }, 300);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initHighlighting);
  } else {
    initHighlighting();
  }
})();
