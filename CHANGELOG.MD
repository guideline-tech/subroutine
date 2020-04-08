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

ActionController::Parameters from Rails 5+ are now transformed to as hash in `Subroutine::Fields` by default. This means strong parameters are essentially unused when passing `Subroutine::Fields`.

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
