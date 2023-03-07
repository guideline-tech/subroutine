# frozen_string_literal: true

require "subroutine/auth"
require "subroutine/association_fields"

## Models ##

class User

  include ::ActiveModel::Model

  attr_accessor :id
  attr_accessor :email_address
  attr_accessor :password

  validates :email_address, presence: true

  def self.all
    self
  end

  def self.find(id)
    new(id: id)
  end

  def self.find_by(params)
    new(params)
  end

  def self.find_by!(params)
    find_by(params) || raise
  end

  def self.type_for_attribute(attribute)
    case attribute
    when :id
      Struct.new(:type).new(:integer)
    else
      Struct.new(:type).new(:string)
    end
  end

end

class StringIdUser < ::User

  def self.type_for_attribute(attribute)
    Struct.new(:type).new(:string)
  end

end

class AdminUser < ::User

  validates :email_address, format: { with: /@admin\.com/, message: "has gotta be @admin.com" }

end

class Account

  include ::ActiveModel::Model

  attr_accessor :id

  def self.all
    self
  end

  def self.find(id)
    new(id: id)
  end

end

## Ops ##

class SignupOp < ::Subroutine::Op

  string :email, aka: :email_address
  string :password

  validates :email, presence: true
  validates :password, presence: true

  outputs :perform_called
  outputs :perform_finished

  outputs :created_user

  protected

  def perform
    output :perform_called, true
    u = build_user

    unless u.valid?
      inherit_errors(u)
      return false
    end

    output :perform_finished, true
    output :created_user, u
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

  field :privileges, default: "min"

  protected

  def user_class
    ::AdminUser
  end

end

class BusinessSignupOp < ::Subroutine::Op

  string :business_name

  fields_from ::SignupOp

end

class DefaultsOp < ::Subroutine::Op

  field :foo, default: "foo"
  field :bar, default: "bar"
  field :baz, default: false

end

class ExceptFooBarOp < ::Subroutine::Op

  fields_from ::DefaultsOp, except: %i[foo bar]

end

class OnlyFooBarOp < ::Subroutine::Op

  fields_from ::DefaultsOp, only: %i[foo bar]

end

class InheritedDefaultsOp < ::DefaultsOp

  field :bar, default: "barstool", allow_overwrite: true

end

class GroupedDefaultsOp < ::Subroutine::Op

  fields_from ::DefaultsOp, group: "inherited"

end

class TypeCastOp < ::Subroutine::Op

  integer :integer_input
  number :number_input
  decimal :decimal_input
  string :string_input
  boolean :boolean_input
  date :date_input
  time :time_input, default: -> { Time.now }
  iso_date :iso_date_input
  iso_time :iso_time_input
  object :object_input
  array :array_input, default: "foo"
  array :type_array_input, of: :integer
  file :file_input
  foreign_key :fk_input_owner_id
  foreign_key :fk_input_email_address, foreign_key_type: :string

end

class OpWithAuth < ::Subroutine::Op

  include ::Subroutine::Auth
  def perform
    true
  end

end

class MissingAuthOp < OpWithAuth
end

class RequireUserOp < OpWithAuth

  require_user!

  string :some_input

end

class RequireNoUserOp < OpWithAuth

  require_no_user!

end

class NoUserRequirementsOp < OpWithAuth

  no_user_requirements!

end

class DifferentUserClassOp < OpWithAuth

  self.user_class_name = "AdminUser"
  require_user!

end

class CustomAuthorizeOp < OpWithAuth

  require_user!
  authorize :authorize_user_is_correct

  protected

  def authorize_user_is_correct
    unauthorized! unless current_user.email_address.to_s =~ /example\.com$/ # rubocop:disable Performance/RegexpMatch
  end

end

class PolicyOp < OpWithAuth

  class FakePolicy

    def user_can_access?
      true
    end

    def user_can_do_it
      false
    end

  end

  require_user!

  policy :user_can_access?
  policy :user_can_do_it

  def policy
    @policy ||= FakePolicy.new
  end

end

