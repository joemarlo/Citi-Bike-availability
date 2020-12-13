$(document).on('shiny:sessioninitialized', function (e) {
  var mobile = window.matchMedia("only screen and (max-width: 767px)").matches;
  Shiny.onInputChange('is_mobile_device', mobile);
});
