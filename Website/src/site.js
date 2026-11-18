// Stage crossfade, section entrances, and the "ask a plant" chat. The page reads fine without it.
(function () {
  var d = document, root = d.documentElement;
  root.classList.add("js");
  var io = "IntersectionObserver" in window;

  // Living favicon: Erty waves in the browser tab.
  (function () {
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    var sp = new Image(), cv = d.createElement("canvas"), cx, links, n = 0, f = 0, tm;
    cv.width = cv.height = 64; cx = cv.getContext("2d");
    sp.onload = function () {
      n = Math.round(sp.width / 64);
      links = d.querySelectorAll('link[rel="icon"]');
      var tick = function () {
        cx.clearRect(0, 0, 64, 64); cx.drawImage(sp, f * 64, 0, 64, 64, 0, 0, 64, 64);
        var u = cv.toDataURL("image/png"); links.forEach(function (l) { l.href = u; });
        f = (f + 1) % n;
      };
      var run = function () { clearInterval(tm); if (!d.hidden) tm = setInterval(tick, 90); };
      d.addEventListener("visibilitychange", run); run();
    };
    sp.src = "/assets/erty/favicon-sprite.png?v=2";
  })();

  // Brand: on touch screens, a tap on the name grows the leaves briefly.
  var brand = d.querySelector(".brand");
  if (brand && matchMedia("(hover: none)").matches) brand.addEventListener("touchstart", function () { brand.classList.add("grow"); setTimeout(function () { brand.classList.remove("grow"); }, 1600); }, { passive: true });

  // Stage: show the layer matching the chapter in the middle of the screen.
  var layers = d.querySelectorAll(".stage .layer");
  if (layers.length && io) {
    var show = function (k) { layers.forEach(function (l) { l.classList.toggle("on", l.dataset.scene === k); }); };
    var secs = d.querySelectorAll(".read [data-scene]"), cur = "0", tick = false;
    var pick = function () {
      tick = false; var k = "0", mid = innerHeight * 0.5;
      secs.forEach(function (s) { if (s.getBoundingClientRect().top < mid) k = s.dataset.scene; });
      if (k !== cur) { cur = k; show(k); }
    };
    addEventListener("scroll", function () { if (!tick) { tick = true; requestAnimationFrame(pick); } }, { passive: true });
    addEventListener("resize", pick); pick();
  }

  // Entrances, one system for the whole site: every block rises in, staggered within its section.
  var reduceM = matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (io) {
    var SEL = "h1,h2,h3,p,ul,ol,figure,details,.btn,.acard,.fcard,.field,.hc,.facts > *,.agrid > *,.fgrid > *,.inputs > *,.mosaic figure,.phone,.m-scene,.talk,.qhead > *,.fhero,.fnav,.slider";
    var SKIP = ".stage,.nav,.msgs,.lockphone,.vs2,.talk *,.phone *,.m-scene *,.slider *,.agrid *,.fgrid *,.facts > * *,.field *,.hc *,.acard *,.fcard *,footer,.hero h1";
    var eo = new IntersectionObserver(function (es) {
      es.forEach(function (e) { if (e.isIntersecting) { e.target.setAttribute("data-entered", ""); eo.unobserve(e.target); } });
    }, { rootMargin: "0px 0px -10% 0px" });
    d.querySelectorAll("main section, main .chapter, .doc .paper").forEach(function (sec) {
      var i = 0;
      sec.querySelectorAll(SEL).forEach(function (el) {
        if (el.closest(SKIP) || el.hasAttribute("data-enter")) return;
        var up = el.parentElement.closest("[data-enter]"); if (up && sec.contains(up)) return;
        el.setAttribute("data-enter", ""); el.style.setProperty("--enter-i", Math.min(i++, 8)); eo.observe(el);
      });
    });
    root.classList.add("enter-ready");
    // Safety net: anything already scrolled past (fast flicks, anchors, restored scroll) is shown.
    var pend = false, sweep = function () {
      pend = false;
      d.querySelectorAll("[data-enter]:not([data-entered])").forEach(function (el) {
        if (el.getBoundingClientRect().top < innerHeight * 0.9) { el.setAttribute("data-entered", ""); eo.unobserve(el); }
      });
    };
    addEventListener("scroll", function () { if (!pend) { pend = true; setTimeout(sweep, 200); } }, { passive: true });
    addEventListener("load", sweep);
  }

  // Hero headline: words rise out of their line on load.
  var h1 = d.querySelector(".hero h1");
  if (h1 && !reduceM) {
    var w = 0;
    (function split(n) {
      Array.prototype.slice.call(n.childNodes).forEach(function (c) {
        if (c.nodeType === 3) {
          var f = d.createDocumentFragment();
          c.textContent.split(/(\s+)/).forEach(function (t) {
            if (!t) return;
            if (/^\s+$/.test(t)) { f.appendChild(d.createTextNode(t)); return; }
            var o = d.createElement("span"), i2 = d.createElement("span");
            o.className = "hw"; i2.textContent = t; i2.style.setProperty("--w", w++); o.appendChild(i2); f.appendChild(o);
          });
          c.parentNode.replaceChild(f, c);
        } else if (c.nodeType === 1 && c.tagName !== "BR") split(c);
      });
    })(h1);
    h1.classList.add("words");
  }

  // Nav tucks away while reading down, returns on the way up.
  var nav = d.querySelector(".nav"), lastY = scrollY;
  if (nav) addEventListener("scroll", function () {
    var y = scrollY; nav.toggleAttribute("data-tucked", y > lastY && y > 240); lastY = y;
  }, { passive: true });

  // Stage reel: the active caption fills up, then hands over to the next screen.
  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  layers.forEach(function (l) {
    var dots = l.querySelectorAll(".rdot"), img = l.querySelector(".phone-screen img");
    if (!dots.length || !img) return;
    var cur = 0;
    var go = function (i) {
      cur = i;
      dots.forEach(function (x, j) { x.classList.remove("on"); void x.offsetWidth; x.classList.toggle("on", j === i); x.setAttribute("aria-pressed", j === i); });
      img.classList.add("fade");
      setTimeout(function () { img.src = dots[i].dataset.src; img.alt = dots[i].textContent; img.classList.remove("fade"); }, 220);
    };
    dots.forEach(function (x, i) {
      x.innerHTML = "<span>" + x.textContent + "</span>";
      x.addEventListener("click", function () { go(i); });
      x.addEventListener("animationend", function () { if (!reduce && x.classList.contains("on")) go((i + 1) % dots.length); });
    });
    new MutationObserver(function () { if (l.classList.contains("on")) go(0); }).observe(l, { attributes: true, attributeFilter: ["class"] });
  });

  // Screen sliders (phone layout).
  d.querySelectorAll(".slider").forEach(function (sl) {
    var tr = sl.querySelector(".track"), pv = sl.querySelector(".prev"), nx = sl.querySelector(".next");
    var step = function () { var f = tr.querySelector(".slide"); return f ? f.getBoundingClientRect().width + 22 : 240; };
    var upd = function () { pv.disabled = tr.scrollLeft < 4; nx.disabled = tr.scrollLeft + tr.clientWidth >= tr.scrollWidth - 4; sl.querySelector(".snav").hidden = tr.scrollWidth <= tr.clientWidth + 4; };
    pv.addEventListener("click", function () { tr.scrollBy({ left: -step() }); });
    nx.addEventListener("click", function () { tr.scrollBy({ left: step() }); });
    tr.addEventListener("scroll", upd, { passive: true }); addEventListener("resize", upd); upd();
  });

  // Ask a plant.
  var talk = d.querySelector(".talk");
  if (!talk) return;
  var answers = JSON.parse(talk.dataset.answers), log = talk.querySelector(".log");
  var plant = talk.querySelector(".chip.on").dataset.plant;
  talk.querySelectorAll(".chip").forEach(function (c) {
    c.addEventListener("click", function () {
      plant = c.dataset.plant;
      talk.querySelectorAll(".chip").forEach(function (x) { x.classList.toggle("on", x === c); x.setAttribute("aria-pressed", x === c); });
    });
  });
  var bubble = function (cls, html) {
    var p = d.createElement("p"); p.className = "b new " + cls; p.innerHTML = html; log.appendChild(p);
    while (log.children.length > 4) log.removeChild(log.firstChild);
  };
  talk.querySelectorAll(".ask").forEach(function (a) {
    a.addEventListener("click", function () {
      bubble("me", a.textContent);
      var who = plant, txt = answers[who][+a.dataset.q];
      setTimeout(function () { bubble("plant", "<b>" + who + "</b>" + txt); }, 450);
    });
  });
})();

