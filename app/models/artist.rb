class Artist < ActiveRecord::Base
  before_create :initialize_creator
  before_save :normalize_name
  after_save :create_version
  after_save :save_url_string
  validates_uniqueness_of :name
  belongs_to :creator, :class_name => "User"
  has_many :members, :class_name => "Artist", :foreign_key => "group_name", :primary_key => "name"
  has_many :urls, :dependent => :destroy, :class_name => "ArtistUrl"
  has_many :versions, :order => "artist_versions.id ASC", :class_name => "ArtistVersion"
  has_one :wiki_page, :foreign_key => "title", :primary_key => "name"
  has_one :tag_alias, :foreign_key => "antecedent_name", :primary_key => "name"
  accepts_nested_attributes_for :wiki_page
  attr_accessible :body, :name, :url_string, :other_names, :other_names_comma, :group_name, :wiki_page_attributes, :notes, :as => [:member, :gold, :builder, :platinum, :contributor, :janitor, :moderator, :default, :admin]
  attr_accessible :is_active, :as => [:builder, :contributor, :janitor, :moderator, :default, :admin]
  attr_accessible :is_banned, :as => :admin

  module UrlMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def find_all_by_url(url)
        url = ArtistUrl.normalize(url)
        artists = []

        while artists.empty? && url.size > 10
          u = url.sub(/\/+$/, "") + "/"
          u = u.to_escaped_for_sql_like.gsub(/\*/, '%') + '%'
          artists += Artist.joins(:urls).where(["artists.is_active = TRUE AND artist_urls.normalized_url LIKE ? ESCAPE E'\\\\'", u]).limit(10).order("artists.name").all
          url = File.dirname(url) + "/"
          break if url =~ /pixiv\.net\/(?:img\/)?$/
        end

        artists.uniq_by {|x| x.name}.slice(0, 20)
      end
    end

    def save_url_string
      if @url_string
        urls.clear

        @url_string.scan(/\S+/).each do |url|
          urls.create(:url => url)
        end
      end
    end

    def url_string=(string)
      @url_string = string
    end

    def url_string
      @url_string || urls.map {|x| x.url}.join("\n")
    end
  end

  module NameMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def normalize_name(name)
        name.to_s.mb_chars.downcase.strip.gsub(/ /, '_').to_s
      end
    end

    def normalize_name
      self.name = Artist.normalize_name(name)
    end

    def other_names_array
      other_names.try(:split, /\s/)
    end

    def other_names_comma
      other_names_array.try(:join, ", ")
    end

    def other_names_comma=(string)
      self.other_names = string.split(/,/).map {|x| Artist.normalize_name(x)}.join(" ")
    end

    def rename!(new_name)
      new_wiki_page = WikiPage.titled(new_name).first
      if new_wiki_page
        # Merge the old wiki page into the new one
        new_wiki_page.update_attributes(:body => new_wiki_page.body + "\n\n" + notes)
      elsif wiki_page
        wiki_page.update_attribute(:title, new_name)
      end
      reload
      update_attribute(:name, new_name)
    end
  end

  module GroupMethods
    def member_names
      members.map(&:name).join(", ")
    end
  end

  module VersionMethods
    def create_version
      ArtistVersion.create(
        :artist_id => id,
        :name => name,
        :updater_id => CurrentUser.user.id,
        :updater_ip_addr => CurrentUser.ip_addr,
        :url_string => url_string,
        :is_active => is_active,
        :is_banned => is_banned,
        :other_names => other_names,
        :group_name => group_name
      )
    end

    def revert_to!(version)
      self.name = version.name
      self.url_string = version.url_string
      self.is_active = version.is_active
      self.other_names = version.other_names
      self.group_name = version.group_name
      save
    end
  end

  module FactoryMethods
    def new_with_defaults(params)
      Artist.new.tap do |artist|
        if params[:name]
          artist.name = params[:name]
          if CurrentUser.user.is_gold?
            # below gold users are limited to two tags
            post = Post.tag_match("source:http #{artist.name} status:any").first
          else
            post = Post.tag_match("source:http #{artist.name}").first
          end
          unless post.nil? || post.source.blank?
            artist.url_string = post.source
          end
        end

        if params[:other_names]
          artist.other_names = params[:other_names]
        end

        if params[:urls]
          artist.url_string = params[:urls]
        end
      end
    end
  end

  module NoteMethods
    def notes
      if wiki_page
        wiki_page.body
      else
        nil
      end
    end

    def notes=(msg)
      if wiki_page
        wiki_page.body = msg
        wiki_page.save if wiki_page.body_changed? || wiki_page.title_changed?
      elsif msg.present?
        self.wiki_page = WikiPage.new(:title => name, :body => msg)
      end
    end
  end

  module TagMethods
    def has_tag_alias?
      TagAlias.exists?(["antecedent_name = ?", name])
    end

    def tag_alias_name
      TagAlias.find_by_antecedent_name(name).consequent_name
    end
  end

  module BanMethods
    def ban!
      Post.transaction do
        begin
          Post.tag_match(name).each do |post|
            begin
              post.flag!("Artist requested removal")
            rescue PostFlag::Error
              # swallow
            end
            post.delete!(:ban => true)
          end
        rescue Post::SearchError
          # swallow
        end

        # potential race condition but unlikely
        unless TagImplication.where(:antecedent_name => name, :consequent_name => "banned_artist").exists?
          tag_implication = TagImplication.create(:antecedent_name => name, :consequent_name => "banned_artist")
          tag_implication.delay(:queue => "default").process!
        end

        update_column(:is_banned, true)
      end
    end
  end

  module SearchMethods
    def active
      where("is_active = true")
    end

    def banned
      where("is_banned = true")
    end

    def url_matches(string)
      matches = find_all_by_url(string).map(&:id)

      if matches.any?
        where("id in (?)", matches)
      else
        where("false")
      end
    end

    def other_names_match(string)
      where("other_names_index @@ to_tsquery('danbooru', E?)", Artist.normalize_name(string).to_escaped_for_tsquery)
    end

    def group_name_matches(name)
      stripped_name = normalize_name(name).to_escaped_for_sql_like
      where("group_name LIKE ? ESCAPE E'\\\\'", stripped_name)
    end

    def name_matches(name)
      stripped_name = normalize_name(name).to_escaped_for_sql_like
      where("name LIKE ? ESCAPE E'\\\\'", stripped_name)
    end

    def any_name_matches(name)
      stripped_name = normalize_name(name).to_escaped_for_sql_like
      name_for_tsquery = normalize_name(name).to_escaped_for_tsquery
      where("(name LIKE ? ESCAPE E'\\\\' OR other_names_index @@ to_tsquery('danbooru', E?))", stripped_name, name_for_tsquery)
    end

    def search(params)
      q = scoped
      params = {} if params.blank?

      case params[:name]
      when /^http/
        q = q.url_matches(params[:name])

      when /name:(.+)/
        q = q.name_matches($1)

      when /other:(.+)/
        q = q.other_names_match($1)

      when /group:(.+)/
        q = q.group_name_matches($1)

      when /status:banned/
        q = q.banned

      when /status:active/
        q = q.where("is_banned = false and is_deleted = false")

      when /./
        q = q.any_name_matches(params[:name])
      end

      if params[:sort] == "name"
        q = q.reorder("name")
      else
        q = q.reorder("id desc")
      end

      if params[:is_active] == "true"
        q = q.active
      elsif params[:is_active] == "false"
        q = q.where("is_active = false")
      end

      if params[:is_banned] == "true"
        q = q.banned
      elsif params[:is_banned] == "false"
        q = q.where("is_banned = false")
      end

      if params[:id].present?
        q = q.where("id = ?", params[:id])
      end

      if params[:creator_name].present?
        q = q.where("creator_id = (select _.id from users _ where lower(_.name) = ?)", params[:creator_name].tr(" ", "_").mb_chars.downcase)
      end

      if params[:creator_id].present?
        q = q.where("creator_id = ?", params[:creator_id].to_i)
      end

      q
    end
  end

  include UrlMethods
  include NameMethods
  include GroupMethods
  include VersionMethods
  extend FactoryMethods
  include NoteMethods
  include TagMethods
  include BanMethods
  extend SearchMethods

  def status
    if is_banned? && is_active?
      "Banned"
    elsif is_banned?
      "Banned Deleted"
    elsif is_active?
      "Active"
    else
      "Deleted"
    end
  end

  def legacy_api_hash
    return {
      :id => id,
      :name => name,
      :other_names => other_names,
      :group_name => group_name,
      :urls => artist_urls.map {|x| x.url},
      :is_active => is_active?,
      :updater_id => 0
    }
  end

  def initialize_creator
    self.creator_id = CurrentUser.user.id
  end

  def deletable_by?(user)
    user.is_builder?
  end
end
