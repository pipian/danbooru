(function() {
  Danbooru.Dtext = {};

  Danbooru.Dtext.initialize_all = function() {
    Danbooru.Dtext.initialize_links();
    Danbooru.Dtext.initialize_expandables();
  }

  Danbooru.Dtext.initialize_links = function() {
    $(".simple_form .dtext-preview").hide();
    $(".simple_form input[value=Preview]").click(Danbooru.Dtext.click_button);
  }

  Danbooru.Dtext.initialize_expandables = function() {
    $(".expandable-content").hide();
    $(".expandable-button").click(function(e) {
      $(this).parent().next().fadeToggle("fast");
    });
  }

  Danbooru.Dtext.call_preview = function(e, $button, $input, $preview) {
    $button.val("Edit");
    $input.hide();
    $preview.text("Loading...").fadeIn("fast");
    $.ajax({
      type: "post",
      url: "/dtext_preview",
      data: {
        body: $input.val()
      },
      success: function(data) {
        $preview.html(data).fadeIn("fast");
        Danbooru.Dtext.initialize_expandables();
      }
    });
  }

  Danbooru.Dtext.call_edit = function(e, $button, $input, $preview) {
    $button.val("Preview");
    $preview.hide();
    $input.slideDown("fast");
  }

  Danbooru.Dtext.click_button = function(e) {
    var $button = $(e.target);
    var $input = $("#" + $button.data("input-id"));
    var $preview = $("#" + $button.data("preview-id"));

    if ($button.val().match(/preview/i)) {
      Danbooru.Dtext.call_preview(e, $button, $input, $preview);
    } else {
      Danbooru.Dtext.call_edit(e, $button, $input, $preview);
    }

    e.preventDefault();
  }
})();

$(document).ready(function() {
  Danbooru.Dtext.initialize_all();
});
