FactoryGirl.define do
  factory(:note) do
    creator :factory => :user
    post
    x 1
    y 1
    width 1
    height 1
    is_active true
    body {Faker::Lorem.sentences.join(" ")}
    updater_id :factory => :user
    updater_ip_addr "127.0.0.1"
  end
end
