(function () {
  var launch = document.getElementById('launch');
  if (!launch) return;
  var capacitor = window.Capacitor;
  var installed =
    window.matchMedia('(display-mode: standalone)').matches ||
    window.navigator.standalone === true ||
    !!(capacitor && capacitor.isNativePlatform && capacitor.isNativePlatform());
  if (installed) launch.dataset.installed = '';
})();
