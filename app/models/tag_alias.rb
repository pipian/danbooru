class TagAlias < ActiveRecord::Base
  before_save :ensure_tags_exist
  after_save :clear_all_cache
  after_destroy :clear_all_cache
  before_validation :initialize_creator, :on => :create
  before_validation :normalize_names
  validates_presence_of :creator_id, :antecedent_name, :consequent_name
  validates_uniqueness_of :antecedent_name
  validate :absence_of_transitive_relation
  belongs_to :creator, :class_name => "User"
  belongs_to :forum_topic

  module SearchMethods
    def name_matches(name)
      where("(antecedent_name like ? escape E'\\\\' or consequent_name like ? escape E'\\\\')", name.mb_chars.downcase.to_escaped_for_sql_like, name.downcase.to_escaped_for_sql_like)
    end
    
    def active
      where("status = ?", "active")
    end

    def search(params)
      q = scoped
      return q if params.blank?

      if params[:name_matches].present?
        q = q.name_matches(params[:name_matches])
      end

      if params[:antecedent_name].present?
        q = q.where("antecedent_name = ?", params[:antecedent_name])
      end

      if params[:id].present?
        q = q.where("id = ?", params[:id].to_i)
      end

      q
    end
  end

  module CacheMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def clear_cache_for(name)
        Cache.delete("ta:#{Cache.sanitize(name)}")
      end
    end

    def clear_all_cache
      Danbooru.config.all_server_hosts.each do |host|
        TagAlias.delay(:queue => host).clear_cache_for(antecedent_name)
        TagAlias.delay(:queue => host).clear_cache_for(consequent_name)
      end
    end
  end

  extend SearchMethods
  include CacheMethods

  def self.to_aliased(names)
    Array(names).flatten.map do |name|
      Cache.get("ta:#{Cache.sanitize(name)}") do
        ActiveRecord::Base.select_value_sql("select consequent_name from tag_aliases where status = 'active' and antecedent_name = ?", name) || name
      end
    end.uniq
  end

  def process!
    update_column(:status, "processing")
    clear_all_cache
    ensure_category_consistency
    update_posts
    update_column(:status, "active")
  rescue Exception => e
    update_column(:status, "error: #{e}")
  end

  def is_pending?
    status == "pending"
  end

  def is_active?
    status == "active"
  end
  
  def normalize_names
    self.antecedent_name = antecedent_name.mb_chars.downcase.tr(" ", "_")
    self.consequent_name = consequent_name.downcase.tr(" ", "_")
  end

  def initialize_creator
    self.creator_id = CurrentUser.user.id
    self.creator_ip_addr = CurrentUser.ip_addr
  end

  def antecedent_tag
    Tag.find_by_name(antecedent_name)
  end

  def consequent_tag
    Tag.find_by_name(consequent_name)
  end

  def absence_of_transitive_relation
    # We don't want a -> b && b -> c chains
    if self.class.exists?(["antecedent_name = ?", consequent_name]) || self.class.exists?(["consequent_name = ?", antecedent_name])
      self.errors[:base] << "Tag alias can not create a transitive relation with another tag alias"
      false
    end
  end

  def ensure_tags_exist
    Tag.find_or_create_by_name(antecedent_name)
    Tag.find_or_create_by_name(consequent_name)
  end

  def ensure_category_consistency
    if antecedent_tag.category != consequent_tag.category && antecedent_tag.category != Tag.categories.general
      consequent_tag.update_attribute(:category, antecedent_tag.category)
      consequent_tag.update_category_cache_for_all
    end

    true
  end

  def update_posts
    Post.raw_tag_match(antecedent_name).find_each do |post|
      escaped_antecedent_name = Regexp.escape(antecedent_name)
      fixed_tags = post.tag_string.sub(/(?:\A| )#{escaped_antecedent_name}(?:\Z| )/, " #{consequent_name} ").strip
      CurrentUser.scoped(creator, creator_ip_addr) do
        post.update_attributes(
          :tag_string => fixed_tags
        )
      end
    end

    antecedent_tag.fix_post_count if antecedent_tag
    consequent_tag.fix_post_count if consequent_tag
  end

  def rename_wiki_and_artist
    antecedent_wiki = WikiPage.titled(antecedent_name).first
    if antecedent_wiki.present? && WikiPage.titled(consequent_name).blank?
      CurrentUser.scoped(creator, creator_ip_addr) do
        antecedent_wiki.update_attributes(
          :title => consequent_name
        )
      end
    end

    if antecedent_tag.category == Tag.categories.artist
      antecedent_artist = Artist.name_matches(antecedent_name).first
      if antecedent_artist.present? && Artist.name_matches(consequent_name).blank?
        CurrentUser.scoped(creator, creator_ip_addr) do
          antecedent_artist.update_attributes(
            :name => consequent_name
          )
        end
      end
    end
  end
end
