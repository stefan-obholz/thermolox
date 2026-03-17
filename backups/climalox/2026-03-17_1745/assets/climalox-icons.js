/* ── CLIMALOX Icon Replacement ──
   Replaces emoji in product descriptions and page content
   with clean Phosphor Icons (SVG). Edit the ICON_MAP below
   to change icons site-wide.
*/
(function() {
  const COLOR = '#D4896F';

  // ── Central Icon Map: emoji → SVG path ──
  // Phosphor Icons (https://phosphoricons.com) – regular weight
  const ICON_MAP = {
    // Nature / Environment
    '🌿': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><path d="M216,40s-48,0-96,48c-16,16-28.59,34.1-37.37,51.63M160,72s-24,24-40,72M128,160C56,168,24,216,24,216s64-8,104-48c8-8,14.52-16.26,19.75-24.43"/><path d="M113.41,145.12C96,168,56,216,24,216"/><path d="M216,40c0,0-24,96-88,160"/></svg>',
    '🍃': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><path d="M216,40s-48,0-96,48c-16,16-28.59,34.1-37.37,51.63M160,72s-24,24-40,72M128,160C56,168,24,216,24,216s64-8,104-48c8-8,14.52-16.26,19.75-24.43"/><path d="M113.41,145.12C96,168,56,216,24,216"/><path d="M216,40c0,0-24,96-88,160"/></svg>',

    // Home / Energy
    '🏠': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><path d="M216,216V115.54a8,8,0,0,0-2.62-5.92l-80-75.54a8,8,0,0,0-10.76,0l-80,75.54A8,8,0,0,0,40,115.54V216"/><line x1="16" y1="216" x2="240" y2="216"/></svg>',
    '🏡': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><path d="M216,216V115.54a8,8,0,0,0-2.62-5.92l-80-75.54a8,8,0,0,0-10.76,0l-80,75.54A8,8,0,0,0,40,115.54V216"/><line x1="16" y1="216" x2="240" y2="216"/></svg>',

    // Paint / Art
    '🎨': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><circle cx="128" cy="128" r="96"/><circle cx="128" cy="80" r="12" fill="currentColor"/><circle cx="80" cy="128" r="12" fill="currentColor"/><circle cx="176" cy="128" r="12" fill="currentColor"/><circle cx="128" cy="176" r="12" fill="currentColor"/></svg>',
    '🖌️': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><path d="M224,24,96,152"/><path d="M136,32l48,48"/><rect x="32" y="152" width="64" height="72" rx="32"/></svg>',
    '🖌': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><path d="M224,24,96,152"/><path d="M136,32l48,48"/><rect x="32" y="152" width="64" height="72" rx="32"/></svg>',

    // Star / Quality
    '⭐': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><polygon points="128 16 160 96 248 104 180 160 200 248 128 208 56 248 76 160 8 104 96 96 128 16"/></svg>',
    '✨': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><path d="M80,24V56"/><path d="M64,40H96"/><path d="M208,120v32"/><path d="M192,136h32"/><path d="M128,48l16,48,48,16-48,16-16,48-16-48L64,112l48-16Z"/></svg>',

    // Checkmark / Quality
    '✅': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><circle cx="128" cy="128" r="96"/><polyline points="88 136 112 160 168 104"/></svg>',
    '☑️': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><circle cx="128" cy="128" r="96"/><polyline points="88 136 112 160 168 104"/></svg>',
    '✓': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><polyline points="40 144 96 200 224 72"/></svg>',

    // No chemicals / Eco
    '🚫': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><circle cx="128" cy="128" r="96"/><line x1="60" y1="60" x2="196" y2="196"/></svg>',
    '⛔': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><circle cx="128" cy="128" r="96"/><line x1="60" y1="60" x2="196" y2="196"/></svg>',

    // Shield / Protection
    '🛡️': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><path d="M40,114.79V56a8,8,0,0,1,8-8H208a8,8,0,0,1,8,8v58.77c0,84.18-71.31,112.07-84.56,116.44a7.85,7.85,0,0,1-6.88,0C111.31,226.86,40,198.97,40,114.79Z"/></svg>',

    // Fire / Heat
    '🔥': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><path d="M128,240c-56,0-80-54-80-96,0-75.53,80-136,80-136s80,60.47,80,136C208,186,184,240,128,240Z"/><path d="M128,240c-24,0-40-22-40-48s40-72,40-72,40,46,40,72S152,240,128,240Z"/></svg>',

    // Droplet / Water
    '💧': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><path d="M128,240a80,80,0,0,1-80-80c0-72,80-152,80-152s80,80,80,152A80,80,0,0,1,128,240Z"/></svg>',

    // Roller / Application
    '🧹': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><rect x="56" y="32" width="152" height="56" rx="8"/><path d="M192,88v24a8,8,0,0,1-8,8H136v32"/><line x1="136" y1="152" x2="136" y2="224"/></svg>',

    // Truck / Delivery
    '🚚': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><path d="M176,80h40l24,48v56H224"/><rect x="16" y="80" width="160" height="104" rx="8"/><circle cx="192" cy="192" r="20"/><circle cx="72" cy="192" r="20"/></svg>',

    // Clock / Time
    '⏰': '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" viewBox="0 0 256 256" fill="none" stroke="currentColor" stroke-width="16" stroke-linecap="round" stroke-linejoin="round"><circle cx="128" cy="128" r="96"/><polyline points="128 72 128 128 168 152"/></svg>',
  };

  function replaceEmoji() {
    // Target product descriptions, custom-liquid sections, and rich-text sections
    var targets = document.querySelectorAll(
      '.product__description, .rte, .custom-liquid, [class*="product"] .metafield, .rich-text__text'
    );

    targets.forEach(function(el) {
      var walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null, false);
      var nodesToReplace = [];

      while (walker.nextNode()) {
        var node = walker.currentNode;
        var text = node.textContent;
        for (var emoji in ICON_MAP) {
          if (text.indexOf(emoji) !== -1) {
            nodesToReplace.push({ node: node, text: text });
            break;
          }
        }
      }

      nodesToReplace.forEach(function(item) {
        var frag = document.createDocumentFragment();
        var remaining = item.text;

        while (remaining.length > 0) {
          var earliest = -1;
          var matchedEmoji = null;

          for (var emoji in ICON_MAP) {
            var idx = remaining.indexOf(emoji);
            if (idx !== -1 && (earliest === -1 || idx < earliest)) {
              earliest = idx;
              matchedEmoji = emoji;
            }
          }

          if (matchedEmoji === null) {
            frag.appendChild(document.createTextNode(remaining));
            break;
          }

          if (earliest > 0) {
            frag.appendChild(document.createTextNode(remaining.substring(0, earliest)));
          }

          var span = document.createElement('span');
          span.className = 'climalox-icon';
          span.style.color = COLOR;
          span.innerHTML = ICON_MAP[matchedEmoji];
          frag.appendChild(span);

          remaining = remaining.substring(earliest + matchedEmoji.length);
        }

        item.node.parentNode.replaceChild(frag, item.node);
      });
    });
  }

  // Run on DOM ready and after Shopify section load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', replaceEmoji);
  } else {
    replaceEmoji();
  }
  document.addEventListener('shopify:section:load', replaceEmoji);
})();
