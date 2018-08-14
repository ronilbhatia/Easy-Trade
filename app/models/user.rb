# == Schema Information
#
# Table name: users
#
#  id              :bigint(8)        not null, primary key
#  username        :string           not null
#  email           :string           not null
#  password_digest :string           not null
#  session_token   :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class User < ApplicationRecord
  validates :username, :email, :session_token, presence: true, uniqueness: true
  validates :password_digest, presence: true
  validates :password, length: { minimum: 6, allow_nil: true }

  has_many :transactions
  has_many :deposits

  after_initialize :ensure_session_token

  attr_reader :password

  def self.find_by_credentials(username, password)
    @user = User.find_by(username: username)
    return nil unless @user
    @user.is_password?(password) ? @user : nil
  end

  def password=(password)
    @password = password
    self.password_digest = BCrypt::Password.create(password)
  end

  def is_password?(password)
    BCrypt::Password.new(self.password_digest).is_password?(password)
  end

  def ensure_session_token
    self.session_token ||= SecureRandom.urlsafe_base64
  end

  def reset_session_token!
    self.session_token = SecureRandom.urlsafe_base64
    self.save!
    self.session_token
  end

  def calculate_buying_power
    buying_power = 0
    self.deposits.each { |deposit| buying_power += deposit.amount }

    self.transactions.each do |transaction|
      transaction_amount = transaction.price * transaction.num_shares
      if transaction.order_type == 'buy'
        buying_power -= transaction_amount
      else
        buying_power += transaction_amount
      end
    end

    buying_power
  end

  def calculate_stocks
    stocks = {}

    self.transactions.each do |transaction|
      curr_stock = Stock.find(transaction.stock_id)
      if stocks[curr_stock.ticker]
        if transaction.order_type == 'buy'
          stocks[curr_stock.ticker] += transaction.num_shares
        else
          stocks[curr_stock.ticker] -= transaction.num_shares
        end
      else
        if transaction.order_type == 'buy'
          stocks[curr_stock.ticker] = transaction.num_shares
        else
          stocks[curr_stock.ticker] = -transaction.num_shares
        end
      end
    end

    stocks
  end

end
