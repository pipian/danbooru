require 'test_helper'

class UserTest < ActiveSupport::TestCase
  context "A user" do
    setup do
      @user = FactoryGirl.create(:user)
      CurrentUser.user = @user
      CurrentUser.ip_addr = "127.0.0.1"
      MEMCACHE.flush_all
    end

    teardown do
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    context "that has been invited by a mod" do
      setup do
        @mod = FactoryGirl.create(:moderator_user)
      end

      should "work" do
        @user.invite!(User::Levels::CONTRIBUTOR)
        @user.reload
        assert_equal(User::Levels::CONTRIBUTOR, @user.level)
      end

      should "not allow invites up to janitor level or beyond" do
        @user.invite!(User::Levels::JANITOR)
        @user.reload
        assert_equal(User::Levels::MEMBER, @user.level)
      end

      should "create a mod action" do
        assert_difference("ModAction.count") do
          @user.invite!(User::Levels::CONTRIBUTOR)
        end
        assert_equal("#{@user.name} level changed Member -> Contributor by #{CurrentUser.name}", ModAction.last.description)
      end
    end

    should "not validate if the originating ip address is banned" do
      FactoryGirl.create(:ip_ban)
      user = FactoryGirl.build(:user)
      user.save
      assert(user.errors.any?)
      assert_equal("IP address is banned", user.errors.full_messages.join)
    end

    should "limit post uploads" do
      assert(!@user.can_upload?)
      @user.update_column(:level, User::Levels::CONTRIBUTOR)
      assert(@user.can_upload?)
      @user.update_column(:level, User::Levels::MEMBER)

      40.times do
        FactoryGirl.create(:post, :uploader => @user, :is_deleted => true)
      end

      assert(!@user.can_upload?)
    end

    should "limit comment votes" do
      Danbooru.config.stubs(:member_comment_time_threshold).returns(1.week.from_now)
      Danbooru.config.stubs(:member_comment_limit).returns(10)
      assert(@user.can_comment_vote?)
      10.times do
        comment = FactoryGirl.create(:comment)
        FactoryGirl.create(:comment_vote, :comment_id => comment.id)
      end

      assert(!@user.can_comment_vote?)
      CommentVote.update_all("created_at = '1990-01-01'")
      assert(@user.can_comment_vote?)
    end

    should "limit comments" do
      assert(!@user.can_comment?)
      @user.update_column(:level, User::Levels::PRIVILEGED)
      assert(@user.can_comment?)
      @user.update_column(:level, User::Levels::MEMBER)
      @user.update_column(:created_at, 1.year.ago)
      assert(@user.can_comment?)
      assert(!@user.is_comment_limited?)
      (Danbooru.config.member_comment_limit).times do
        FactoryGirl.create(:comment)
      end
      assert(@user.is_comment_limited?)
    end

    should "verify" do
      assert(@user.is_verified?)
      @user = FactoryGirl.create(:user)
      @user.generate_email_verification_key
      @user.save
      assert(!@user.is_verified?)
      assert_raise(User::Error) {@user.verify!("bbb")}
      assert_nothing_raised {@user.verify!(@user.email_verification_key)}
      assert(@user.is_verified?)
    end

    should "authenticate" do
      assert(User.authenticate(@user.name, "password"), "Authentication should have succeeded")
      assert(!User.authenticate(@user.name, "password2"), "Authentication should not have succeeded")
      assert(User.authenticate_hash(@user.name, User.sha1("password")), "Authentication should have succeeded")
      assert(!User.authenticate_hash(@user.name, User.sha1("xxx")), "Authentication should not have succeeded")
    end

    should "normalize its level" do
      user = FactoryGirl.create(:user, :level => User::Levels::ADMIN)
      assert(user.is_moderator?)
      assert(user.is_janitor?)
      assert(user.is_contributor?)
      assert(user.is_privileged?)

      user = FactoryGirl.create(:user, :level => User::Levels::MODERATOR)
      assert(!user.is_admin?)
      assert(user.is_moderator?)
      assert(user.is_janitor?)
      assert(user.is_contributor?)
      assert(user.is_privileged?)

      user = FactoryGirl.create(:user, :level => User::Levels::JANITOR)
      assert(!user.is_admin?)
      assert(!user.is_moderator?)
      assert(user.is_janitor?)
      assert(user.is_contributor?)
      assert(user.is_privileged?)

      user = FactoryGirl.create(:user, :level => User::Levels::CONTRIBUTOR)
      assert(!user.is_admin?)
      assert(!user.is_moderator?)
      assert(!user.is_janitor?)
      assert(user.is_contributor?)
      assert(user.is_privileged?)

      user = FactoryGirl.create(:user, :level => User::Levels::PRIVILEGED)
      assert(!user.is_admin?)
      assert(!user.is_moderator?)
      assert(!user.is_janitor?)
      assert(!user.is_contributor?)
      assert(user.is_privileged?)

      user = FactoryGirl.create(:user)
      assert(!user.is_admin?)
      assert(!user.is_moderator?)
      assert(!user.is_janitor?)
      assert(!user.is_contributor?)
      assert(!user.is_privileged?)
    end

    context "name" do
      should "be #{Danbooru.config.default_guest_name} given an invalid user id" do
        assert_equal(Danbooru.config.default_guest_name, User.id_to_name(-1))
      end

      should "be fetched given a user id" do
        @user = FactoryGirl.create(:user)
        assert_equal(@user.name, User.id_to_name(@user.id))
      end

      should "be updated" do
        @user = FactoryGirl.create(:user)
        @user.update_attribute(:name, "danzig")
        assert_equal(@user.name, User.id_to_name(@user.id))
      end
    end

    context "ip address" do
      setup do
        @user = FactoryGirl.create(:user)
      end

      context "in the json representation" do
        should "not appear" do
          assert(@user.to_json !~ /addr/)
        end
      end

      context "in the xml representation" do
        should "not appear" do
          assert(@user.to_xml !~ /addr/)
        end
      end
    end

    context "password" do
      should "match the cookie hash" do
        @user = FactoryGirl.create(:user)
        @user.password = "zugzug5"
        @user.password_confirmation = "zugzug5"
        @user.save
        @user.reload
        assert(User.authenticate_cookie_hash(@user.name, @user.bcrypt_cookie_password_hash))
      end

      should "match the confirmation" do
        @user = FactoryGirl.create(:user)
        @user.old_password = "password"
        @user.password = "zugzug5"
        @user.password_confirmation = "zugzug5"
        @user.save
        @user.reload
        assert(User.authenticate(@user.name, "zugzug5"), "Authentication should have succeeded")
      end

      should "fail if the confirmation does not match" do
        @user = FactoryGirl.create(:user)
        @user.password = "zugzug6"
        @user.password_confirmation = "zugzug5"
        @user.save
        assert_equal(["Password doesn't match confirmation"], @user.errors.full_messages)
      end

      should "not be too short" do
        @user = FactoryGirl.create(:user)
        @user.password = "x5"
        @user.password_confirmation = "x5"
        @user.save
        assert_equal(["Password is too short (minimum is 5 characters)"], @user.errors.full_messages)
      end

      should "should be reset" do
        @user = FactoryGirl.create(:user)
        new_pass = @user.reset_password
        assert(User.authenticate(@user.name, new_pass), "Authentication should have succeeded")
      end

      should "not change the password if the password and old password are blank" do
        @user = FactoryGirl.create(:user, :password => "67890")
        @user.update_attributes(:password => "", :old_password => "")
        assert(@user.bcrypt_password == User.sha1("67890"))
      end

      should "not change the password if the old password is incorrect" do
        @user = FactoryGirl.create(:user, :password => "67890")
        @user.update_attributes(:password => "12345", :old_password => "abcdefg")
        assert(@user.bcrypt_password == User.sha1("67890"))
      end

      should "not change the password if the old password is blank" do
        @user = FactoryGirl.create(:user, :password => "67890")
        @user.update_attributes(:password => "12345", :old_password => "")
        assert(@user.bcrypt_password == User.sha1("67890"))
      end

      should "change the password if the old password is correct" do
        @user = FactoryGirl.create(:user, :password => "67890")
        @user.update_attributes(:password => "12345", :old_password => "67890")
        assert(@user.bcrypt_password == User.sha1("12345"))
      end

      context "in the json representation" do
        setup do
          @user = FactoryGirl.create(:user)
        end

        should "not appear" do
          assert(@user.to_json !~ /password/)
        end
      end

      context "in the xml representation" do
        setup do
          @user = FactoryGirl.create(:user)
        end

        should "not appear" do
          assert(@user.to_xml !~ /password/)
        end
      end
    end
  end
end
