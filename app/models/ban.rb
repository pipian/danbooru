class Ban < ActiveRecord::Base
  after_create :update_feedback
  belongs_to :user
  belongs_to :banner, :class_name => "User"
  attr_accessible :reason, :duration, :user_id, :user_name
  validate :user_is_inferior
  validates_presence_of :user_id, :reason, :duration
  before_validation :initialize_banner_id, :on => :create
    
  def self.is_banned?(user)
    exists?(["user_id = ? AND expires_at > ?", user.id, Time.now])
  end
  
  def self.search(params)
    q = scoped
    return q if params.blank?
    
    if params[:banner_name]
      q = q.where("banner_id = (select _.id from users _ where lower(_.name) = ?)", params[:banner_name].downcase)
    end
    
    if params[:banner_id]
      q = q.where("banner_id = ?", params[:banner_id].to_i)
    end
    
    if params[:user_name]
      q = q.where("user_id = (select _.id from users _ where lower(_.name) = ?)", params[:user_name].downcase)
    end
    
    if params[:user_id]
      q = q.where("user_id = ?", params[:user_id].to_i)
    end
    
    q
  end
  
  def initialize_banner_id
    self.banner_id = CurrentUser.id
  end
  
  def user_is_inferior
    if user
      if user.is_admin?
        errors[:base] << "You can never ban an admin."      
        false
      elsif user.is_moderator? && banner.is_admin?
        true
      elsif user.is_moderator?
        errors[:base] << "Only admins can ban moderators."
        false
      elsif banner.is_admin? || banner.is_moderator?
        true
      else
        errors[:base] << "No one else can ban."
        false
      end
    end
  end
  
  def update_feedback
    if user
      feedback = user.feedback.build
      feedback.category = "negative"
      feedback.body = "Banned: #{reason}"
      feedback.creator_id = banner_id
      feedback.save
    end
  end
  
  def user_name
    user ? user.name : nil
  end
  
  def user_name=(username)
    self.user_id = User.name_to_id(username)
  end
  
  def duration=(dur)
    self.expires_at = dur.to_i.days.from_now
    @duration = dur
  end
  
  def duration
    @duration
  end
  
  def expired?
    expires_at < Time.now
  end
end
