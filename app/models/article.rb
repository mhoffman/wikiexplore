class Article < ActiveRecord::Base
    has_many :dislikes
    has_many :disliking_users, through: :article_dislikes
end
