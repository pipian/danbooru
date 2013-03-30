require 'test_helper'

class ForumPostsControllerTest < ActionController::TestCase
  context "The forum posts controller" do
    setup do
      @user = FactoryGirl.create(:user)
      CurrentUser.user = @user
      CurrentUser.ip_addr = "127.0.0.1"
      @other_user = FactoryGirl.create(:user)
      @mod = FactoryGirl.create(:moderator_user)
      @forum_topic = FactoryGirl.create(:forum_topic, :title => "my forum topic", :creator => @user)
      @forum_post = FactoryGirl.create(:forum_post, :topic_id => @forum_topic.id, :body => "xxx")
    end

    teardown do
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    context "index action" do
      should "list all forum posts" do
        get :index
        assert_response :success
      end

      context "with search conditions" do
        should "list all matching forum posts" do
          get :index, {:search => {:body_matches => "xxx"}}
          assert_response :success
          assert_equal(1, assigns(:forum_posts).size)
        end

        should "list nothing for when the search matches nothing" do
          get :index, {:search => {:body_matches => "bababa"}}
          assert_response :success
          assert_equal(0, assigns(:forum_posts).size)
        end
      end
    end

    context "edit action" do
      should "render if the editor is the creator of the topic" do
        get :edit, {:id => @forum_post.id}, {:user_id => @user.id}
        assert_response :success
      end

      should "render if the editor is a moderator" do
        get :edit, {:id => @forum_post.id}, {:user_id => @mod.id}
        assert_response :success
      end

      should "fail if the editor is not the creator of the topic and is not a moderator" do
        assert_raises(User::PrivilegeError) do
          get :edit, {:id => @forum_post.id}, {:user_id => @other_user.id}
        end
      end
    end

    context "new action" do
      should "render" do
        get :new, {}, {:user_id => @user.id, :topic_id => @forum_topic.id}, {:user_id => @user.id}
        assert_response :success
      end
    end

    context "create action" do
      should "create a new forum post" do
        assert_difference("ForumPost.count", 1) do
          post :create, {:forum_post => {:body => "xaxaxa", :topic_id => @forum_topic.id}}, {:user_id => @user.id}
        end

        forum_post = ForumPost.last
        assert_redirected_to(forum_topic_path(@forum_topic, :page => 1))
      end
    end

    context "destroy action" do
      should "destroy the posts" do
        CurrentUser.user = @mod
        post :destroy, {:id => @forum_post.id}, {:user_id => @mod.id}
        assert_redirected_to(forum_post_path(@forum_post))
        @forum_post.reload
        assert_equal(true, @forum_post.is_deleted?)
      end
    end

    context "undelete action" do
      setup do
        @forum_post.update_attribute(:is_deleted, true)
      end

      should "restore the post" do
        post :undelete, {:id => @forum_post.id}, {:user_id => @user.id}
        assert_redirected_to(forum_post_path(@forum_post))
        @forum_post.reload
        assert_equal(false, @forum_post.is_deleted?)
      end
    end
  end
end
