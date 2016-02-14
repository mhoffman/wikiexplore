class Category < ActiveRecord::Base
    has_many :propensities
    has_many :users, through: :propensities
end
