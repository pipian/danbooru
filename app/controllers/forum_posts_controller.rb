class ForumPostsController < ApplicationController
  respond_to :html, :xml, :json, :js
  before_filter :member_only, :except => [:index, :show]
  rescue_from User::PrivilegeError, :with => "static/access_denied"

  def new
    @forum_topic = ForumTopic.find(params[:topic_id]) if params[:topic_id]
    @forum_post = ForumPost.new_reply(params)
    respond_with(@forum_post)
  end

  def edit
    @forum_post = ForumPost.find(params[:id])
    check_privilege(@forum_post)
    respond_with(@forum_post)
  end

  def index
    if CurrentUser.is_janitor?
      @search = ForumPost.search(params[:search])
    else
      @search = ForumPost.active.search(params[:search])
    end
    @forum_posts = @search.order("forum_posts.id DESC").paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
    respond_with(@forum_posts) do |format|
      format.xml do
        render :xml => @forum_posts.to_xml(:root => "forum-posts")
      end
    end
  end

  def search
  end

  def show
    @forum_post = ForumPost.find(params[:id])
    if request.format == "text/html" && @forum_post.id == @forum_post.topic.original_post.id
      redirect_to(forum_topic_path(@forum_post.topic))
    else
      respond_with(@forum_post)
    end
  end

  def create
    @forum_post = ForumPost.create(params[:forum_post])
    respond_with(@forum_post, :location => forum_topic_path(@forum_post.topic, :page => @forum_post.topic.last_page))
  end

  def update
    @forum_post = ForumPost.find(params[:id])
    check_privilege(@forum_post)
    @forum_post.update_attributes(params[:forum_post])
    respond_with(@forum_post, :location => forum_topic_path(@forum_post.topic, :page => @forum_post.forum_topic_page))
  end

  def destroy
    @forum_post = ForumPost.find(params[:id])
    raise User::PrivilegeError unless @forum_post.editable_by?(CurrentUser.user)
    @forum_post.update_column(:is_deleted, true)
    respond_with(@forum_post)
  end

  def undelete
    @forum_post = ForumPost.find(params[:id])
    check_privilege(@forum_post)
    @forum_post.update_attribute(:is_deleted, false)
    respond_with(@forum_post)
  end

private
  def check_privilege(forum_post)
    if !forum_post.editable_by?(CurrentUser.user)
      raise User::PrivilegeError
    end
  end
end
