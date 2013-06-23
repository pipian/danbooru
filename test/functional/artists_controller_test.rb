require 'test_helper'

class ArtistsControllerTest < ActionController::TestCase
  context "An artists controller" do
    setup do
      CurrentUser.user = FactoryGirl.create(:user)
      CurrentUser.ip_addr = "127.0.0.1"
      @artist = FactoryGirl.create(:artist)
      @user = FactoryGirl.create(:user)
    end

    teardown do
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    should "get the new page" do
      get :new, {}, {:user_id => @user.id}
      assert_response :success
    end

    should "get the edit page" do
      get :edit, {:id => @artist.id}, {:user_id => @user.id}
      assert_response :success
    end

    should "get the show page" do
      get :show, {:id => @artist.id}
      assert_response :success
    end

    should "get the show page for a negated tag" do
      @artist.update_attribute(:name, "-aaa")
      get :show, {:id => @artist.id}
      assert_response :success
    end

    should "get the index page" do
      get :index
      assert_response :success
    end

    should "create an artist" do
      assert_difference("Artist.count", 1) do
        attributes = FactoryGirl.attributes_for(:artist)
        attributes.delete(:is_active)
        post :create, {:artist => attributes}, {:user_id => @user.id}
      end
      artist = Artist.last
      assert_redirected_to(artist_path(artist))
    end

    should "update an artist" do
      post :update, {:id => @artist.id, :artist => {:name => "xxx"}}, {:user_id => @user.id}
      @artist.reload
      assert_equal("xxx", @artist.name)
      assert_redirected_to(artist_path(@artist))
    end

    should "revert an artist" do
      @artist.update_attributes(:name => "xyz")
      @artist.update_attributes(:name => "abc")
      version = @artist.versions.first
      post :revert, {:id => @artist.id, :version_id => version.id}
    end
  end
end
