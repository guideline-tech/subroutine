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

class SignupOp < ::Subroutine::Op

  string :email, :aka => :email_address
  string :password

  validates :email, :presence => true
  validates :password, :presence => true

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

class BusinessSignupOp < ::Subroutine::Op

  string :business_name
  inputs_from ::SignupOp

end

class DefaultsOp < ::Subroutine::Op

  field :foo, :default => 'foo'
  field :bar, :default => 'bar'

end

class InheritedDefaultsOp < ::DefaultsOp

  field :bar, :default => 'barstool'

end

class TypeCastOp < ::Subroutine::Op

  integer :integer_input
  number :number_input
  string :string_input
  boolean :boolean_input
  date :date_input
  time :time_input, :default => lambda{ Time.now }
  iso_date :iso_date_input
  iso_time :iso_time_input
  object :object_input
  array :array_input, :default => 'foo'

end
