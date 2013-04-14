class PostQueryBuilder
  attr_accessor :query_string, :has_constraints

  def initialize(query_string)
    @query_string = query_string
    @has_constraint = false
  end

  def has_constraints?
    @has_constraints
  end

  def has_constraints!
    @has_constraints = true
  end

  def add_range_relation(arr, field, relation)
    return relation if arr.nil?

    has_constraints!

    case arr[0]
    when :eq
      if arr[1].is_a?(Time)
        relation.where("#{field} between ? and ?", arr[1].beginning_of_day, arr[1].end_of_day)
      else
        relation.where(["#{field} = ?", arr[1]])
      end

    when :gt
      relation.where(["#{field} > ?", arr[1]])

    when :gte
      relation.where(["#{field} >= ?", arr[1]])

    when :lt
      relation.where(["#{field} < ?", arr[1]])

    when :lte
      relation.where(["#{field} <= ?", arr[1]])

    when :in
      relation.where(["#{field} in (?)", arr[1]])

    when :between
      relation.where(["#{field} BETWEEN ? AND ?", arr[1], arr[2]])

    else
      relation
    end
  end

  def escape_string_for_tsquery(array)
    array.map do |token|
      token.to_escaped_for_tsquery
    end
  end

  def add_tag_string_search_relation(tags, relation)
    tag_query_sql = []

    if tags[:include].any?
      tag_query_sql << "(" + escape_string_for_tsquery(tags[:include]).join(" | ") + ")"
      has_constraints!
    end

    if tags[:related].any?
      tag_query_sql << "(" + escape_string_for_tsquery(tags[:related]).join(" & ") + ")"
      has_constraints!
    end

    if tags[:exclude].any?
      tag_query_sql << "!(" + escape_string_for_tsquery(tags[:exclude]).join(" | ") + ")"
    end

    if tag_query_sql.any?
      relation = relation.where("posts.tag_index @@ to_tsquery('danbooru', E?)", tag_query_sql.join(" & "))
    end

    relation
  end

  def add_tag_subscription_relation(subscriptions, relation)
    subscriptions.each do |subscription|
      if subscription =~ /^(.+?):(.+)$/
        user_name = $1
        subscription_name = $2
        user = User.find_by_name(user_name)
        return relation if user.nil?
        post_ids = TagSubscription.find_post_ids(user.id, subscription_name)
      else
        user = User.find_by_name(subscription)
        return relation if user.nil?
        post_ids = TagSubscription.find_post_ids(user.id)
      end

      post_ids = [0] if post_ids.empty?
      relation = relation.where(["posts.id IN (?)", post_ids])
    end

    relation
  end

  def build
    unless query_string.is_a?(Hash)
      q = Tag.parse_query(query_string)
    end

    relation = Post.scoped

    if q[:tag_count].to_i > Danbooru.config.tag_query_limit
      raise ::Post::SearchError.new("You cannot search for more than #{Danbooru.config.tag_query_limit} tags at a time")
    end

    relation = add_range_relation(q[:post_id], "posts.id", relation)
    relation = add_range_relation(q[:mpixels], "posts.image_width * posts.image_height / 1000000.0", relation)
    relation = add_range_relation(q[:width], "posts.image_width", relation)
    relation = add_range_relation(q[:height], "posts.image_height", relation)
    relation = add_range_relation(q[:score], "posts.score", relation)
    relation = add_range_relation(q[:fav_count], "posts.fav_count", relation)
    relation = add_range_relation(q[:filesize], "posts.file_size", relation)
    relation = add_range_relation(q[:date], "posts.created_at", relation)
    relation = add_range_relation(q[:general_tag_count], "posts.tag_count_general", relation)
    relation = add_range_relation(q[:artist_tag_count], "posts.tag_count_artist", relation)
    relation = add_range_relation(q[:copyright_tag_count], "posts.tag_count_copyright", relation)
    relation = add_range_relation(q[:character_tag_count], "posts.tag_count_character", relation)
    relation = add_range_relation(q[:post_tag_count], "posts.tag_count", relation)
    relation = add_range_relation(q[:pixiv_id], "posts.pixiv_id", relation) 

    if q[:md5]
      relation = relation.where(["posts.md5 IN (?)", q[:md5]])
      has_constraints!
    end

    if q[:status] == "pending"
      relation = relation.where("posts.is_pending = TRUE")
    elsif q[:status] == "flagged"
      relation = relation.where("posts.is_flagged = TRUE")
    elsif q[:status] == "deleted"
      relation = relation.where("posts.is_deleted = TRUE")
    elsif q[:status] == "banned"
      relation = relation.where("posts.is_banned = TRUE")
    elsif q[:status] == "all" || q[:status] == "any"
      # do nothing
    elsif q[:status_neg] == "pending" || q[:status] == "active"
      relation = relation.where("posts.is_pending = FALSE")
    elsif q[:status_neg] == "flagged"
      relation = relation.where("posts.is_flagged = FALSE")
    elsif q[:status_neg] == "deleted"
      relation = relation.where("posts.is_deleted = FALSE")
    elsif CurrentUser.user.hide_deleted_posts?
      relation = relation.where("posts.is_deleted = FALSE")
    end

    # The SourcePattern SQL function replaces Pixiv sources with "pixiv/[suffix]", where
    # [suffix] is everything past the second-to-last slash in the URL.  It leaves non-Pixiv
    # URLs unchanged.  This is to ease database load for Pixiv source searches.
    if q[:source]
      if q[:source] == "none%"
        relation = relation.where("(posts.source = '' OR posts.source IS NULL)")
      elsif q[:source] == "http%"
        relation = relation.where("(posts.source like ?)", "http%")
      elsif q[:source] =~ /^%\.?pixiv(?:\.net(?:\/img)?)?(?:%\/|(?=%$))(.+)$/
        relation = relation.where("SourcePattern(posts.source) LIKE ? ESCAPE E'\\\\'", "pixiv/" + $1)
        has_constraints!
      else
        relation = relation.where("SourcePattern(posts.source) LIKE SourcePattern(?) ESCAPE E'\\\\'", q[:source])
        has_constraints!
      end
    end

    if q[:subscriptions]
      relation = add_tag_subscription_relation(q[:subscriptions], relation)
      has_constraints!
    end

    if q[:uploader_id_neg]
      relation = relation.where("posts.uploader_id not in (?)", q[:uploader_id_neg])
    end

    if q[:uploader_id]
      relation = relation.where("posts.uploader_id = ?", q[:uploader_id])
      has_constraints!
    end

    if q[:approver_id_neg]
      relation = relation.where("posts.approver_id not in (?)", q[:approver_id_neg])
    end

    if q[:approver_id]
      relation = relation.where("posts.approver_id = ?", q[:approver_id])
      has_constraints!
    end

    if q[:commenter_id]
      relation = relation.where(:id => Comment.where("creator_id = ?", q[:commenter_id]).select("post_id").uniq)
      has_constraints!
    end

    if q[:noter_id]
      relation = relation.where(:id => Note.where("creator_id = ?", q[:noter_id]).select("post_id").uniq)
      has_constraints!
    end

    if q[:parent] == "none"
      relation = relation.where("posts.parent_id IS NULL")
    elsif q[:parent_neg] == "none" || q[:parent] == "any"
      relation = relation.where("posts.parent_id IS NOT NULL")
    elsif q[:parent]
      relation = relation.where("(posts.id = ? or posts.parent_id = ?)", q[:parent].to_i, q[:parent].to_i)
      has_constraints!
    end

    if q[:rating] =~ /^q/
      relation = relation.where("posts.rating = 'q'")
    elsif q[:rating] =~ /^s/
      relation = relation.where("posts.rating = 's'")
    elsif q[:rating] =~ /^e/
      relation = relation.where("posts.rating = 'e'")
    end

    if q[:rating_negated] =~ /^q/
      relation = relation.where("posts.rating <> 'q'")
    elsif q[:rating_negated] =~ /^s/
      relation = relation.where("posts.rating <> 's'")
    elsif q[:rating_negated] =~ /^e/
      relation = relation.where("posts.rating <> 'e'")
    end

    if q[:locked] == "rating"
      relation = relation.where("posts.is_rating_locked = TRUE")
    elsif q[:locked] == "note" || q[:locked] == "notes"
      relation = relation.where("posts.is_note_locked = TRUE")
    elsif q[:locked] == "status"
      relation = relation.where("posts.is_status_locked = TRUE")
    end

    if q[:locked_negated] == "rating"
      relation = relation.where("posts.is_rating_locked = FALSE")
    elsif q[:locked_negated] == "note" || q[:locked_negated] == "notes"
      relation = relation.where("posts.is_note_locked = FALSE")
    elsif q[:locked_negated] == "status"
      relation = relation.where("posts.is_status_locked = FALSE")
    end

    relation = add_tag_string_search_relation(q[:tags], relation)

    if q[:order] == "rank"
      relation = relation.where("posts.score > 0 and posts.created_at >= ?", 2.days.ago)
    end

    case q[:order]
    when "id", "id_asc"
      relation = relation.order("posts.id ASC")

    when "id_desc"
      relation = relation.order("posts.id DESC")

    when "score", "score_desc"
      relation = relation.order("posts.score DESC, posts.id DESC")

    when "score_asc"
      relation = relation.order("posts.score ASC, posts.id DESC")

    when "favcount"
      relation = relation.order("posts.fav_count DESC, posts.id DESC")

    when "favcount_asc"
      relation = relation.order("posts.fav_count ASC, posts.id DESC")

    when "comment", "comm"
      relation = relation.order("posts.last_commented_at DESC, posts.id DESC").where("posts.last_commented_at is not null")

    when "comment_asc", "comm_asc"
      relation = relation.order("posts.last_commented_at ASC, posts.id DESC").where("posts.last_commented_at is not null")

    when "note"
      relation = relation.order("posts.last_noted_at DESC, posts.id DESC").where("posts.last_noted_at is not null")

    when "note_asc"
      relation = relation.order("posts.last_noted_at ASC, posts.id DESC").where("posts.last_noted_at is not null")

    when "mpixels", "mpixels_desc"
      # Use "w*h/1000000", even though "w*h" would give the same result, so this can use
      # the posts_mpixels index.
      relation = relation.order("posts.image_width * posts.image_height / 1000000.0 DESC, posts.id DESC")

    when "mpixels_asc"
      relation = relation.order("posts.image_width * posts.image_height / 1000000.0 ASC, posts.id DESC")

    when "portrait"
      relation = relation.order("1.0 * posts.image_width / GREATEST(1, posts.image_height) ASC, posts.id DESC")

    when "landscape"
      relation = relation.order("1.0 * posts.image_width / GREATEST(1, posts.image_height) DESC, posts.id DESC")

    when "filesize", "filesize_desc"
      relation = relation.order("posts.file_size DESC")

    when "filesize_asc"
      relation = relation.order("posts.file_size ASC")

    when "rank"
      relation = relation.order("log(3, posts.score) + (extract(epoch from posts.created_at) - extract(epoch from timestamp '2005-05-24')) / 45000 DESC")

    else
      relation = relation.order("posts.id DESC")
    end

    relation
  end
end
