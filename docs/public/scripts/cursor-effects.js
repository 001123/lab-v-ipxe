// Interactive Global Mouse Spotlight
(function () {
  if (typeof window === 'undefined') return;

  function initCursor() {
    if (document.getElementById('cursor-spotlight')) return;

    // Create global spotlight element
    const spotlight = document.createElement('div');
    spotlight.id = 'cursor-spotlight';
    spotlight.className = 'cursor-spotlight';
    spotlight.setAttribute('aria-hidden', 'true');
    spotlight.style.opacity = '0';
    spotlight.style.transform = 'translate3d(-9999px, -9999px, 0)';
    document.body.appendChild(spotlight);

    let isVisible = false;

    window.addEventListener('pointermove', (e) => {
      const mouseX = e.clientX;
      const mouseY = e.clientY;

      if (mouseX === 0 && mouseY === 0) return;

      if (!isVisible) {
        isVisible = true;
        spotlight.style.opacity = '0.7';
      }

      spotlight.style.transform = `translate3d(${mouseX}px, ${mouseY}px, 0)`;

      // Update reactive mouse properties on cards
      const target = e.target;
      if (target && target.closest) {
        const card = target.closest('.card, .lang-card, .sl-link-button, .pagination-links a');
        if (card) {
          const rect = card.getBoundingClientRect();
          card.style.setProperty('--mouse-x', `${mouseX - rect.left}px`);
          card.style.setProperty('--mouse-y', `${mouseY - rect.top}px`);
        }
      }
    });

    document.addEventListener('pointerleave', () => {
      isVisible = false;
      spotlight.style.opacity = '0';
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initCursor);
  } else {
    initCursor();
  }
})();
