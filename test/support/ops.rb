## Models ##

class User
  include ::ActiveModel::Model

  attr_accessor :email_address
  attr_accessor :password

  validates :email_address, :presence => true
end

class AdminUser < ::User
  validates :email_address, :format => {:with => /@admin\.com/, :message => 'has gotta be @admin.com'}
end


## Ops ##

class SignupOp < ::Opp::Base

  field :email
  field :password

  validates :email, :presence => true
  validates :password, :presence => true

  error_map :email_address => :email

  attr_reader :perform_called
  attr_reader :perform_finished

  attr_reader :created_user

  protected

  def perform
    @perform_called = true
    u = build_user

    unless u.valid?
      inherit_errors_from(u)
      return false
    end

    @perform_finished = true
    @created_user = u

    true
  end

  def build_user
    u = user_class.new
    u.email_address = email
    u.password = password
    u
  end

  def user_class
    ::User
  end
end

class AdminSignupOp < ::SignupOp

  field :priveleges, :default => 'min'

  protected

  def user_class
    ::AdminUser
  end

end

class BusinessSignupOp < ::Opp::Base

  field :business_name
  inputs_from ::SignupOp

end

class DefaultsOp < ::Opp::Base

  field :foo, :default => 'foo'

  field baz: 'baz'

  field :bar
  default :bar => 'bar'

end

class InheritedDefaultsOp < ::DefaultsOp

  default :bar => 'barstool'

end
