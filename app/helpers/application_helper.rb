module ApplicationHelper
  def nav_link_to(text, url, options = nil)
    if nav_link_match(params[:controller], url)
      klass = "current"
    else
      klass = nil
    end

    content_tag("li", link_to(text, url, options), :class => klass)
  end

  def fast_link_to(text, link_params, options = {})
    if options
      attributes = options.map do |k, v|
        %{#{k}="#{h(v)}"}
      end.join(" ")
    else
      attributes = ""
    end

    if link_params.is_a?(Hash)
      action = link_params.delete(:action)
      controller = link_params.delete(:controller) || controller_name
      id = link_params.delete(:id)

      link_params = link_params.map {|k, v| "#{k}=#{u(v)}"}.join("&")

      if link_params.present?
        link_params = "?#{link_params}"
      end

      if id
        url = "/#{controller}/#{action}/#{id}#{link_params}"
      else
        url = "/#{controller}/#{action}#{link_params}"
      end
    else
      url = link_params
    end

    raw %{<a href="#{h(url)}" #{attributes}>#{text}</a>}
  end

  def format_text(text, options = {})
    DText.parse(text)
  end

  def error_messages_for(instance_name)
    instance = instance_variable_get("@#{instance_name}")

    if instance && instance.errors.any?
      %{<div class="error-messages ui-state-error ui-corner-all"><strong>Error</strong>: #{instance.__send__(:errors).full_messages.join(", ")}</div>}.html_safe
    else
      ""
    end
  end

  def time_tag(content, time)
    zone = time.strftime("%z")
    datetime = time.strftime("%Y-%m-%dT%H:%M" + zone[0, 3] + ":" + zone[3, 2])

    content_tag(:time, content || datetime, :datetime => datetime, :title => time.to_formatted_s)
  end

  def time_ago_in_words_tagged(time)
    raw time_tag(time_ago_in_words(time) + " ago", time)
  end

  def compact_time(time)
    time_tag(time.strftime("%Y-%m-%d %H:%M"), time)
  end

  def mod_link_to_user(user, positive_or_negative)
    html = ""
    html << link_to(user.name, user_path(user))

    if positive_or_negative == :positive
      html << " [" + link_to("+", new_user_feedback_path(:user_feedback => {:category => "positive", :user_id => user.id})) + "]"

      unless user.is_privileged?
        html << " [" + link_to("invite", new_moderator_invitation_path(:invitation => {:name => user.name, :level => User::Levels::CONTRIBUTOR})) + "]"
      end
    else
      html << " [" + link_to("&ndash;".html_safe, new_user_feedback_path(:user_feedback => {:category => "negative", :user_id => user.id})) + "]"
    end

    html.html_safe
  end

  def dtext_field(object, name, options = {})
    options[:name] ||= "Body"
    options[:input_id] ||= "#{object}_#{name}"
    options[:input_name] ||= "#{object}[#{name}]"
    options[:value] ||= instance_variable_get("@#{object}").try(name)
    options[:preview_id] ||= "dtext-preview"

    render "dtext/form", options
  end

  def dtext_preview_button(object, name, options = {})
    options[:input_id] ||= "#{object}_#{name}"
    options[:preview_id] ||= "dtext-preview"
    submit_tag("Preview", "data-input-id" => options[:input_id], "data-preview-id" => options[:preview_id])
  end

  def search_field(method, options = {})
    method = method.to_s
    name = options[:label] || method.titleize
    string = '<div class="input"><label for="search_' + method + '">' + name + '</label><input type="text" name="search[' + method + ']" id="search_'  + method + '">'
    if options[:hint]
      string += '<p class="hint">' + options[:hint] + '</p>'
    end
    string += '</div>'
    string.html_safe
  end

protected
  def nav_link_match(controller, url)
    url =~ case controller
    when "sessions", "users", "maintenance/user/login_reminders", "maintenance/user/password_resets", "admin/users", "tag_subscriptions"
      /^\/(session|users)/

    when "forum_posts"
      /^\/forum_topics/

    when "comments"
      /^\/comments/

    when "notes", "note_versions"
      /^\/notes/

    when "posts", "uploads", "post_versions", "explore/posts", "moderator/post/dashboards", "favorites"
      /^\/post/

    when "artists", "artist_versions"
      /^\/artist/

    when "tags"
      /^\/tags/

    when "pools"
      /^\/pools/

    when "moderator/dashboards"
      /^\/moderator/

    when "tag_aliases", "tag_alias_corrections", "tag_alias_requests"
      /^\/tag_aliases/

    when "tag_implications", "tag_implication_requests"
      /^\/tag_implications/

    when "wiki_pages", "wiki_page_versions"
      /^\/wiki_pages/

    when "forum_topics", "forum_posts"
      /^\/forum_topics/

    else
      /^\/static/
    end
  end
end
