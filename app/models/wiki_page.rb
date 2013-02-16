class WikiPage < ActiveRecord::Base
  before_save :normalize_title
  before_create :initialize_creator
  after_save :create_version
  belongs_to :creator, :class_name => "User"
  validates_uniqueness_of :title, :case_sensitive => false
  validates_presence_of :title
  validate :validate_locker_is_janitor
  attr_accessible :title, :body, :is_locked
  has_one :tag, :foreign_key => "name", :primary_key => "title"
  has_one :artist, :foreign_key => "name", :primary_key => "title"
  has_many :versions, :class_name => "WikiPageVersion", :dependent => :destroy, :order => "wiki_page_versions.id ASC"
  
  module SearchMethods
    def titled(title)
      where("title = ?", title.downcase.tr(" ", "_"))
    end
    
    def recent
      order("updated_at DESC").limit(25)
    end
    
    def body_matches(query)
      where("body_index @@ plainto_tsquery(?)", query.scan(/\S+/).join(" & "))
    end

    def search(params = {})
      q = scoped
      return q if params.blank?

      if params[:title]
        q = q.where("title LIKE ? ESCAPE E'\\\\'", params[:title].downcase.tr(" ", "_").to_escaped_for_sql_like)
      end

      if params[:creator_id]
        q = q.where("creator_id = ?", params[:creator_id])
      end
      
      if params[:body_matches]
        q = q.body_matches(params[:body_matches])
      end
      
      if params[:creator_name]
        q = q.where("creator_id = (select _.id from users _ where lower(_.name) = ?)", params[:creator_name].downcase)
      end
      
      if params[:sort] == "time"
        q = q.order("updated_at desc")
      end

      q
    end
  end
  
  extend SearchMethods
  
  def self.find_title_and_id(title)
    titled(title).select("title, id").first
  end
  
  def validate_locker_is_janitor
    if is_locked_changed? && !CurrentUser.is_janitor?
      errors.add(:is_locked, "can be modified by janitors only")
      return false
    end
  end
  
  def revert_to(version)
    self.title = version.title
    self.body = version.body
    self.is_locked = version.is_locked
  end
  
  def revert_to!(version)
    revert_to(version)
    save!
  end

  def normalize_title
    self.title = title.downcase.tr(" ", "_")
  end

  def creator_name
    User.id_to_name(user_id).tr("_", " ")
  end
  
  def category_name
    Tag.category_for(title)
  end

  def pretty_title
    title.tr("_", " ")
  end
  
  def create_version
    if title_changed? || body_changed? || is_locked_changed?
      versions.create(
        :updater_id => CurrentUser.user.id,
        :updater_ip_addr => CurrentUser.ip_addr,
        :title => title,
        :body => body,
        :is_locked => is_locked
      )
    end
  end
  
  def initialize_creator
    self.creator_id = CurrentUser.user.id
  end
  
  def post_set
    @post_set ||= PostSets::WikiPage.new(title, 1, 4)
  end
  
  def presenter
    @presenter ||= WikiPagePresenter.new(self)
  end
  
  def tags
    body.scan(/\[\[(.+?)\]\]/).flatten.map do |match|
      if match =~ /^(.+?)\|(.+)/
        $1
      else
        match
      end
    end.map {|x| x.downcase.tr(" ", "_")}
  end
end
