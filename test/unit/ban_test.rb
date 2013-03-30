require 'test_helper'

class BanTest < ActiveSupport::TestCase
  context "A ban" do
    context "created by an admin" do
      setup do
        @banner = FactoryGirl.create(:admin_user)
        CurrentUser.user = @banner
        CurrentUser.ip_addr = "127.0.0.1"
      end

      teardown do
        @banner = nil
        CurrentUser.user = nil
        CurrentUser.ip_addr = nil
      end

      should "not be valid against another admin" do
        user = FactoryGirl.create(:admin_user)
        ban = FactoryGirl.build(:ban, :user => user, :banner => @banner)
        ban.save
        assert(ban.errors.any?)
      end

      should "be valid against anyone who is not an admin" do
        user = FactoryGirl.create(:moderator_user)
        ban = FactoryGirl.create(:ban, :user => user, :banner => @banner)
        assert(ban.errors.empty?)

        user = FactoryGirl.create(:janitor_user)
        ban = FactoryGirl.create(:ban, :user => user, :banner => @banner)
        assert(ban.errors.empty?)

        user = FactoryGirl.create(:contributor_user)
        ban = FactoryGirl.create(:ban, :user => user, :banner => @banner)
        assert(ban.errors.empty?)

        user = FactoryGirl.create(:privileged_user)
        ban = FactoryGirl.create(:ban, :user => user, :banner => @banner)
        assert(ban.errors.empty?)

        user = FactoryGirl.create(:user)
        ban = FactoryGirl.create(:ban, :user => user, :banner => @banner)
        assert(ban.errors.empty?)
      end
    end

    context "created by a moderator" do
      setup do
        @banner = FactoryGirl.create(:moderator_user)
        CurrentUser.user = @banner
        CurrentUser.ip_addr = "127.0.0.1"
      end

      teardown do
        @banner = nil
        CurrentUser.user = nil
        CurrentUser.ip_addr = nil
      end

      should "not be valid against an admin or moderator" do
        user = FactoryGirl.create(:admin_user)
        ban = FactoryGirl.build(:ban, :user => user, :banner => @banner)
        ban.save
        assert(ban.errors.any?)

        user = FactoryGirl.create(:moderator_user)
        ban = FactoryGirl.build(:ban, :user => user, :banner => @banner)
        ban.save
        assert(ban.errors.any?)
      end

      should "be valid against anyone who is not an admin or a moderator" do
        user = FactoryGirl.create(:janitor_user)
        ban = FactoryGirl.create(:ban, :user => user, :banner => @banner)
        assert(ban.errors.empty?)

        user = FactoryGirl.create(:contributor_user)
        ban = FactoryGirl.create(:ban, :user => user, :banner => @banner)
        assert(ban.errors.empty?)

        user = FactoryGirl.create(:privileged_user)
        ban = FactoryGirl.create(:ban, :user => user, :banner => @banner)
        assert(ban.errors.empty?)

        user = FactoryGirl.create(:user)
        ban = FactoryGirl.create(:ban, :user => user, :banner => @banner)
        assert(ban.errors.empty?)
      end
    end

    context "created by a janitor" do
      setup do
        @banner = FactoryGirl.create(:janitor_user)
        CurrentUser.user = @banner
        CurrentUser.ip_addr = "127.0.0.1"
      end

      teardown do
        @banner = nil
        CurrentUser.user = nil
        CurrentUser.ip_addr = nil
      end

      should "always be invalid" do
        user = FactoryGirl.create(:admin_user)
        ban = FactoryGirl.build(:ban, :user => user, :banner => @banner)
        ban.save
        assert(ban.errors.any?)

        user = FactoryGirl.create(:moderator_user)
        ban = FactoryGirl.build(:ban, :user => user, :banner => @banner)
        ban.save
        assert(ban.errors.any?)

        user = FactoryGirl.create(:janitor_user)
        ban = FactoryGirl.build(:ban, :user => user, :banner => @banner)
        ban.save
        assert(ban.errors.any?)

        user = FactoryGirl.create(:contributor_user)
        ban = FactoryGirl.build(:ban, :user => user, :banner => @banner)
        ban.save
        assert(ban.errors.any?)

        user = FactoryGirl.create(:privileged_user)
        ban = FactoryGirl.build(:ban, :user => user, :banner => @banner)
        ban.save
        assert(ban.errors.any?)

        user = FactoryGirl.create(:user)
        ban = FactoryGirl.build(:ban, :user => user, :banner => @banner)
        ban.save
        assert(ban.errors.any?)
      end
    end

    should "initialize the expiration date" do
      user = FactoryGirl.create(:user)
      admin = FactoryGirl.create(:admin_user)
      CurrentUser.user = admin
      ban = FactoryGirl.create(:ban, :user => user, :banner => admin)
      CurrentUser.user = nil
      assert_not_nil(ban.expires_at)
    end

    should "update the user's feedback" do
      user = FactoryGirl.create(:user)
      admin = FactoryGirl.create(:admin_user)
      assert(user.feedback.empty?)
      CurrentUser.user = admin
      ban = FactoryGirl.create(:ban, :user => user, :banner => admin)
      CurrentUser.user = nil
      assert(!user.feedback.empty?)
      assert_equal("negative", user.feedback.last.category)
    end
  end

  context "Searching for a ban" do
    context "by user id" do
      setup do
        @admin = FactoryGirl.create(:admin_user)
        CurrentUser.user = @admin
        CurrentUser.ip_addr = "127.0.0.1"
        @user = FactoryGirl.create(:user)
      end

      teardown do
        CurrentUser.user = nil
        CurrentUser.ip_addr = nil
      end

      context "when only expired bans exist" do
        setup do
          @ban = FactoryGirl.create(:ban, :user => @user, :banner => @admin, :duration => -1)
        end

        should "not return expired bans" do
          assert(!Ban.is_banned?(@user))
        end
      end

      context "when active bans still exist" do
        setup do
          @ban = FactoryGirl.create(:ban, :user => @user, :banner => @admin, :duration => 1)
        end

        should "return active bans" do
          assert(Ban.is_banned?(@user))
        end
      end
    end
  end
end
