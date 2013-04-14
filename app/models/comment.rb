class Comment < ActiveRecord::Base
  validate :validate_creator_is_not_limited, :on => :create
  validates_format_of :body, :with => /\S/, :message => 'has no content'
  belongs_to :post
  belongs_to :creator, :class_name => "User"
  belongs_to :updater, :class_name => "User"
  has_many :votes, :class_name => "CommentVote", :dependent => :destroy
  before_validation :initialize_creator, :on => :create
  before_validation :initialize_updater
  after_create :update_last_commented_at_on_create
  after_destroy :update_last_commented_at_on_destroy
  attr_accessible :body, :post_id, :do_not_bump_post
  attr_accessor :do_not_bump_post

  module SearchMethods
    def recent
      reorder("comments.id desc").limit(6)
    end

    def body_matches(query)
      where("body_index @@ plainto_tsquery(?)", query.to_escaped_for_tsquery_split).order("comments.id DESC")
    end

    def hidden(user)
      where("score < ?", user.comment_threshold)
    end

    def visible(user)
      where("score >= ?", user.comment_threshold)
    end

    def post_tags_match(query)
      joins(:post).where("posts.tag_index @@ to_tsquery('danbooru', ?)", query.to_escaped_for_tsquery_split)
    end

    def for_creator(user_id)
      where("creator_id = ?", user_id)
    end

    def for_creator_name(user_name)
      where("creator_id = (select _.id from users _ where lower(_.name) = lower(?))", user_name.mb_chars.downcase)
    end

    def search(params)
      q = scoped
      return q if params.blank?

      if params[:body_matches].present?
        q = q.body_matches(params[:body_matches])
      end

      if params[:post_id].present?
        q = q.where("post_id = ?", params[:post_id].to_i)
      end

      if params[:post_tags_match].present?
        q = q.post_tags_match(params[:post_tags_match])
      end

      if params[:creator_name].present?
        q = q.for_creator_name(params[:creator_name].tr(" ", "_"))
      end

      if params[:creator_id].present?
        q = q.for_creator(params[:creator_id].to_i)
      end

      q
    end
  end

  extend SearchMethods

  def initialize_creator
    self.creator_id = CurrentUser.user.id
    self.ip_addr = CurrentUser.ip_addr
  end

  def initialize_updater
    self.updater_id = CurrentUser.user.id
    self.updater_ip_addr = CurrentUser.ip_addr
  end

  def creator_name
    User.id_to_name(creator_id)
  end

  def updater_name
    User.id_to_name(updater_id)
  end

  def validate_creator_is_not_limited
    if creator.is_comment_limited? && !do_not_bump_post?
      errors.add(:base, "You can only post #{Danbooru.config.member_comment_limit} comments per hour")
      false
    elsif creator.can_comment?
      true
    else
      errors.add(:base, "You can not post comments within 1 week of sign up")
      false
    end
  end

  def update_last_commented_at_on_create
    if Comment.where("post_id = ?", post_id).count <= Danbooru.config.comment_threshold && !do_not_bump_post?
      Post.update_all(["last_commented_at = ?", created_at], ["id = ?", post_id])
    end
    true
  end

  def update_last_commented_at_on_destroy
    other_comments = Comment.where("post_id = ? and id <> ?", post_id, id).order("id DESC")
    if other_comments.count == 0
      Post.update_all("last_commented_at = NULL", ["id = ?", post_id])
    else
      Post.update_all(["last_commented_at = ?", other_comments.first.created_at], ["id = ?", post_id])
    end
    true
  end

  def do_not_bump_post?
    do_not_bump_post == "1"
  end

  def vote!(val)
    numerical_score = val == "up" ? 1 : -1
    vote = votes.create(:score => numerical_score)

    if vote.errors.empty?
      if vote.is_positive?
        update_column(:score, score + 1)
      elsif vote.is_negative?
        update_column(:score, score - 1)
      end
    end

    return vote
  end

  def editable_by?(user)
    creator_id == user.id || user.is_janitor?
  end
end

Comment.connection.extend(PostgresExtensions)
