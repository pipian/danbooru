class WikiPagesController < ApplicationController
  respond_to :html, :xml, :json, :js
  before_filter :member_only, :except => [:index, :show, :show_or_new]
  before_filter :janitor_only, :only => [:destroy]
  before_filter :normalize_search_params, :only => [:index]
  rescue_from ActiveRecord::StatementInvalid, :with => :rescue_exception

  def new
    @wiki_page = WikiPage.new(params[:wiki_page])
    respond_with(@wiki_page)
  end

  def edit
    @wiki_page = WikiPage.find(params[:id])
    respond_with(@wiki_page)
  end

  def index
    @wiki_pages = WikiPage.search(params[:search]).order("updated_at desc").paginate(params[:page], :search_count => params[:search])
    respond_with(@wiki_pages) do |format|
      format.html do
        if @wiki_pages.count == 1 && (params[:page].nil? || params[:page].to_i == 1)
          redirect_to(wiki_page_path(@wiki_pages.first))
        end
      end
      format.xml do
        render :xml => @wiki_pages.to_xml(:root => "wiki-pages")
      end
    end
  end

  def show
    if params[:id] =~ /[a-zA-Z]/
      @wiki_page = WikiPage.find_by_title(params[:id])
    else
      @wiki_page = WikiPage.find_by_id(params[:id])
    end
    
    respond_with(@wiki_page)
  end

  def create
    @wiki_page = WikiPage.create(params[:wiki_page])
    respond_with(@wiki_page)
  end

  def update
    @wiki_page = WikiPage.find(params[:id])
    @wiki_page.update_attributes(params[:wiki_page])
    respond_with(@wiki_page)
  end

  def destroy
    @wiki_page = WikiPage.find(params[:id])
    @wiki_page.destroy
    respond_with(@wiki_page)
  end

  def revert
    @wiki_page = WikiPage.find(params[:id])
    @version = WikiPageVersion.find(params[:version_id])
    @wiki_page.revert_to!(@version)
    flash[:notice] = "Page was reverted"
    respond_with(@wiki_page)
  end

  def show_or_new
    @wiki_page = WikiPage.find_by_title(params[:title])
    if @wiki_page
      redirect_to wiki_page_path(@wiki_page)
    else
      redirect_to new_wiki_page_path(:wiki_page => {:title => params[:title]})
    end
  end

private
  def normalize_search_params
    if params[:title]
      params[:search] ||= {}
      params[:search][:title] = params.delete(:title)
    end
  end
end
