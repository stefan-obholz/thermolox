/* ── CLIMALOX Icon System ──
   Uses Lucide Icons (MIT license) – https://lucide.dev
   Replaces emoji in product descriptions with consistent SVG icons.
   Color from design tokens: #505050
*/
(function() {
  const C = '#505050';
  const W = '1.5';

  // Lucide SVG paths – consistent stroke-based icons
  function icon(paths, size) {
    size = size || '1.2em';
    return '<svg xmlns="http://www.w3.org/2000/svg" width="' + size + '" height="' + size + '" viewBox="0 0 24 24" fill="none" stroke="' + C + '" stroke-width="' + W + '" stroke-linecap="round" stroke-linejoin="round">' + paths + '</svg>';
  }

  const ICONS = {
    // ── Product features ──
    check:      icon('<path d="M20 6 9 17l-5-5"/>'),
    checkCircle:icon('<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><path d="m9 11 3 3L22 4"/>'),
    palette:    icon('<circle cx="13.5" cy="6.5" r=".5" fill="' + C + '"/><circle cx="17.5" cy="10.5" r=".5" fill="' + C + '"/><circle cx="8.5" cy="7.5" r=".5" fill="' + C + '"/><circle cx="6.5" cy="12" r=".5" fill="' + C + '"/><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.93 0 1.5-.67 1.5-1.5 0-.39-.15-.74-.39-1.04-.24-.3-.39-.65-.39-1.04 0-.83.67-1.5 1.5-1.5H16c3.31 0 6-2.69 6-6 0-5.17-4.49-8.92-10-8.92Z"/>'),
    home:       icon('<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>'),
    leaf:       icon('<path d="M11 20A7 7 0 0 1 9.8 6.9C15.5 4.9 17 3.4 19 2c1 2 2 4.5 2 8 0 5.5-4.78 10-10 10Z"/><path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12"/>'),
    star:       icon('<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>'),
    brush:      icon('<path d="m9.06 11.9 8.07-8.06a2.85 2.85 0 1 1 4.03 4.03l-8.06 8.08"/><path d="M7.07 14.94c-1.66 0-3 1.35-3 3.02 0 1.33-2.5 1.52-2 2.02 1.08 1.1 2.49 2.02 4 2.02 2.2 0 4-1.8 4-4.04a3.01 3.01 0 0 0-3-3.02Z"/>'),
    ban:        icon('<circle cx="12" cy="12" r="10"/><path d="m4.9 4.9 14.2 14.2"/>'),
    shield:     icon('<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/>'),
    flame:      icon('<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14 0-5.5 3.5-7.5C14 5 16.69 7.22 17 10c.27 2.43-1.67 5-4 6.5-.62.41-1.35.5-2.02.5-1.5 0-2.48-1-2.48-2.5Z"/><path d="M12 22v-2"/>'),
    droplet:    icon('<path d="M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z"/>'),
    truck:      icon('<path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2"/><path d="M15 18h2.38a2 2 0 0 0 1.78-1.11L21.5 13a2 2 0 0 0 .12-.68V8a2 2 0 0 0-2-2h-3"/><circle cx="7" cy="18" r="2"/><circle cx="17" cy="18" r="2"/>'),
    clock:      icon('<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>'),
    sparkles:   icon('<path d="M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z"/><path d="M20 3v4"/><path d="M22 5h-4"/>'),
    heart:      icon('<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/>'),
    info:       icon('<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>'),
    award:      icon('<path d="m15.477 12.89 1.515 8.526a.5.5 0 0 1-.81.47l-3.58-2.687a1 1 0 0 0-1.197 0l-3.586 2.686a.5.5 0 0 1-.81-.469l1.514-8.526"/><circle cx="12" cy="8" r="6"/>'),
  };

  // Emoji → Lucide icon mapping
  var MAP = {
    '✅': 'checkCircle', '☑️': 'checkCircle', '✓': 'check', '✔': 'check', '✔️': 'check',
    '🎨': 'palette', '🖌️': 'brush', '🖌': 'brush',
    '🏠': 'home', '🏡': 'home',
    '🌿': 'leaf', '🍃': 'leaf', '🌱': 'leaf',
    '⭐': 'star', '✨': 'sparkles', '💫': 'sparkles',
    '🚫': 'ban', '⛔': 'ban',
    '🛡️': 'shield', '🛡': 'shield',
    '🔥': 'flame',
    '💧': 'droplet',
    '🚚': 'truck',
    '⏰': 'clock', '🕐': 'clock',
    '❤️': 'heart', '💚': 'heart',
    'ℹ️': 'info',
    '🏆': 'award', '🥇': 'award',
  };

  function replaceEmoji() {
    var targets = document.querySelectorAll(
      '.product__description, .rte, .custom-liquid, .rich-text__text, [class*="product"] .metafield'
    );

    targets.forEach(function(el) {
      var walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null, false);
      var nodes = [];
      while (walker.nextNode()) {
        var text = walker.currentNode.textContent;
        for (var emoji in MAP) {
          if (text.indexOf(emoji) !== -1) { nodes.push(walker.currentNode); break; }
        }
      }

      nodes.forEach(function(node) {
        var frag = document.createDocumentFragment();
        var remaining = node.textContent;

        while (remaining.length > 0) {
          var earliest = -1, matchedEmoji = null;
          for (var emoji in MAP) {
            var idx = remaining.indexOf(emoji);
            if (idx !== -1 && (earliest === -1 || idx < earliest)) {
              earliest = idx; matchedEmoji = emoji;
            }
          }
          if (!matchedEmoji) {
            frag.appendChild(document.createTextNode(remaining));
            break;
          }
          if (earliest > 0) frag.appendChild(document.createTextNode(remaining.substring(0, earliest)));
          var span = document.createElement('span');
          span.className = 'climalox-icon';
          span.innerHTML = ICONS[MAP[matchedEmoji]];
          frag.appendChild(span);
          remaining = remaining.substring(earliest + matchedEmoji.length);
        }
        node.parentNode.replaceChild(frag, node);
      });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', replaceEmoji);
  } else {
    replaceEmoji();
  }
  document.addEventListener('shopify:section:load', replaceEmoji);
})();
