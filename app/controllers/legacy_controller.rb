class LegacyController < ApplicationController
  before_filter :member_only, :only => [:create_post]

  def posts
    @post_set = PostSets::Post.new(tag_query, params[:page], params[:limit])
    @posts = @post_set.posts
  end
  
  def create_post
    @upload = Upload.create(params[:post].merge(:server => Socket.gethostname))
    @upload.delay.process!
    render :nothing => true
  end
  
  def users
    @users = User.search(params).limit(100)
  end
  
  def tags
    @tags = Tag.search(params).limit(100)
  end
  
  def unavailable
    render :text => "this resource is no longer available", :status => 410
  end

private
  def tag_query
    params[:tags] || (params[:post] && params[:post][:tags])
  end
end
