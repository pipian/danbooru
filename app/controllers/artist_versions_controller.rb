class ArtistVersionsController < ApplicationController
  respond_to :html, :xml, :json

  def index
    @artist_versions = ArtistVersion.search(params[:search]).order("id desc").paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
    respond_with(@artist_versions) do |format|
      format.xml do
        render :xml => @artist_versions.to_xml(:root => "artist-versions")
      end
    end
  end
end
