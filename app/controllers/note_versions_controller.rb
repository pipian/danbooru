class NoteVersionsController < ApplicationController
  respond_to :html, :xml, :json
  before_filter :member_only, :except => [:index, :show]

  def index
    @note_versions = NoteVersion.search(params[:search]).order("note_versions.id desc").paginate(params[:page], :limit => params[:limit])
    respond_with(@note_versions) do |format|
      format.xml do
        render :xml => @note_versions.to_xml(:root => "note-versions")
      end
    end
  end
end
