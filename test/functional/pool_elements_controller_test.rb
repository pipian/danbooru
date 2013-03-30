require 'test_helper'

class PoolElementsControllerTest < ActionController::TestCase
  context "The pools posts controller" do
    setup do
      @user = FactoryGirl.create(:user)
      @mod = FactoryGirl.create(:moderator_user)
      CurrentUser.user = @user
      CurrentUser.ip_addr = "127.0.0.1"
      @post = FactoryGirl.create(:post)
      @pool = FactoryGirl.create(:pool, :name => "abc")
    end

    teardown do
      CurrentUser.user = nil
    end

    context "create action" do
      should "add a post to a pool" do
        post :create, {:pool_id => @pool.id, :post_id => @post.id, :format => "json"}, {:user_id => @user.id}
        @pool.reload
        assert_equal([@post.id], @pool.post_id_array)
      end

      should "add a post to a pool once and only once" do
        @pool.add!(@post)
        post :create, {:pool_id => @pool.id, :post_id => @post.id, :format => "json"}, {:user_id => @user.id}
        @pool.reload
        assert_equal([@post.id], @pool.post_id_array)
      end
    end

    context "destroy action" do
      setup do
        @pool.add!(@post)
      end

      should "remove a post from a pool" do
        post :destroy, {:pool_id => @pool.id, :post_id => @post.id, :format => "json"}, {:user_id => @user.id}
        @pool.reload
        assert_equal([], @pool.post_id_array)
      end

      should "do nothing if the post is not a member of the pool" do
        @pool.remove!(@post)
        post :destroy, {:pool_id => @pool.id, :post_id => @post.id, :format => "json"}, {:user_id => @user.id}
        @pool.reload
        assert_equal([], @pool.post_id_array)
      end
    end
  end
end