class IfConditionalPolicyOp < OpWithAuth

  class FakePolicy

    def user_can_access?
      false
    end

  end

  require_user!
  boolean :check_policy
  validates :check_policy, inclusion: { in: [true, false] }
  policy :user_can_access?, if: :check_policy

  def policy
    @policy ||= FakePolicy.new
  end

end

class UnlessConditionalPolicyOp < OpWithAuth

  class FakePolicy

    def user_can_access?
      false
    end

  end

  require_user!
  boolean :unless_check_policy
  validates :unless_check_policy, inclusion: { in: [true, false] }
  policy :user_can_access?, unless: :unless_check_policy

  def policy
    @policy ||= FakePolicy.new
  end

end

class ParentInheritanceOp < ::Subroutine::Op
  class EarlyInheritanceOp < ParentInheritanceOp
    integer :debit_cents
  end

  integer :amount_cents

  class LateInheritanceOp < ParentInheritanceOp
    integer :debit_cents
  end

end

class OuterInheritanceOp < ParentInheritanceOp

  integer :credit_cents

end

class OpWithAssociation < ::Subroutine::Op

  include ::Subroutine::AssociationFields

  def perform
    false
  end

end

class SimpleAssociationOp < ::OpWithAssociation

  association :user

end

class SimpleAssociationWithStringIdOp < ::OpWithAssociation

  association :string_id_user

end

class UnscopedSimpleAssociationOp < ::OpWithAssociation

  association :user, unscoped: true, allow_overwrite: true

end

class PolymorphicAssociationOp < ::OpWithAssociation

  association :admin, polymorphic: true

end

class AssociationWithClassOp < ::OpWithAssociation

  association :admin, class_name: "AdminUser"

end

class AssociationWithForeignKeyOp < ::OpWithAssociation

  association :user, foreign_key: "owner_id"

end

class AssociationWithFindByKeyOp < ::OpWithAssociation

  association :user, find_by: "email_address", foreign_key_type: :string

end

class AssociationWithImplicitStringFindByOp < ::OpWithAssociation

  association :user, find_by: "email_address"

end

class AssociationWithFindByAndForeignKeyOp < ::OpWithAssociation

  association :user, foreign_key: "email_address", find_by: "email_address"

end

class ExceptAssociationOp < ::Subroutine::Op

  fields_from ::PolymorphicAssociationOp, except: %i[admin]

end

class OnlyAssociationOp < ::Subroutine::Op

  fields_from ::PolymorphicAssociationOp, only: %i[admin]

end

class InheritedSimpleAssociation < ::Subroutine::Op

  fields_from SimpleAssociationOp

end

class InheritedUnscopedAssociation < ::Subroutine::Op

  fields_from UnscopedSimpleAssociationOp

end

class InheritedPolymorphicAssociationOp < ::Subroutine::Op

  fields_from PolymorphicAssociationOp

end

class GroupedParamAssociationOp < ::OpWithAssociation

  association :user, group: :info

end

class GroupedPolymorphicParamAssociationOp < ::OpWithAssociation

  association :user, polymorphic: true, group: :info

end

class GroupedInputsFromOp < ::Subroutine::Op

  fields_from GroupedParamAssociationOp, group: :inherited

end

class FalsePerformOp < ::Subroutine::Op

  def perform
    false
  end

end

class ErrorTraceOp < ::Subroutine::Op

  class SomeObject

    include ::ActiveModel::Model
    include ::ActiveModel::Validations::Callbacks

    def foo
      errors.add(:base, "Failure of things")
      raise Subroutine::Failure, self
    end

    def bar
      foo
    end

  end

  class SubOp < ::Subroutine::Op

    def perform
      SomeObject.new.bar
    end

  end

  def perform
    SubOp.submit!
  end

end

class CustomFailureClassOp < ::Subroutine::Op

  class Failure < StandardError

    attr_reader :record
    def initialize(record)
      @record = record
      errors = @record.errors.full_messages.join(", ")
      super(errors)
    end

  end

  failure_class Failure

  def perform
    errors.add(:base, "Will never work")
  end

end

class PrefixedInputsOp < ::Subroutine::Op

  string :user_email_address

  def perform
    u = AdminUser.new(email_address: user_email_address)
    u.valid?
    inherit_errors(u, prefix: :user_)
  end

end
