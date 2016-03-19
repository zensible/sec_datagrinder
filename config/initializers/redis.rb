$redis = Redis.new( :port => Rails.env.test? ? 6380 : 6379)
