// Stage crossfade, section entrances, and the "ask a plant" chat. The page reads fine without it.
(function () {
  var d = document, root = d.documentElement;
  root.classList.add("js");
  var io = "IntersectionObserver" in window;

  // Stage: show the layer matching the chapter in the middle of the screen.
  var layers = d.querySelectorAll(".stage .layer");
  if (layers.length && io) {
    var show = function (k) { layers.forEach(function (l) { l.classList.toggle("on", l.dataset.scene === k); }); };
    var so = new IntersectionObserver(function (es) {
      es.forEach(function (e) { if (e.isIntersecting) show(e.target.dataset.scene); });
    }, { rootMargin: "-45% 0px -45% 0px" });
    d.querySelectorAll(".read [data-scene]").forEach(function (s) { so.observe(s); });
  }

  // Entrances: heading, text, then pictures, staggered.
  var parts = d.querySelectorAll(".chapter > *, .features h2, .frow, .beta .bgrid > *, .field > *, .faq h2, .qtext p, .ctext > *");
  if (io && !matchMedia("(prefers-reduced-motion: reduce)").matches) {
    var ro = new IntersectionObserver(function (es) {
      es.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add("in"); ro.unobserve(e.target); } });
    }, { rootMargin: "0px 0px -8% 0px" });
    parts.forEach(function (p) {
      var i = Array.prototype.indexOf.call(p.parentNode.children, p);
      p.classList.add("rv"); p.style.transitionDelay = Math.min(i, 6) * 75 + "ms"; ro.observe(p);
    });
  }

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
