class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  #validates_uniqueness_of :email, :allow_blank => true

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :propensities
  has_many :categories, through: :propensities

  has_many :article_dislikes
  has_many :disliked_articles, through: :article_dislikes, :source => :article
end
