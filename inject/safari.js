// Sets JS navigator properties to match Safari: deletes userAgentData, sets vendor to Apple.
(function () {
  delete Navigator.prototype.userAgentData;

  Object.defineProperty(Navigator.prototype, "vendor", {
    get: function () { return "Apple Computer, Inc."; },
    configurable: true,
  });
})();
