module PoolVersionsHelper
  def pool_version_diff(current)
    prev = PoolVersion.where(["pool_id = ? and updated_at < ?", current.pool_id, current.updated_at]).order("updated_at desc").first

    if prev.nil?
      return current.post_id_array.map {|x| '<ins><a href="/posts/' + x.to_s + '">' + x.to_s + '</a></ins>'}.join(" ").html_safe
    end

    added = current.post_id_array - prev.post_id_array
    removed = prev.post_id_array - current.post_id_array

    (added.map {|x| '<ins><a href="/posts/' + x.to_s + '">' + x.to_s + '</a></ins>'}.join(" ") + removed.map {|x| '<del><a href="/posts/' + x.to_s + '">' + x.to_s + '</a></del>'}.join(" ")).html_safe
  end
end
