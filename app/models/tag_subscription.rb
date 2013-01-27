class TagSubscription < ActiveRecord::Base
  belongs_to :creator, :class_name => "User"
  before_validation :initialize_creator, :on => :create
  before_validation :initialize_post_ids, :on => :create
  before_save :normalize_name
  before_save :limit_tag_count
  attr_accessible :name, :tag_query, :post_ids, :is_visible_on_profile
  validates_presence_of :name, :tag_query, :is_public, :creator_id
  
  def normalize_name
    self.name = name.gsub(/\W/, "_")
  end
  
  def initialize_creator
    self.creator_id = CurrentUser.id
  end

  def initialize_post_ids
    process
  end

  def tag_query_array
    Tag.scan_query(tag_query)
  end

  def limit_tag_count
    self.tag_query = tag_query_array.slice(0, 20).join(" ")
  end

  def process
    post_ids = tag_query_array.inject([]) do |all, tag|
      all += Post.tag_match(tag).limit(Danbooru.config.tag_subscription_post_limit / 3).select("posts.id").order("posts.id desc").map(&:id)
    end
    self.post_ids = post_ids.sort.reverse.slice(0, Danbooru.config.tag_subscription_post_limit).join(",")
  end
  
  def is_active?
    creator.last_logged_in_at && creator.last_logged_in_at > 1.year.ago
  end
  
  def editable_by?(user)
    user.is_moderator? || creator_id == user.id
  end
  
  def self.search(params)
    q = scoped
    return q if params.blank?
    
    if params[:creator_id]
      q = q.where("creator_id = ?", params[:creator_id].to_i)
    end
    
    if params[:creator_name]
      q = q.where("creator_id = (select _.id from users _ where lower(_.name) = ?)", params[:creator_name].downcase)
    end
    
    q
  end
  
  def self.visible_to(user)
    where("(is_public = TRUE OR creator_id = ? OR ?)", user.id, user.is_moderator?)
  end

  def self.find_tags(subscription_name)
    if subscription_name =~ /^(.+?):(.+)$/
      user_name = $1
      sub_group = $2
    else
      user_name = subscription_name
      sub_group = nil
    end

    user = User.find_by_name(user_name)
    
    if user
      relation = where(["creator_id = ?", user.id])
      
      if sub_group
        relation = relation.where(["name ILIKE ? ESCAPE E'\\\\'", sub_group.to_escaped_for_sql_like])
      end

      relation.map {|x| x.tag_query.split(/ /)}.flatten
    else
      []
    end        
  end

  def self.find_post_ids(user_id, name = nil, limit = Danbooru.config.tag_subscription_post_limit)
    relation = where(["creator_id = ?", user_id])
    
    if name
      relation = relation.where(["name ILIKE ? ESCAPE E'\\\\'", name.to_escaped_for_sql_like])
    end
    
    relation.each do |tag_sub|
      tag_sub.update_column(:last_accessed_at, Time.now)
    end

    relation.map {|x| x.post_ids.split(/,/)}.flatten.uniq.map(&:to_i).sort.reverse.slice(0, limit)
  end

  def self.find_posts(user_id, name = nil, limit = Danbooru.config.tag_subscription_post_limit)
    Post.where(["id in (?)", find_post_ids(user_id, name, limit)]).order("id DESC").limit(limit)
  end

  def self.process_all
    find_each do |tag_subscription|
      if $job_task_daemon_active != false && tag_subscription.creator.is_privileged? && tag_subscription.is_active?
        begin
          tag_subscription.process
          tag_subscription.save
        rescue Exception => x
          raise if Rails.environment != "production"
        end
      end
    end
  end
end
