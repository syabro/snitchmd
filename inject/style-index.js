// Lightpanda lacks indexed access to inline styles (style[0] is undefined while
// style.item(0) works). React sites such as Substack read style[i] and crash.
// Defines getters for the first MAX_INDEXED_PROPS indexes.
(function () {
  var MAX_INDEXED_PROPS = 200;
  var proto = CSSStyleDeclaration.prototype;

  for (var i = 0; i < MAX_INDEXED_PROPS; i++) {
    defineIndex(i);
  }

  function defineIndex(i) {
    Object.defineProperty(proto, i, {
      get: function () { return i < this.length ? this.item(i) : undefined; },
      configurable: true,
    });
  }
})();
