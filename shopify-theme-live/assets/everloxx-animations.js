/* ═══════ EVERLOXX PREMIUM ANIMATIONS ═══════
   Zero dependencies. Performant: IntersectionObserver + rAF + CSS transforms.

   Features:
   1. Lenis Smooth Scroll  → buttery momentum scrolling
   2. Scroll Reveal         → .cx-reveal / staggered children
   3. Counter Animation     → .cx-stat counts from 0
   4. 3D Tilt on Cards      → perspective tilt on mouse move
   5. Magnetic Buttons      → buttons follow cursor subtly
   6. Text Reveal           → .cx-text-reveal words appear one by one
   7. Marquee               → .cx-marquee infinite horizontal scroll
   8. Parallax              → smooth container float on scroll
   9. Auto-lift on cards    → removes inline hover handlers
*/
(function() {
  'use strict';
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  // ═══════════════════════════════════════════
  // 1. LENIS SMOOTH SCROLL (minimal inline implementation)
  // ═══════════════════════════════════════════
  function initLenis() {
    var scroll = { target: window.scrollY, current: window.scrollY, ease: 0.08 };
    var body = document.body;
    var html = document.documentElement;

    // Don't init on mobile (touch devices scroll natively better)
    if ('ontouchstart' in window) return;

    var docHeight = Math.max(body.scrollHeight, html.scrollHeight);
    body.style.height = docHeight + 'px';

    var wrapper = document.createElement('div');
    wrapper.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;overflow:hidden;';

    var content = document.createElement('div');
    content.style.cssText = 'will-change:transform;';

    // Move all body children into wrapper
    while (body.firstChild) {
      if (body.firstChild === wrapper) break;
      content.appendChild(body.firstChild);
    }
    wrapper.appendChild(content);
    body.appendChild(wrapper);

    window.addEventListener('scroll', function() {
      scroll.target = window.scrollY;
    }, { passive: true });

    function tick() {
      scroll.current += (scroll.target - scroll.current) * scroll.ease;
      var y = -scroll.current.toFixed(2);
      content.style.transform = 'translate3d(0,' + y + 'px,0)';

      // Update body height if content changes
      var newHeight = content.scrollHeight;
      if (Math.abs(newHeight - docHeight) > 50) {
        docHeight = newHeight;
        body.style.height = docHeight + 'px';
      }

      requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  }

  // ═══════════════════════════════════════════
  // 2. SCROLL REVEAL
  // ═══════════════════════════════════════════
  function initReveal() {
    document.querySelectorAll(
      'section > div > div[style*="text-align:center"], .cx-section-heading, section[aria-label]'
    ).forEach(function(el) {
      if (!el.classList.contains('cx-reveal') && !el.closest('.cx-reveal')) {
        el.classList.add('cx-reveal');
      }
    });

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
          if (el.classList.contains('cx-reveal-stagger')) {
            Array.prototype.forEach.call(el.children, function(child, i) {
              child.style.opacity = '0';
              child.style.transform = 'translateY(30px)';
              child.style.transition = 'opacity 0.8s cubic-bezier(0.16,1,0.3,1) ' + (i * 150) + 'ms, transform 0.8s cubic-bezier(0.16,1,0.3,1) ' + (i * 150) + 'ms';
              setTimeout(function() { child.style.opacity = '1'; child.style.transform = 'translateY(0)'; }, 50);
            });
          }
          el.classList.add('cx-visible');
          observer.unobserve(el);
        }
      });
    }, { threshold: 0.1, rootMargin: '0px 0px -60px 0px' });

    document.querySelectorAll('.cx-reveal').forEach(function(el) { observer.observe(el); });
  }

  // ═══════════════════════════════════════════
  // 3. COUNTER ANIMATION
  // ═══════════════════════════════════════════
  function initCounters() {
    var counted = false;
    var stats = document.querySelectorAll('.cx-stat');
    if (!stats.length) return;

    var observer = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        if (entry.isIntersecting && !counted) {
          counted = true;
          stats.forEach(function(el) {
            var text = el.textContent.trim();
            var suffix = text.replace(/[\d.,]/g, '');
            var target = parseFloat(text.replace(/[^\d.,]/g, '').replace(',', '.'));
            if (isNaN(target)) return;

            var duration = 2000;
            var start = performance.now();
            el.textContent = '0' + suffix;

            function tick(now) {
              var p = Math.min((now - start) / duration, 1);
              var eased = 1 - Math.pow(1 - p, 4); // ease out quart
              el.textContent = Math.round(eased * target) + suffix;
              if (p < 1) requestAnimationFrame(tick);
              else el.textContent = text;
            }
            requestAnimationFrame(tick);
          });
          observer.disconnect();
        }
      });
    }, { threshold: 0.3 });

    stats.forEach(function(el) { observer.observe(el); });
  }

  // ═══════════════════════════════════════════
  // 4. 3D TILT ON CARDS
  // ═══════════════════════════════════════════
  function initTilt() {
    document.querySelectorAll('.cx-card').forEach(function(card) {
      card.style.transformStyle = 'preserve-3d';
      card.style.transition = 'transform 0.15s ease-out';

      card.addEventListener('mousemove', function(e) {
        var rect = card.getBoundingClientRect();
        var x = (e.clientX - rect.left) / rect.width - 0.5;  // -0.5 to 0.5
        var y = (e.clientY - rect.top) / rect.height - 0.5;
        var tiltX = y * -8;  // degrees
        var tiltY = x * 8;
        card.style.transform = 'perspective(800px) rotateX(' + tiltX + 'deg) rotateY(' + tiltY + 'deg) scale3d(1.02,1.02,1.02)';
      });

      card.addEventListener('mouseleave', function() {
        card.style.transform = 'perspective(800px) rotateX(0) rotateY(0) scale3d(1,1,1)';
      });
    });
  }

  // ═══════════════════════════════════════════
  // 5. MAGNETIC BUTTONS
  // ═══════════════════════════════════════════
  function initMagnetic() {
    document.querySelectorAll('.cx-cta-btn, .cx-btn, a[style*="border-radius:40px"]').forEach(function(btn) {
      btn.style.transition = 'transform 0.3s cubic-bezier(0.16,1,0.3,1)';

      btn.addEventListener('mousemove', function(e) {
        var rect = btn.getBoundingClientRect();
        var cx = rect.left + rect.width / 2;
        var cy = rect.top + rect.height / 2;
        var dx = (e.clientX - cx) * 0.2;
        var dy = (e.clientY - cy) * 0.2;
        btn.style.transform = 'translate(' + dx + 'px,' + dy + 'px)';
      });

      btn.addEventListener('mouseleave', function() {
        btn.style.transform = 'translate(0,0)';
      });
    });
  }

  // ═══════════════════════════════════════════
  // 6. TEXT REVEAL (word by word)
  // ═══════════════════════════════════════════
  function initTextReveal() {
    document.querySelectorAll('.cx-section-heading, .cx-cta-heading, .cx-step-title').forEach(function(el) {
      if (el.dataset.revealed) return;
      el.dataset.revealed = '1';

      var html = el.innerHTML;
      // Skip elements containing HTML tags with attributes (they break on split)
      if (html.match(/<[a-z]+\s+[^>]*>/i)) return;

      // Split into words preserving simple HTML tags like <br>
      var words = html.split(/(\s+)/);
      var wrapped = words.map(function(w) {
        if (w.match(/^\s+$/)) return w;
        if (w.match(/^<[^>]+>$/)) return w;
        return '<span class="cx-word" style="display:inline-block;opacity:0;transform:translateY(12px);transition:opacity 0.5s ease,transform 0.5s ease;">' + w + '</span>';
      }).join('');
      el.innerHTML = wrapped;
    });

    var observer = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        if (entry.isIntersecting) {
          var words = entry.target.querySelectorAll('.cx-word');
          words.forEach(function(w, i) {
            setTimeout(function() {
              w.style.opacity = '1';
              w.style.transform = 'translateY(0)';
            }, i * 80);
          });
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.2 });

    document.querySelectorAll('.cx-section-heading, .cx-cta-heading').forEach(function(el) {
      observer.observe(el);
    });
  }

  // ═══════════════════════════════════════════
  // 7. MARQUEE STRIP
  // ═══════════════════════════════════════════
  function initMarquee() {
    document.querySelectorAll('.cx-marquee').forEach(function(el) {
      var content = el.innerHTML;
      // Duplicate content for seamless loop
      el.innerHTML = '<div class="cx-marquee-inner" style="display:flex;white-space:nowrap;animation:cx-marquee-scroll 25s linear infinite;">' +
        '<span style="padding-right:60px;">' + content + '</span>' +
        '<span style="padding-right:60px;">' + content + '</span>' +
        '<span style="padding-right:60px;">' + content + '</span>' +
        '</div>';
    });

    // Inject keyframes
    var style = document.createElement('style');
    style.textContent = '@keyframes cx-marquee-scroll { 0% { transform: translateX(0); } 100% { transform: translateX(-33.333%); } }';
    document.head.appendChild(style);
  }

  // ═══════════════════════════════════════════
  // 8. PARALLAX (smooth lerp on containers)
  // ═══════════════════════════════════════════
  function initParallax() {
    var containers = document.querySelectorAll('.cx-card div[style*="gap"], .cx-card div[style*="drop-shadow"]');
    if (!containers.length) {
      document.querySelectorAll('.cx-card').forEach(function(card) {
        var imgArea = card.querySelector('div');
        if (imgArea) imgArea.classList.add('cx-parallax-group');
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
        item.target = -(center - window.innerHeight / 2) * 0.012;
      });
    }, { passive: true });

    function tick() {
      items.forEach(function(item) {
        item.current += (item.target - item.current) * 0.035;
        item.el.style.transform = 'translateY(' + item.current.toFixed(2) + 'px)';
      });
      requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  }

  // ═══════════════════════════════════════════
  // 9. AUTO-LIFT CARDS (remove inline handlers)
  // ═══════════════════════════════════════════
  function initLift() {
    document.querySelectorAll('.cx-card, a[style*="border-radius:16px"]').forEach(function(el) {
      el.classList.add('cx-lift');
      el.removeAttribute('onmouseover');
      el.removeAttribute('onmouseout');
    });
  }

  // ═══════════════════════════════════════════
  // INIT
  // ═══════════════════════════════════════════
  function init() {
    initLift();
    initReveal();
    initCounters();
    initTilt();
    initMagnetic();
    initTextReveal();
    initMarquee();
    initParallax();
    // Lenis last (restructures DOM)
    // Disabled for now - can cause issues with Shopify's dynamic sections
    // initLenis();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
  document.addEventListener('shopify:section:load', init);
})();
