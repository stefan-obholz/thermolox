/* ═══════ CLIMALOX ANIMATIONS ═══════
   Performant: IntersectionObserver + CSS transforms, no libraries.

   Features:
   1. Scroll Reveal   → .cx-reveal / .cx-reveal-stagger
   2. Counter          → .cx-stat (auto-detected, counts from 0)
   3. Parallax         → .cx-parallax-img (subtle float on scroll)
   4. Lift hover       → .cx-lift (added automatically to .cx-card)
*/
(function() {
  'use strict';
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  // ── 1. Scroll Reveal ──
  function initReveal() {
    // Auto-add cx-reveal to key sections
    document.querySelectorAll(
      'section > div > div[style*="text-align:center"], ' +
      '.cx-section-heading, ' +
      'section[aria-label]'
    ).forEach(function(el) {
      if (!el.classList.contains('cx-reveal') && !el.closest('.cx-reveal')) {
        el.classList.add('cx-reveal');
      }
    });

    // Auto-add stagger to grids
    document.querySelectorAll(
      'div[style*="display:grid"], div[style*="display:flex"][style*="gap"]'
    ).forEach(function(el) {
      if (el.children.length >= 3 && !el.classList.contains('cx-reveal-stagger')) {
        el.classList.add('cx-reveal-stagger');
        el.classList.add('cx-reveal');
      }
    });

    var observer = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        if (entry.isIntersecting) {
          var el = entry.target;
          // Stagger children with delay
          if (el.classList.contains('cx-reveal-stagger')) {
            Array.prototype.forEach.call(el.children, function(child, i) {
              child.style.opacity = '0';
              child.style.transform = 'translateY(30px)';
              child.style.transition = 'opacity 0.7s cubic-bezier(0.16,1,0.3,1) ' + (i * 120) + 'ms, transform 0.7s cubic-bezier(0.16,1,0.3,1) ' + (i * 120) + 'ms';
              setTimeout(function() {
                child.style.opacity = '1';
                child.style.transform = 'translateY(0)';
              }, 50);
            });
          }
          el.classList.add('cx-visible');
          observer.unobserve(el);
        }
      });
    }, { threshold: 0.1, rootMargin: '0px 0px -60px 0px' });

    document.querySelectorAll('.cx-reveal').forEach(function(el) {
      observer.observe(el);
    });
  }

  // ── 2. Counter Animation ──
  function initCounters() {
    var counted = false;
    var stats = document.querySelectorAll('.cx-stat');
    if (!stats.length) return;

    var observer = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        if (entry.isIntersecting && !counted) {
          counted = true;
          animateCounters(stats);
          observer.disconnect();
        }
      });
    }, { threshold: 0.3 });

    stats.forEach(function(el) { observer.observe(el); });
  }

  function animateCounters(elements) {
    elements.forEach(function(el) {
      var text = el.textContent.trim();
      var suffix = text.replace(/[\d.,]/g, ''); // e.g. '%'
      var target = parseFloat(text.replace(/[^\d.,]/g, '').replace(',', '.'));
      if (isNaN(target)) return;

      var duration = 1800;
      var start = performance.now();
      var isInteger = target === Math.floor(target);

      function tick(now) {
        var elapsed = now - start;
        var progress = Math.min(elapsed / duration, 1);
        // Ease out cubic
        var eased = 1 - Math.pow(1 - progress, 3);
        var current = eased * target;

        if (isInteger) {
          el.textContent = Math.round(current) + suffix;
        } else {
          el.textContent = current.toFixed(0) + suffix;
        }

        if (progress < 1) {
          requestAnimationFrame(tick);
        } else {
          el.textContent = text; // restore exact original
        }
      }

      el.textContent = '0' + suffix;
      requestAnimationFrame(tick);
    });
  }

  // ── 3. Parallax on collection cards (smooth lerp, moves container not individual images) ──
  function initParallax() {
    // Find the parent containers that hold images, not individual imgs
    var containers = document.querySelectorAll('.cx-card div[style*="gap"], .cx-card div[style*="drop-shadow"]');
    // Fallback: use the card's image area (first child div)
    if (!containers.length) {
      document.querySelectorAll('.cx-card').forEach(function(card) {
        var imgArea = card.querySelector('div');
        if (imgArea) {
          imgArea.classList.add('cx-parallax-group');
        }
      });
      containers = document.querySelectorAll('.cx-parallax-group');
    }

    if (!containers.length) return;

    var items = [];
    containers.forEach(function(el) {
      el.style.willChange = 'transform';
      items.push({ el: el, current: 0, target: 0 });
    });

    window.addEventListener('scroll', function() {
      items.forEach(function(item) {
        var rect = item.el.getBoundingClientRect();
        var center = rect.top + rect.height / 2;
        var viewCenter = window.innerHeight / 2;
        item.target = -(center - viewCenter) * 0.015;
      });
    }, { passive: true });

    function tick() {
      items.forEach(function(item) {
        item.current += (item.target - item.current) * 0.04;
        item.el.style.transform = 'translateY(' + item.current.toFixed(2) + 'px)';
      });
      requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  }

  // ── 4. Auto-add lift to cards ──
  function initLift() {
    document.querySelectorAll('.cx-card, a[style*="border-radius:16px"]').forEach(function(el) {
      el.classList.add('cx-lift');
      // Remove inline hover handlers since CSS handles it now
      el.removeAttribute('onmouseover');
      el.removeAttribute('onmouseout');
    });
  }

  // ── Init all ──
  function init() {
    initLift();
    initReveal();
    initCounters();
    initParallax();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
  document.addEventListener('shopify:section:load', init);
})();
