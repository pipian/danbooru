(function() {
  Danbooru.RelatedTag = {};

  Danbooru.RelatedTag.initialize_all = function() {
    if ($("#c-posts").length || $("#c-uploads").length) {
      this.initialize_buttons();
      $("#related-tags-container").hide();
      $("#artist-tags-container").hide();
    }
  }

  Danbooru.RelatedTag.initialize_buttons = function() {
    this.common_bind("#related-tags-button", "");
    this.common_bind("#related-artists-button", "artist");
    this.common_bind("#related-characters-button", "character");
    this.common_bind("#related-copyrights-button", "copyright");
    $("#find-artist-button").click(Danbooru.RelatedTag.find_artist);
  }

  Danbooru.RelatedTag.tags_include = function(name) {
    var current = $("#upload_tag_string,#post_tag_string").val().toLowerCase().match(/\S+/g) || [];
    if ($.inArray(name.toLowerCase(), current) > -1) {
      return true;
    } else {
      return false;
    }
  }

  Danbooru.RelatedTag.common_bind = function(button_name, category) {
    $(button_name).click(function(e) {
      $("#related-tags").html("<em>Loading...</em>");
      $("#related-tags-container").show();
      $.get("/related_tag.json", {
        "query": Danbooru.RelatedTag.current_tag(),
        "category": category
      }).success(Danbooru.RelatedTag.process_response);
      $("#artist-tags-container").hide();
      e.preventDefault();
    });
  }

  Danbooru.RelatedTag.current_tag = function() {
    // 1. abc def |  -> def
    // 2. abc def|   -> def
    // 3. abc de|f   -> def
    // 4. abc |def   -> def
    // 5. abc| def   -> abc
    // 6. ab|c def   -> abc
    // 7. |abc def   -> abc
    // 8. | abc def  -> abc

    var $field = $("#upload_tag_string,#post_tag_string");
    var string = $field.val();
    var n = string.length;
    var a = $field.get(0).selectionStart;
    var b = $field.get(0).selectionStart;

    if ((a > 0) && (a < (n - 1)) && (!/\s/.test(string[a])) && (/\s/.test(string[a - 1]))) {
      // 4 is the only case where we need to scan forward. in all other cases we
      // can drag a backwards, and then drag b forwards.

      while ((b < n) && (!/\s/.test(string[b]))) {
        b++;
      }
    } else if (string.search(/\S/) > b) { // case 8
      b = string.search(/\S/);
      while ((b < n) && (!/\s/.test(string[b]))) {
        b++;
      }
    } else {
      while ((a > 0) && ((/\s/.test(string[a])) || (string[a] === undefined))) {
        a--;
        b--;
      }

      while ((a > 0) && (!/\s/.test(string[a - 1]))) {
        a--;
        b--;
      }

      while ((b < (n - 1)) && (!/\s/.test(string[b]))) {
        b++;
      }
    }

    b++;
		return string.slice(a, b);
  }

  Danbooru.RelatedTag.process_response = function(data) {
    Danbooru.RelatedTag.recent_search = data;
    Danbooru.RelatedTag.build_all();
  }

  Danbooru.RelatedTag.build_all = function() {
    if (Danbooru.RelatedTag.recent_search === null || Danbooru.RelatedTag.recent_search === undefined) {
      return;
    }

    $("#related-tags").show();

    var query = Danbooru.RelatedTag.recent_search.query;
    var related_tags = Danbooru.RelatedTag.recent_search.tags;
    var wiki_page_tags = Danbooru.RelatedTag.recent_search.wiki_page_tags;
    var $dest = $("#related-tags");
    $dest.empty();

    $dest.append(this.build_html("recent", this.other_tags(Danbooru.Cookie.get("recent_tags_with_categories"))));
    $dest.append(this.build_html("frequent", this.other_tags(Danbooru.Cookie.get("favorite_tags_with_categories"))));
    $dest.append(this.build_html(query, related_tags));
    if (wiki_page_tags.length) {
      $dest.append(Danbooru.RelatedTag.build_html("wiki:" + query, wiki_page_tags));
    }
    if (Danbooru.RelatedTag.recent_artists) {
      var tags = [];
      if (Danbooru.RelatedTag.recent_artists.length === 0) {
        tags.push([" none", 0]);
      } else if (Danbooru.RelatedTag.recent_artists.length === 1) {
        tags.push([Danbooru.RelatedTag.recent_artists[0].name, 1]);
        if (Danbooru.RelatedTag.recent_artists[0].is_banned === true) {
          tags.push(["BANNED_ARTIST", "banned"]);
        }
        $.each(Danbooru.RelatedTag.recent_artists[0].urls, function(i, url) {
          tags.push([" " + url.url, 0]);
        });
      } else if (Danbooru.RelatedTag.recent_artists.length >= 10) {
        tags.push([" none", 0]);
      } else {
        $.each(Danbooru.RelatedTag.recent_artists, function(i, artist) {
          tags.push([artist.name, 1]);
        });
      }
     $dest.append(Danbooru.RelatedTag.build_html("artist", tags, true));
    }
  }

  Danbooru.RelatedTag.other_tags = function(string) {
    if (string && string.length) {
      return $.map(string.match(/\S+ \d+/g), function(x, i) {
        var submatch = x.match(/(\S+) (\d+)/);
        return [[submatch[1], submatch[2]]];
      });
    } else {
      return [];
    }
  }

  Danbooru.RelatedTag.build_html = function(query, related_tags, is_wide_column) {
    if (query === null || query === "") {
      return "";
    }

    query = query.replace(/_/g, " ");
    var header = $("<em/>");

    var match = query.match(/^wiki:(.+)/);
    if (match) {
      header.html($("<a/>").attr("href", "/wiki_pages?title=" + encodeURIComponent(match[1])).attr("target", "_blank").text(query));
    } else {
      header.text(query);
    }

    var $div = $("<div/>");
    $div.addClass("tag-column");
    if (is_wide_column) {
      $div.addClass("wide-column");
    }
    var $ul = $("<ul/>");
    $ul.append(
      $("<li/>").append(
        header
      )
    );

    $.each(related_tags, function(i, tag) {
      if (tag[0][0] !== " ") {
        var $link = $("<a/>");
        $link.text(tag[0].replace(/_/g, " "));
        $link.addClass("tag-type-" + tag[1]);
        $link.attr("href", "/posts?tags=" + encodeURIComponent(tag[0]));
        $link.click(Danbooru.RelatedTag.toggle_tag);
        if (Danbooru.RelatedTag.tags_include(tag[0])) {
          $link.addClass("selected");
        }
        $ul.append(
          $("<li/>").append($link)
        );
      } else {
        $ul.append($("<li/>").text(tag[0]));
      }
    });

    $div.append($ul);
    return $div;
  }

  Danbooru.RelatedTag.toggle_tag = function(e) {
    var $field = $("#upload_tag_string,#post_tag_string");
    var tag = $(e.target).html().replace(/ /g, "_").replace(/&gt;/g, ">").replace(/&lt;/g, "<").replace(/&amp;/g, "&");

    if (Danbooru.RelatedTag.tags_include(tag)) {
      var escaped_tag = Danbooru.regexp_escape(tag);
      $field.val($field.val().replace(new RegExp("(^|\\s)" + escaped_tag + "($|\\s)", "gi"), "$1$2"));
    } else {
      $field.val($field.val() + " " + tag);
    }
    $field.val($field.val().trim().replace(/ +/g, " ") + " ");

    $field[0].selectionStart = $field.val().length;
    Danbooru.RelatedTag.build_all();
    if (Danbooru.RelatedTag.recent_artist && $("#artist-tags-container").css("display") === "block") {
      Danbooru.RelatedTag.process_artist(Danbooru.RelatedTag.recent_artist);
    }

    if ($(window).scrollTop() <= $field.offset().top + $field.outerHeight()) {
      $field.focus();
    }

    e.preventDefault();
  }

  Danbooru.RelatedTag.find_artist = function(e) {
    $("#artist-tags").html("<em>Loading...</em>");
    var url = $("#upload_source,#post_source");
    $.get("/artists.json", {"limit": 20, "search[name]": url.val()}).success(Danbooru.RelatedTag.process_artist);
    e.preventDefault();
  }

  Danbooru.RelatedTag.process_artist = function(data) {
    Danbooru.RelatedTag.recent_artists = data;
    Danbooru.RelatedTag.build_all();
  }
})();

$(function() {
  Danbooru.RelatedTag.initialize_all();
});
