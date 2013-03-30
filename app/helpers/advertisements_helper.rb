require 'net/http'
require 'net/https'

module AdvertisementsHelper
  def render_advertisement(ad_type)
    if ad_type == 'horizontal'
      http = Net::HTTP.new('www.roundstable.com', 443)
      http.use_ssl = true
      request = Net::HTTP::Get.new('/buysomeapples/buysomeapples.php')
      raw(http.request(request).body)
    else

		if Danbooru.config.can_see_ads?(CurrentUser.user)
	    @advertisement = Advertisement.find(:first, :conditions => ["ad_type = ? AND status = 'active'", ad_type], :order => "random()")
	    if @advertisement
  	    content_tag(
  	      "div",
  	      link_to(
  	        image_tag(
  	          @advertisement.image_url,
  	          :alt => "Advertisement",
  	          :width => @advertisement.width,
  	          :height => @advertisement.height
  	        ),
  	        advertisement_hits_path(:advertisement_id => @advertisement.id),
  	        :method => :post
  	      ),
          :style => "margin-bottom: 1em;"
  	    )
	    end
		else
			""
		end
    end
  end

  def render_rss_advertisement(short_or_long, safe)
    if Danbooru.config.can_see_ads?(CurrentUser.user)
      if safe
        render "advertisements/jlist_rss_ads_explicit_#{short_or_long}"
      else
        render "advertisements/jlist_rss_ads_safe_#{short_or_long}"
      end
    end
  end
end
