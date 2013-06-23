FactoryGirl.define do
  factory(:ip_ban) do
    creator :factory => :user
    reason {Faker::Lorem.words.join(" ")}
    ip_addr "127.0.0.1"
  end
end