// Plant voices: messages arrive one by one with a typing indicator; lock-screen notifications drop in
(() => {
  if (matchMedia("(prefers-reduced-motion: reduce)").matches || !("IntersectionObserver" in window)) return;
  const play = (box, items, step, fn) => {
    items.forEach(el => el.classList.add("pending")); box.classList.add("anim");
    const io = new IntersectionObserver(es => {
      if (!es.some(e => e.isIntersecting)) return;
      io.disconnect();
      items.forEach((el, i) => setTimeout(() => fn(el), i * step));
    }, { threshold: 0.25 });
    io.observe(box);
  };
  const msgs = document.querySelector(".msgs");
  if (msgs) play(msgs, [...msgs.querySelectorAll(".msg")], 1100, m => {
    const b = m.querySelector(".bub"); m.classList.add("typing"); m.classList.remove("pending");
    setTimeout(() => { m.classList.remove("typing"); m.classList.add("said"); }, 650);
  });
  const lock = document.querySelector(".lockphone");
  if (lock) play(lock, [...lock.querySelectorAll(".ncard")].reverse(), 450, n => { n.classList.remove("pending"); n.classList.add("drop"); });
})();
(() => {
  const v = document.querySelector(".vs2");
  if (!v || matchMedia("(prefers-reduced-motion: reduce)").matches || !("IntersectionObserver" in window)) return;
  v.classList.add("wait");
  const io = new IntersectionObserver(es => { if (es.some(e => e.isIntersecting)) { io.disconnect(); v.classList.replace("wait", "go"); } }, { threshold: .3 });
  io.observe(v);
})();
