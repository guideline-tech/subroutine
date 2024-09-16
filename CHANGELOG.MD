## Subroutine 4.2.0

Common ActiveModel validations can now be passed to fields. Can pass multiple validators can be passed to the same field.

```ruby
class MyOp < Subroutine::Op

  association :user, presence: true
  string :first_name, length: { maximum: 20 }

end
```

## Subroutine 4.1.0

A field can no opt out of the natural assignment behavior of ActiveSupport::HashWithIndifferentAccess. Top level param groups are still accessible via indifferent access but if a field sets the `bypass_indifferent_assignment` option to `true` the HashWithIndifferentAccess assignment behavior will be bypassed in favor of direct Hash-like assignment.

```ruby
class MyOp < Subroutine::Op

  object :some_hash
  object :some_other_hash, bypass_indifferent_assignment: true

end
```

## Subroutine 4.0.1

Association fields can now use `find_by()` instead of `find_by!()` by passing a `raise_on_miss: false` option. This places the responsibility on the op to manage nil cases rather than handling RecordNotFound errors.

## Subroutine 4.0

The `Subroutine::Fields` module now contains a class_attribute that allows the altering of param accessor behaviors. `include_defaults_in_params` is now available to opt into including the default values in usage of the `all_params (alias params)` method. Backwards compatibility is preserved by defaulting the value to `false`. If switched to true, when an input is omitted and the field is configured with a default value, it will be included in the `all_params` object.

Removed all usage of `ungrouped` params and refactored the storage of grouped params. Params are now stored in either the provided group or the defaults group and accessed via provided_params, params, default_params, and params_with_defaults. Grouped params are accessed the same way but with the group name prefixed eg. `my_private_default_params`.

## Subroutine 3.0

Add support for Rails 6.1. Drop support for Rails 6.0 and lower.

## Subroutine 2.3

Support dynamic types for foreign keys on association fields. The class type is used at runtime to determine the casting behavior of the foreign key field.

## Subroutine 2.2

Add `type` validation for Output.

## Subroutine 2.0

The updates between 1.0 and 2.0 are relatively minor and are focused more on cleaning up the codebase and extending the use of the 0.9->1.0 refactor. There are, however, breaking changes to how associations are loaded. The association is no longer loaded via `find()` but rather `find_by!(id:)`. Given this, a major version was released.

**Note:** 2.0.0 was released with a bug and subsequently yanked. 2.0.1 is the first available 2.x version.

## Subroutine 1.0

A massive refactor took place between 0.9 and 1.0, including breaking changes. The goal was to reduce complexity, simplify backtraces, and increase the overall safety and reliability of the library.

### Subroutine::Fields

`Subroutine::Fields` was completely refactored to manage field declaration, configuration, and access in a more systematic and safer way.

`Op._fields` was removed in favor of `Op.field_configurations`. `field_configurations` is a hash with keys of the field name and values of `FieldConfiguration` objects. FieldConfiguration objects are SimpleDelegates to the underlying option hashes. They answer questions and provide a mechanism for validating the configuration of a field.

Fields can be accessed via helpers and accessors can be managed by the field declration. Helpers include `get_field`, `set_field`, and `clear_field`.

```ruby
class SomeOp < ::Subroutine::Op
  string :foo, read_accessor: field_reader: false, field_writer: true

  def perform
    self.foo = "bar"
    self.foo # NoMethodError
    self.get_field(:foo) # => "bar"
  end
end
```

Fields can be omitted from mass assignment, meaning they would not be respected via constructor signatures.

```ruby
class SomeOp < ::Subroutine::Op
  string :foo, mass_assignable: false
  def perform
    puts foo
  end
end

SomeOp.submit!(foo: "Hello World!") # raises ::Subroutine::Fields::MassAssignmentError
SomeOp.new{|op| op.foo = "Hello World!" }.submit! # prints "Hello World!"
```

This is especially useful when dealing with user input and potentially unsafe attributes.

```ruby
class UserUpdateOp < ::Op
  association :user
  string :first_name
  string :last_name
  integer :credit_balance_cents, mass_assignable: false

  def perform
    user.update(params)
  end
end

# some_controller.rb
def update
  UserUpdateOp.submit!(params.merge(user: current_user))
end
```

Field groups were added as well, allowing you to access subsets of the fields easily.

```ruby
class AccountUpdateOp < ::Op
  association :account

  with_options group: :user do
    string :first_name
    string :last_name
    date :dob
  end

  with_options group: :business do
    string :company_name
    string :ein
  end

  def perform
    account.user.update(user_params)
    account.business.update(business_params)
  end

end
```

ActionController::Parameters from Rails 5+ are now transformed to a hash in `Subroutine::Fields` by default. This means strong parameters are essentially unused when passing `Subroutine::Fields`.

Read more about field management and access in https://github.com/guideline-tech/subroutine/wiki/Param-Usage

### Subroutine::Association

The `Subroutine::Association` module has been moved to `Subroutine::AssociationFields`.

Only native types are stored in params now. The objects loaded from associations are stored in an `association_cache`. This ensures access to fields are consistent regardless of the inputs.

```ruby
class SomeOp < ::Subroutine::Op
  association :user
  association :resource, polymorphic: true
end

user = User.find(4)

op = SomeOp.new(user: user, resource: user)
op.params #=> { user_id: 4, resource_type: "User", resource_id: 4 }
op.params_with_association #=> { user: <User:103204 @id=4>, resource: <User:103204 @id=4> }

op = SomeOp.new(user_id: user.id, resource_type: "User", resource_id: user.id)
op.params #=> { user_id: 4, resource_type: "User", resource_id: 4 }
op.params_with_association #=> { user: <User:290053 @id=4>, resource: <User:29042 @id=4> }
```

Assignment of associations now validates the type. If an association is not polymorphic, the type will be validated against the expected type.
