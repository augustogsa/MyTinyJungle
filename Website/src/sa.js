// Site analytics (GA4). Loads gtag with the ID in <script data-ga="G-…">, then reports every
// interaction worth knowing: clicks on any link/button, store badges, contact links, language and
// theme switches, section views, scroll depth, engaged time, forms, FAQ opens, copies, rage clicks,
// JS errors, 404s and Core Web Vitals. No personal data is sent (no form values, no emails).
(function () {
  var me = document.currentScript, ID = me && me.dataset.ga;
  if (!ID || navigator.webdriver || /^(localhost|127\.|0\.0\.0\.0)/.test(location.hostname)) return;
  var w = window, d = document;
  w.dataLayer = w.dataLayer || [];
  var gtag = w.gtag = w.gtag || function () { w.dataLayer.push(arguments); };
  var attach = me.dataset.attach === "1"; // page already loads the Google tag (GTM): only add events
  if (!attach) gtag("consent", "default", { ad_storage: "denied", ad_user_data: "denied", ad_personalization: "denied", analytics_storage: "granted" });
  if (!attach) { gtag("js", new Date());
  gtag("config", ID, {
    site_name: me.dataset.site || location.hostname,
    page_language: d.documentElement.lang || "",
    theme: d.documentElement.dataset.theme || (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"),
    viewport: innerWidth < 768 ? "mobile" : innerWidth < 1100 ? "tablet" : "desktop"
  });
  var s = d.createElement("script"); s.async = true; s.src = "https://www.googletagmanager.com/gtag/js?id=" + ID; d.head.appendChild(s); }

  var ev = function (n, p) { p = p || {}; p.send_to = ID; p.page_path = p.page_path || location.pathname; gtag("event", n, p); };
  var txt = function (el) { return ((el.getAttribute("aria-label") || el.innerText || el.title || el.alt || (el.querySelector("img") || {}).alt || "") + "").replace(/\s+/g, " ").trim().slice(0, 100); };
  var where = function (el) {
    var sec = el.closest("section[id],header,footer,nav,main,[data-section]");
    if (!sec) return "page";
    return sec.dataset.section || sec.id || sec.tagName.toLowerCase();
  };
  var store = function (h) { return /apps\.apple\.com|itunes\.apple/.test(h) ? "app_store" : /play\.google\.com/.test(h) ? "google_play" : ""; };

  if (/404|not found/i.test(d.title) || d.body.dataset.page === "404") ev("page_not_found", { page_path: location.pathname, page_referrer: d.referrer });

  // Every click on something clickable.
  var last = { el: null, t: 0, n: 0 };
  d.addEventListener("click", function (e) {
    var el = e.target.closest && e.target.closest("a,button,[role=button],summary,[data-track],input[type=submit],label");
    var now = Date.now();
    if (e.target === last.el && now - last.t < 700) { if (++last.n === 3) ev("rage_click", { element_text: txt(e.target), section: where(e.target), page_path: location.pathname }); }
    else last.n = 1;
    last.el = e.target; last.t = now;
    if (!el) return;
    var href = el.href || "", p = {
      element_type: el.tagName.toLowerCase(), element_text: txt(el), element_id: el.id || "",
      element_classes: (el.className && el.className.baseVal === undefined ? el.className : "").toString().slice(0, 100),
      section: where(el), link_url: href, track_id: el.dataset.track || ""
    };
    ev("ui_click", p);
    var st = store(href);
    if (st) ev("store_click", { store: st, section: p.section, element_text: p.element_text, link_url: href });
    else if (/^mailto:/.test(href)) ev("contact_click", { method: "email", section: p.section });
    else if (/^tel:/.test(href)) ev("contact_click", { method: "phone", section: p.section });
    else if (href && el.host && el.host !== location.host) ev("outbound_click", { link_domain: el.host, link_url: href, section: p.section });
    else if (href && el.hash && el.pathname === location.pathname) ev("anchor_click", { target: el.hash, section: p.section });
    if (el.dataset.lang || el.hreflang) ev("language_switch", { from: d.documentElement.lang, to: el.dataset.lang || el.hreflang });
    if (el.matches(".lights,[data-theme-toggle]")) setTimeout(function () { ev("theme_toggle", { theme: d.documentElement.dataset.theme || "" }); }, 0);
    if (el.tagName === "SUMMARY") setTimeout(function () { if (el.parentNode.open) ev("faq_open", { question: p.element_text, section: p.section }); }, 0);
  }, true);

  // Sections seen (once each).
  if ("IntersectionObserver" in w) {
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (x) {
        if (!x.isIntersecting) return;
        io.unobserve(x.target);
        var h = x.target.querySelector("h1,h2,h3");
        ev("section_view", { section: x.target.dataset.section || x.target.id || x.target.tagName.toLowerCase(), section_title: h ? txt(h) : "" });
      });
    }, { threshold: 0.4 });
    var seen = new WeakSet(), watch = function () { d.querySelectorAll("section,footer,[data-section]").forEach(function (x) { if (!seen.has(x)) { seen.add(x); io.observe(x); } }); };
    watch(); new MutationObserver(watch).observe(d.body, { childList: true, subtree: true }); // client-routed pages
  }

  // Scroll depth.
  var marks = [25, 50, 75, 90, 100], hit = {};
  addEventListener("scroll", function () {
    var h = d.documentElement, pct = Math.round((scrollY + innerHeight) / h.scrollHeight * 100);
    marks.forEach(function (m) { if (pct >= m && !hit[m]) { hit[m] = 1; ev("scroll_depth", { percent: m }); } });
  }, { passive: true });

  // Engaged time while the tab is visible.
  var secs = 0, steps = [10, 30, 60, 120, 300];
  setInterval(function () {
    if (d.visibilityState !== "visible") return;
    secs++;
    if (steps.indexOf(secs) > -1) ev("engaged_time", { seconds: secs });
  }, 1000);

  // Forms: start and submit (names only, never values).
  var started = new WeakSet();
  d.addEventListener("focusin", function (e) {
    var f = e.target.form; if (!f || started.has(f)) return; started.add(f);
    ev("form_start_custom", { form_id: f.id || f.getAttribute("name") || f.action || "", field: e.target.name || e.target.type });
  });
  d.addEventListener("submit", function (e) { var f = e.target; ev("form_submit_custom", { form_id: f.id || f.getAttribute("name") || f.action || "", section: where(f) }); }, true);

  // Media.
  d.addEventListener("play", function (e) { if (e.target.tagName === "VIDEO" && !e.target.muted) ev("video_play", { video: (e.target.currentSrc || "").split("/").pop(), section: where(e.target) }); }, true);

  // Copies.
  d.addEventListener("copy", function () { ev("text_copy", { length: (getSelection() + "").length, section: where(getSelection().anchorNode && getSelection().anchorNode.parentElement || d.body) }); });

  // Errors.
  addEventListener("error", function (e) {
    if (e.target && e.target !== w && e.target.src) ev("resource_error", { resource: (e.target.src + "").slice(0, 150) });
    else if (e.message) ev("js_error", { message: (e.message + "").slice(0, 150), source: ((e.filename || "") + ":" + (e.lineno || 0)).slice(-100) });
  }, true);

  // Core Web Vitals.
  if (w.PerformanceObserver) {
    var vit = function (name, value) { ev("web_vital", { metric_name: name, metric_value: Math.round(name === "CLS" ? value * 1000 : value), value: Math.round(name === "CLS" ? value * 1000 : value), non_interaction: true }); };
    var lcp = 0, cls = 0, inp = 0;
    try { new PerformanceObserver(function (l) { var e = l.getEntries(); lcp = e[e.length - 1].startTime; }).observe({ type: "largest-contentful-paint", buffered: true }); } catch (e) {}
    try { new PerformanceObserver(function (l) { l.getEntries().forEach(function (e) { if (!e.hadRecentInput) cls += e.value; }); }).observe({ type: "layout-shift", buffered: true }); } catch (e) {}
    try { new PerformanceObserver(function (l) { l.getEntries().forEach(function (e) { if (e.interactionId) inp = Math.max(inp, e.duration); }); }).observe({ type: "event", buffered: true, durationThreshold: 16 }); } catch (e) {}
    var sent = false;
    var flush = function () {
      if (sent || d.visibilityState !== "hidden") return; sent = true;
      var nav = performance.getEntriesByType("navigation")[0];
      if (nav) vit("TTFB", nav.responseStart);
      if (lcp) vit("LCP", lcp); vit("CLS", cls); if (inp) vit("INP", inp);
    };
    addEventListener("visibilitychange", flush); addEventListener("pagehide", function () { d.visibilityState === "hidden" || (sent = false); flush(); });
  }
})();
