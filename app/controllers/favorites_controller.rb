class FavoritesController < ApplicationController
  before_filter :member_only

  def index
    if params[:tags]
      redirect_to(posts_path(:tags => params[:tags]))
    elsif request.format == Mime::JS
      list_favorited_users
    else
      @favorite_set = PostSets::Favorite.new(CurrentUser.user, params[:page], params)
    end
  end

  def create
    if CurrentUser.favorite_limit.nil? || CurrentUser.favorite_count < CurrentUser.favorite_limit
      @post = Post.find(params[:post_id])
      @post.add_favorite!(CurrentUser.user)
    else
      @error_msg = "You can only keep up to #{CurrentUser.favorite_limit} favorites. Upgrade your account to save more."
    end
  end

  def destroy
    @post = Post.find(params[:id])
    @post.remove_favorite!(CurrentUser.user)
  end

  def list_favorited_users
    @post = Post.find(params[:post_id])
    render :action => "list_favorited_users"
  end
end
