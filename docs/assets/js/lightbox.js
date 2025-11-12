// Lightweight Lightbox — vanilla JS
// Usage: add data-lightbox to <img> elements. Optionally group with data-group="quickstart" etc.
(() => {
  const SEL = 'img[data-lightbox]';
  let state = {
    groups: new Map(),   // group -> array of elements
    order: [],           // array of all lightboxed elements when no group
    currentGroup: null,
    currentIndex: -1,
    zoom: 1
  };

  // Build overlay once
  const overlay = document.createElement('div');
  overlay.className = 'lb-overlay';
  overlay.innerHTML = `
    <div class="lb-frame">
      <div class="lb-media">
        <img class="lb-img" alt="Preview"/>
        <button class="lb-close" aria-label="Close">✕</button>
        <button class="lb-prev" aria-label="Previous">‹</button>
        <button class="lb-next" aria-label="Next">›</button>
      </div>
      <div class="lb-caption"></div>
    </div>`;
  document.body.appendChild(overlay);

  const imgEl = overlay.querySelector('.lb-img');
  const captionEl = overlay.querySelector('.lb-caption');
  const btnClose = overlay.querySelector('.lb-close');
  const btnPrev = overlay.querySelector('.lb-prev');
  const btnNext = overlay.querySelector('.lb-next');

  function collect() {
    state.groups.clear();
    state.order = [];
    document.querySelectorAll(SEL).forEach((el) => {
      const g = el.dataset.group || null;
      if (g) {
        if (!state.groups.has(g)) state.groups.set(g, []);
        state.groups.get(g).push(el);
      } else {
        state.order.push(el);
      }
      el.classList.add('lb-zoomable');
    });
  }

  function openFor(el) {
    const group = el.dataset.group || null;
    let list = group ? state.groups.get(group) : state.order;
    if (!list || !list.length) list = [el];

    state.currentGroup = group;
    state.currentIndex = list.indexOf(el);
    if (state.currentIndex < 0) state.currentIndex = 0;

    updateImage();
    overlay.classList.add('is-open');
  }

  function updateImage() {
    const list = getList();
    const cur = list[state.currentIndex];
    if (!cur) return;
    state.zoom = 1;
    imgEl.style.transform = 'scale(1)';
    imgEl.src = cur.src;
    imgEl.alt = cur.alt || 'Preview';
    captionEl.textContent = cur.closest('figure')?.querySelector('figcaption')?.textContent || cur.alt || '';
    btnPrev.style.display = list.length > 1 ? '' : 'none';
    btnNext.style.display = list.length > 1 ? '' : 'none';
  }

  function getList() {
    return state.currentGroup ? (state.groups.get(state.currentGroup) || []) : state.order;
  }

  function prev() {
    const list = getList();
    state.currentIndex = (state.currentIndex - 1 + list.length) % list.length;
    updateImage();
  }

  function next() {
    const list = getList();
    state.currentIndex = (state.currentIndex + 1) % list.length;
    updateImage();
  }

  function close() {
    overlay.classList.remove('is-open');
  }

  // Zoom with click
  function toggleZoom(ev) {
    if (state.zoom === 1) {
      state.zoom = 1.8;
      imgEl.style.transform = 'scale(1.8)';
      imgEl.classList.add('lb-zoomed');
    } else {
      state.zoom = 1;
      imgEl.style.transform = 'scale(1)';
      imgEl.classList.remove('lb-zoomed');
    }
  }

  // Drag to pan when zoomed
  let isPanning = false, startX = 0, startY = 0, originX = 0, originY = 0;
  imgEl.addEventListener('mousedown', (e) => {
    if (state.zoom === 1) return;
    isPanning = true;
    startX = e.clientX; startY = e.clientY;
    const tr = imgEl.style.transformOrigin || 'center center';
    const rect = imgEl.getBoundingClientRect();
    originX = rect.width / 2; originY = rect.height / 2;
    e.preventDefault();
  });
  window.addEventListener('mousemove', (e) => {
    if (!isPanning) return;
    const dx = e.clientX - startX;
    const dy = e.clientY - startY;
    imgEl.style.transform = `translate(${dx}px, ${dy}px) scale(${state.zoom})`;
  });
  window.addEventListener('mouseup', () => {
    if (!isPanning) return;
    isPanning = false;
    // Snap back to center if too far (simple heuristic)
    imgEl.style.transform = `scale(${state.zoom})`;
  });

  // Wheel zoom
  imgEl.addEventListener('wheel', (e) => {
    e.preventDefault();
    const delta = Math.sign(e.deltaY);
    const nextZoom = Math.min(3, Math.max(1, state.zoom + (delta < 0 ? 0.2 : -0.2)));
    state.zoom = nextZoom;
    imgEl.style.transform = `scale(${state.zoom})`;
    if (state.zoom > 1) imgEl.classList.add('lb-zoomed'); else imgEl.classList.remove('lb-zoomed');
  }, { passive: false });

  // Touch swipe + pinch (basic)
  let touchStartX = 0, touchStartY = 0;
  overlay.addEventListener('touchstart', (e) => {
    if (e.touches.length === 1) {
      touchStartX = e.touches[0].clientX;
      touchStartY = e.touches[0].clientY;
    }
  }, { passive: true });
  overlay.addEventListener('touchend', (e) => {
    const dx = (e.changedTouches[0]?.clientX || 0) - touchStartX;
    const dy = (e.changedTouches[0]?.clientY || 0) - touchStartY;
    if (Math.abs(dx) > 60 && Math.abs(dy) < 50) {
      if (dx > 0) prev(); else next();
    }
  });

  // Events
  btnClose.addEventListener('click', close);
  btnPrev.addEventListener('click', prev);
  btnNext.addEventListener('click', next);
  overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });
  imgEl.addEventListener('click', toggleZoom);

  window.addEventListener('keydown', (e) => {
    if (!overlay.classList.contains('is-open')) return;
    if (e.key === 'Escape') close();
    else if (e.key === 'ArrowLeft') prev();
    else if (e.key === 'ArrowRight') next();
  });

  // Attach to images
  function bind() {
    collect();
    document.querySelectorAll(SEL).forEach((el) => {
      if (el.__lbBound) return;
      el.__lbBound = true;
      el.addEventListener('click', (e) => {
        e.preventDefault();
        openFor(el);
      });
    });
  }

  // Observe DOM changes in case images load dynamically
  const mo = new MutationObserver(bind);
  mo.observe(document.documentElement, { childList: true, subtree: true });

  // Initial bind
  window.addEventListener('DOMContentLoaded', bind);
})();
