class TagImplication < ActiveRecord::Base
  before_save :update_descendant_names
  after_save :update_descendant_names_for_parent
  belongs_to :creator, :class_name => "User"
  before_validation :initialize_creator, :on => :create
  before_validation :normalize_names
  validates_presence_of :creator_id, :antecedent_name, :consequent_name
  validates_uniqueness_of :antecedent_name, :scope => :consequent_name
  validate :absence_of_circular_relation

  module DescendantMethods
    extend ActiveSupport::Concern

    module ClassMethods
      # assumes names are normalized
      def with_descendants(names)
        (names + where("antecedent_name in (?) and status = ?", names, "active").map(&:descendant_names_array)).flatten.uniq
      end
    end

    def descendants
      @descendants ||= begin
        [].tap do |all|
          children = [consequent_name]

          until children.empty?
            all.concat(children)
            children = self.class.where(["antecedent_name IN (?)", children]).all.map(&:consequent_name)
          end
        end.sort.uniq
      end
    end

    def descendant_names_array
      descendant_names.split(/ /)
    end

    def update_descendant_names
      self.descendant_names = descendants.join(" ")
    end

    def update_descendant_names!
      update_descendant_names
      update_column(:descendant_names, descendant_names)
    end

    def update_descendant_names_for_parent
      p = parent

      while p
        p.update_descendant_names!
        p = p.parent
      end
    end

    def clear_descendants_cache
      @descendants = nil
    end
  end

  module ParentMethods
    def parent
      @parent ||= self.class.where(["consequent_name = ?", antecedent_name]).first
    end

    def clear_parent_cache
      @parent = nil
    end
  end

  module SearchMethods
    def name_matches(name)
      where("(antecedent_name like ? escape E'\\\\' or consequent_name like ? escape E'\\\\')", name.downcase.to_escaped_for_sql_like, name.downcase.to_escaped_for_sql_like)
    end

    def search(params)
      q = scoped
      return q if params.blank?

      if params[:id].present?
        q = q.where("id = ?", params[:id].to_i)
      end

      if params[:name_matches].present?
        q = q.name_matches(params[:name_matches])
      end

      if params[:antecedent_name].present?
        q = q.where("antecedent_name = ?", params[:antecedent_name])
      end

      q
    end
  end

  include DescendantMethods
  include ParentMethods
  extend SearchMethods

  def initialize_creator
    self.creator_id = CurrentUser.user.id
    self.creator_ip_addr = CurrentUser.ip_addr
  end

  def process!
    update_column(:status, "processing")
    update_descendant_names_for_parent
    update_posts
    update_column(:status, "active")
  rescue Exception => e
    update_column(:status, "error: #{e}")
  end

  def absence_of_circular_relation
    # We don't want a -> b && b -> a chains
    if self.class.exists?(["antecedent_name = ? and consequent_name = ?", consequent_name, antecedent_name])
      self.errors[:base] << "Tag implication can not create a circular relation with another tag implication"
      false
    end
  end

  def update_posts
    Post.tag_match("#{antecedent_name} status:any").find_each do |post|
      escaped_antecedent_name = Regexp.escape(antecedent_name)
      fixed_tags = post.tag_string.sub(/(?:\A| )#{escaped_antecedent_name}(?:\Z| )/, " #{antecedent_name} #{descendant_names} ").strip
      CurrentUser.scoped(creator, creator_ip_addr) do
        post.update_attributes(
          :tag_string => fixed_tags
        )
      end
    end
  end
  
  def normalize_names
    self.antecedent_name = antecedent_name.downcase.tr(" ", "_")
    self.consequent_name = consequent_name.downcase.tr(" ", "_")
  end

  def is_pending?
    status == "pending"
  end

  def is_active?
    status == "active"
  end

  def antecedent_tag
    Tag.find_by_name(antecedent_name)
  end

  def consequent_tag
    Tag.find_by_name(consequent_name)
  end

  def reload(options = {})
    super
    clear_parent_cache
    clear_descendants_cache
  end
end
