module Admin::UsersHelper
  def user_level_select(object, field)
    options = [
      ["Member", User::Levels::MEMBER],
      ["Gold", User::Levels::PRIVILEGED],
      ["Platinum", User::Levels::PLATINUM],
      ["Builder", User::Levels::BUILDER],
      ["Contributor", User::Levels::CONTRIBUTOR],
      ["Janitor", User::Levels::JANITOR],
      ["Moderator", User::Levels::MODERATOR],
      ["Admin", User::Levels::ADMIN]
    ]
    select(object, field, options)
  end
end
