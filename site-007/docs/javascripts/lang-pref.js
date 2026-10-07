/* Remember the language chosen in the Material language switcher so the root
   page (docs/index.md) sends returning visitors to the same language. */
(function () {
  "use strict";
  function remember(event) {
    var link = event.target.closest && event.target.closest("a[hreflang]");
    if (!link) { return; }
    var lang = link.getAttribute("hreflang");
    if (lang !== "en" && lang !== "fr") { return; }
    try { localStorage.setItem("apiops007-lang", lang); } catch (e) { /* storage blocked */ }
  }
  document.addEventListener("click", remember);
})();
