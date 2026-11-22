// Makes the JS-visible identity match a Safari User-Agent.
(function () {
  try { delete Navigator.prototype.userAgentData; } catch (e) {}
  try { Object.defineProperty(Navigator.prototype, "vendor", { get: function () { return "Apple Computer, Inc."; }, configurable: true }); } catch (e) {}
})();
