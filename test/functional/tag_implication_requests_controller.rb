require 'test_helper'

class TagImplicationRequestsControllerTest < ActionController::TestCase
  context "The tag implication request controller" do
    setup do
      @user = FactoryGirl.create(:user)
      CurrentUser.user = @user
      CurrentUser.ip_addr = "127.0.0.1"
      MEMCACHE.flush_all
      Delayed::Worker.delay_jobs = false
    end

    teardown do
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    context "new action" do
      should "render" do
        get :new, {}, {:user => @user.id}
        assert_response :success
      end
    end

    context "create action" do
      should "render" do
        assert_difference("ForumTopic.count", 1) do
          post :create, {:tag_implication_request => {:antecedent_name => "aaa", :consequent_name => "bbb", :reason => "ccc"}}, {:user => @user.id}
        end
        assert_redirected_to(forum_topic_path(ForumTopic.last))
      end
    end
  end
end
