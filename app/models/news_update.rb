class NewsUpdate < ActiveRecord::Base
  belongs_to :creator, :class_name => "User"
  belongs_to :updater, :class_name => "User"
  scope :recent, order("created_at desc").limit(5)
  before_validation :initialize_creator, :on => :create
  before_validation :initialize_updater

  def initialize_creator
    self.creator_id = CurrentUser.id
  end

  def initialize_updater
    self.updater_id = CurrentUser.id
  end
end
