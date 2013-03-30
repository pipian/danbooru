class ApplicationController < ActionController::Base
  protect_from_forgery
  helper :pagination
  before_filter :set_current_user
  after_filter :reset_current_user
  before_filter :set_title
  before_filter :set_started_at_session
  before_filter :api_check
  layout "default"

  rescue_from User::PrivilegeError, :with => :access_denied
  rescue_from Danbooru::Paginator::PaginationError, :with => :render_pagination_limit

protected
  def api_check
    if request.format.to_s =~ /\/json|\/xml/
      if CurrentUser.is_anonymous?
        render :text => "401 Not Authorized\n", :layout => false, :status => 401
        return false
      end

      if ApiLimiter.throttled?(request.remote_ip)
        render :text => "421 User Throttled\n", :layout => false, :status => 421
        return false
      end
    end
    
    return true
  end

  def rescue_exception(exception)
    @exception = exception

    if exception.is_a?(::ActiveRecord::StatementInvalid) && exception.to_s =~ /statement timeout/
      @exception = nil
      @error_message = "The database timed out running your query."
      render :template => "static/error", :status => 500
    elsif exception.is_a?(::ActiveRecord::RecordNotFound)
      @exception = nil
      @error_message = "That record was not found"
      render :template => "static/error", :status => 404
    else
      render :template => "static/error", :status => 500
    end
  end

  def render_pagination_limit
    @error_message = "You can only view up to #{Danbooru.config.max_numbered_pages} pages. Please narrow your search terms."
    render :template => "static/error", :status => 410
  end

  def access_denied
    previous_url = params[:url] || request.fullpath

    respond_to do |fmt|
      fmt.html do
        if request.get?
          redirect_to new_session_path(:url => previous_url), :notice => "Access denied"
        else
          redirect_to new_session_path, :notice => "Access denied"
        end
      end
      fmt.xml do
        render :xml => {:success => false, :reason => "access denied"}.to_xml(:root => "response"), :status => 403
      end
      fmt.json do
        render :json => {:success => false, :reason => "access denied"}.to_json, :status => 403
      end
    end
  end

  def set_current_user
    session_loader = SessionLoader.new(session, cookies, request, params)
    session_loader.load
  end

  def reset_current_user
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  def set_started_at_session
    if session[:started_at].blank?
      session[:started_at] = Time.now
    end
  end

  %w(member banned builder privileged platinum contributor janitor moderator admin).each do |level|
    define_method("#{level}_only") do
      if CurrentUser.user.__send__("is_#{level}?")
        true
      else
        access_denied()
        false
      end
    end
  end

  def set_title
    @page_title = Danbooru.config.app_name + "/#{params[:controller]}"
  end
end
