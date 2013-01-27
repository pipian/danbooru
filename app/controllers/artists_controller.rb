class ArtistsController < ApplicationController
  respond_to :html, :xml, :json
  before_filter :member_only, :except => [:index, :show, :banned]
  
  def new
    @artist = Artist.new_with_defaults(params)
    respond_with(@artist)
  end
  
  def edit
    @artist = Artist.find(params[:id])
    respond_with(@artist)
  end
  
  def banned
    @artists = Artist.where("is_banned = ?", true).order("name")
    respond_with(@artists)
  end
  
  def index
    @artists = Artist.search(params[:search]).paginate(params[:page])
    respond_with(@artists) do |format|
      format.xml do
        render :xml => @artists.to_xml(:include => [:urls])
      end
      format.json do
        render :json => @artists.to_json(:include => [:urls])
      end
    end
  end
  
  def search
  end
  
  def show
    @artist = Artist.find(params[:id])
    @post_set = PostSets::Artist.new(@artist)
    respond_with(@artist)
  end
  
  def create
    @artist = Artist.create(params[:artist], :as => CurrentUser.role)
    respond_with(@artist)
  end
  
  def update
    @artist = Artist.find(params[:id])
    @artist.update_attributes(params[:artist], :as => CurrentUser.role)
    respond_with(@artist)
  end
  
  def revert
    @artist = Artist.find(params[:id])
    @version = ArtistVersion.find(params[:version_id])
    @artist.revert_to!(@version)
    respond_with(@artist)
  end
  
  def show_or_new
    @artist = Artist.find_by_name(params[:name])
    if @artist
      redirect_to artist_path(@artist)
    else
      redirect_to new_artist_path(:name => params[:name])
    end
  end
end
