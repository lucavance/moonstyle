const storageKey = 'lampclaw-style-inspector-open';

function element(tag, className, text) {
  const value = document.createElement(tag);
  if (className) value.className = className;
  if (text !== undefined) value.textContent = text;
  return value;
}

function cssPropertyName(value) {
  if (value.startsWith('--')) return value;
  return value.replaceAll(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
}

function elementLabel(value) {
  const id = value.id ? `#${value.id}` : '';
  const classes = [...value.classList]
    .slice(0, 3)
    .map((className) => `.${className}`)
    .join('');
  return `${value.tagName.toLowerCase()}${id}${classes}`;
}

function storedOpenState() {
  try {
    return sessionStorage.getItem(storageKey) === 'true';
  } catch {
    return false;
  }
}

function storeOpenState(value) {
  try {
    sessionStorage.setItem(storageKey, String(value));
  } catch {
    // Storage can be unavailable in sandboxed development frames.
  }
}

function statusLabel(value) {
  return (
    {
      ready: 'ready',
      rebuilding: 'rebuilding',
      stale: 'stale',
      unavailable: 'unavailable',
    }[value] ?? value
  );
}

export function mountLampclawStyleInspector({
  manifest: initialManifest,
  status: initialStatus = 'ready',
  openSource = () => {},
} = {}) {
  if (typeof document === 'undefined') {
    return {
      dispose() {},
      setStatus() {},
      updateManifest() {},
    };
  }

  document.querySelector('[data-lampclaw-style-inspector]')?.remove();
  const host = element('div');
  host.dataset.lampclawStyleInspector = '';
  const shadow = host.attachShadow({ mode: 'open' });
  shadow.innerHTML = `
    <style>
      :host { all: initial; color-scheme: light dark; }
      * { box-sizing: border-box; }
      button { font: inherit; }
      .badge { position: fixed; right: 16px; bottom: 16px; z-index: 2147483647; display: flex;
        align-items: center; gap: 7px; min-width: 42px; height: 32px; padding: 0 10px; border: 1px solid #68708a;
        border-radius: 999px; background: #111522; color: #f4f6ff; box-shadow: 0 5px 18px #0007;
        cursor: pointer; font: 600 12px/1 system-ui, sans-serif; }
      .badge:hover, button:focus-visible { outline: 2px solid #85a7ff; outline-offset: 2px; }
      .dot { width: 8px; height: 8px; border-radius: 50%; background: #59d499; }
      :host([data-status="rebuilding"]) .dot { background: #f7c65f; }
      :host([data-status="stale"]) .dot, :host([data-status="unavailable"]) .dot { background: #ff7d86; }
      .panel { position: fixed; right: 16px; bottom: 56px; z-index: 2147483647; width: min(430px, calc(100vw - 32px));
        max-height: min(680px, calc(100vh - 80px)); overflow: hidden; border: 1px solid #5b637a; border-radius: 12px;
        background: #111522; color: #eef1fa; box-shadow: 0 15px 45px #0009; font: 12px/1.45 system-ui, sans-serif; }
      .panel[hidden] { display: none; }
      .header, .toolbar { display: flex; align-items: center; gap: 8px; padding: 10px 12px; border-bottom: 1px solid #32394c; }
      .header strong { flex: 1; font-size: 13px; }
      .status { color: #aeb7cc; font-size: 11px; }
      .icon, .pick, .source { border: 1px solid #535d76; border-radius: 7px; background: #20263a; color: #eef1fa; cursor: pointer; }
      .icon { width: 26px; height: 26px; }
      .pick { padding: 6px 10px; }
      .pick[aria-pressed="true"] { background: #365fbd; border-color: #7da0f5; }
      .selection { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: #c8d1e8; }
      .body { max-height: min(570px, calc(100vh - 190px)); overflow: auto; padding: 10px; }
      .empty { padding: 18px 10px; color: #aab3c8; text-align: center; }
      .rule { margin-bottom: 9px; padding: 10px; border: 1px solid #343c51; border-radius: 9px; background: #171c2b; }
      .rule-head { display: flex; align-items: baseline; gap: 8px; }
      .class { color: #90b0ff; font: 600 12px/1.4 ui-monospace, monospace; overflow-wrap: anywhere; }
      .property { margin-left: auto; color: #cbd2e3; }
      .computed { margin: 5px 0; color: #83deb2; overflow-wrap: anywhere; }
      pre { margin: 7px 0; padding: 7px; overflow: auto; border-radius: 6px; background: #0d1019; color: #dfe5f4;
        white-space: pre-wrap; overflow-wrap: anywhere; font: 11px/1.45 ui-monospace, monospace; }
      .meta { color: #939db5; font-size: 11px; }
      .origin { display: flex; align-items: center; gap: 6px; margin-top: 6px; min-width: 0; }
      .origin-label { min-width: 0; flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: #bbc4d8; }
      .source { padding: 3px 7px; color: #a9c0ff; }
      .unknown { margin: 8px 2px 2px; color: #8993aa; overflow-wrap: anywhere; }
      .highlight { position: fixed; z-index: 2147483646; display: none; pointer-events: none; border: 2px solid #6f9cff;
        background: #6f9cff22; box-shadow: 0 0 0 1px #fff8 inset; }
    </style>
    <button class="badge" type="button" title="Lampclaw Style Inspector (Alt/Option+Shift+S)" aria-label="Toggle Lampclaw Style Inspector">
      <span class="dot"></span><span>Style</span>
    </button>
    <section class="panel" hidden aria-label="Lampclaw Style Inspector">
      <div class="header"><strong>Lampclaw Style Inspector</strong><span class="status"></span><button class="icon close" type="button" aria-label="Close">×</button></div>
      <div class="toolbar"><button class="pick" type="button" aria-pressed="false">Pick element</button><span class="selection">No element selected</span></div>
      <div class="body"><div class="empty">Pick an element to inspect its applied atomic rules.</div></div>
    </section>
    <div class="highlight"></div>
  `;
  document.documentElement.append(host);

  const badge = shadow.querySelector('.badge');
  const panel = shadow.querySelector('.panel');
  const close = shadow.querySelector('.close');
  const pick = shadow.querySelector('.pick');
  const selection = shadow.querySelector('.selection');
  const body = shadow.querySelector('.body');
  const statusNode = shadow.querySelector('.status');
  const highlight = shadow.querySelector('.highlight');
  let manifest = initialManifest ?? null;
  let status = initialStatus;
  let selected = null;
  let picking = false;
  let open = storedOpenState();

  const setOpen = (value) => {
    open = value;
    panel.hidden = !open;
    badge.setAttribute('aria-expanded', String(open));
    storeOpenState(open);
    if (!open && picking) stopPicking();
  };

  const setStatus = (value) => {
    status = value;
    host.dataset.status = value;
    statusNode.textContent = statusLabel(value);
    badge.title = `Lampclaw Style Inspector: ${statusLabel(value)} (Alt/Option+Shift+S)`;
  };

  const renderOrigin = (origin) => {
    const row = element('div', 'origin');
    const identity = [origin.module, origin.exportName, origin.namespace]
      .filter(Boolean)
      .join(' · ');
    row.append(element('span', 'origin-label', identity || 'Unknown origin'));
    if (origin.source !== null) {
      const source = origin.source;
      const button = element('button', 'source', `${source.file}:${source.line}:${source.column}`);
      button.type = 'button';
      button.title = source.symbol ? `${source.file} · ${source.symbol}` : source.file;
      button.addEventListener('click', () => openSource(source));
      row.append(button);
    }
    return row;
  };

  const render = () => {
    if (selected === null || !selected.isConnected) {
      selected = null;
      selection.textContent = 'No element selected';
      body.replaceChildren(
        element('div', 'empty', 'Pick an element to inspect its applied atomic rules.'),
      );
      return;
    }
    selection.textContent = elementLabel(selected);
    const classes = [...selected.classList];
    const ruleByClass = new Map((manifest?.rules ?? []).map((rule) => [rule.className, rule]));
    const matched = classes
      .map((className) => ruleByClass.get(className))
      .filter(Boolean)
      .toSorted((left, right) => left.priority100 - right.priority100 || left.order - right.order);
    const nodes = [];
    const computedStyle = getComputedStyle(selected);
    for (const rule of matched) {
      const card = element('article', 'rule');
      const header = element('div', 'rule-head');
      header.append(element('span', 'class', `.${rule.className}`));
      header.append(element('span', 'property', rule.property));
      card.append(header);
      const computed = computedStyle.getPropertyValue(cssPropertyName(rule.property)).trim();
      card.append(element('div', 'computed', `computed: ${computed || '(empty)'}`));
      card.append(element('pre', '', rule.css));
      card.append(
        element('div', 'meta', `priority100 ${rule.priority100} · render order ${rule.order}`),
      );
      if (rule.origins.length === 0) {
        card.append(element('div', 'origin', 'Source unavailable in the dependency bundle.'));
      } else {
        for (const origin of rule.origins) card.append(renderOrigin(origin));
      }
      nodes.push(card);
    }
    if (matched.length === 0) {
      nodes.push(element('div', 'empty', 'No Lampclaw atomic classes found on this element.'));
    }
    const unknown = classes.filter((className) => !ruleByClass.has(className));
    if (unknown.length > 0) {
      nodes.push(element('div', 'unknown', `Other classes: ${unknown.join(' ')}`));
    }
    body.replaceChildren(...nodes);
  };

  const hideHighlight = () => {
    highlight.style.display = 'none';
  };

  const stopPicking = () => {
    picking = false;
    pick.setAttribute('aria-pressed', 'false');
    pick.textContent = 'Pick element';
    hideHighlight();
    document.removeEventListener('pointermove', onPointerMove, true);
    document.removeEventListener('click', onPickClick, true);
  };

  const onPointerMove = (event) => {
    if (event.composedPath().includes(host)) {
      hideHighlight();
      return;
    }
    const target = document.elementFromPoint(event.clientX, event.clientY);
    if (!(target instanceof Element) || target === host) {
      hideHighlight();
      return;
    }
    const rectangle = target.getBoundingClientRect();
    Object.assign(highlight.style, {
      display: 'block',
      left: `${rectangle.left}px`,
      top: `${rectangle.top}px`,
      width: `${rectangle.width}px`,
      height: `${rectangle.height}px`,
    });
  };

  const onPickClick = (event) => {
    if (event.composedPath().includes(host)) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    if (event.target instanceof Element) selected = event.target;
    stopPicking();
    render();
  };

  const startPicking = () => {
    if (picking) {
      stopPicking();
      return;
    }
    picking = true;
    setOpen(true);
    pick.setAttribute('aria-pressed', 'true');
    pick.textContent = 'Picking…';
    document.addEventListener('pointermove', onPointerMove, true);
    document.addEventListener('click', onPickClick, true);
  };

  const onKeyDown = (event) => {
    if (event.altKey && event.shiftKey && event.key.toLowerCase() === 's') {
      event.preventDefault();
      setOpen(!open);
    } else if (event.key === 'Escape') {
      if (picking) stopPicking();
      else if (open) setOpen(false);
    }
  };

  badge.addEventListener('click', () => setOpen(!open));
  close.addEventListener('click', () => setOpen(false));
  pick.addEventListener('click', startPicking);
  document.addEventListener('keydown', onKeyDown);
  setStatus(status);
  setOpen(open);

  return {
    dispose() {
      stopPicking();
      document.removeEventListener('keydown', onKeyDown);
      host.remove();
    },
    setStatus,
    updateManifest(value) {
      manifest = value;
      render();
    },
  };
}
