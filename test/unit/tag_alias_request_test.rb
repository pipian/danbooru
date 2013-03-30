require 'test_helper'

class TagAliasRequestTest < ActiveSupport::TestCase
  context "A tag alias request" do
    setup do
      @user = FactoryGirl.create(:user)
      CurrentUser.user = @user
      CurrentUser.ip_addr = "127.0.0.1"
      MEMCACHE.flush_all
      Delayed::Worker.delay_jobs = false
    end

    teardown do
      MEMCACHE.flush_all
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    should "raise an exception if invalid" do
      assert_raises(TagAliasRequest::ValidationError) do
        TagAliasRequest.new("", "", "reason").create
      end
    end

    should "create a tag alias" do
      assert_difference("TagAlias.count", 1) do
        TagAliasRequest.new("aaa", "bbb", "reason").create
      end
      assert_equal("pending", TagAlias.last.status)
    end

    should "create a forum topic" do
      assert_difference("ForumTopic.count", 1) do
        TagAliasRequest.new("aaa", "bbb", "reason").create
      end
    end

    should "create a forum post" do
      assert_difference("ForumPost.count", 1) do
        TagAliasRequest.new("aaa", "bbb", "reason").create
      end
    end
  end
end
