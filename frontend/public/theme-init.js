(function () {
  try {
    var theme = localStorage.getItem('pa-theme');
    if (theme === 'light' || theme === 'dark') document.documentElement.setAttribute('data-theme', theme);
  } catch (e) {}
})();
