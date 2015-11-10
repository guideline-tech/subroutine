# Subroutine

A gem that provides an interface for creating feature-driven operations. It utilizes the command pattern, enables the usage of "ops" as "form objects", and just all-around enables clear, concise, meaningful code.

## Examples

So you need to sign up a user? or maybe update one's account? or change a password? or maybe you need to sign up a business along with a user, associate them, send an email, and queue a worker in a single request? Not a problem, create an op for any of these use cases. Here's the signup example.

```ruby
class SignupOp < ::Subroutine::Op

  field :name
  field :email
  field :password

  validates :name, presence: true
  validates :email, presence: true
  validates :password, presence: true

  attr_reader :signed_up_user

  protected

  def perform
    u = build_user
    u.save!

    deliver_welcome_email!(u)

    @signed_up_user = u
    true
  end

  def build_user
    User.new(params)
  end

  def deliver_welcome_email!(u)
    UserMailer.welcome(u.id).deliver_later
  end
end
```

So why is this needed?

1. No insane cluttering of controllers with strong parameters, etc.
2. No insane cluttering of models with validations, callbacks, and random methods that don't relate to integrity or access of model data.
3. Insanely testable.
4. Insanely easy to read and maintain.
5. Multi-model operations become insanely easy.
6. Your sanity.

### Connecting it all

```txt
app/
  |
  |- controllers/
  |  |- users_controller.rb
  |
  |- models/
  |  |- user.rb
  |
  |- ops/
     |- signup_op.rb

```

#### Route
```ruby
  resources :users, only: [] do
    collection do
      post :signup
    end
  end
```

#### Model

When ops are around, the point of the model is to ensure data validity. That's essentially it.
So most of your models are a series of validations, common accessors, queries, etc.

```ruby
class User
  validates :name,   presence: true
  validates :email,     email: true

  has_secure_password
end
```

#### Controller(s)

I've found that a great way to handle errors with ops is to allow you top level controller to appropriately
render errors in a consisent way. This is exceptionally easy for api-driven apps.


```ruby
class Api::Controller < ApplicationController
  rescue_from ::Subroutine::Failure, with: :render_op_failure

  def render_op_failure(e)
    # however you want to do this, `e` will be similar to an ActiveRecord::RecordInvalid error
    # e.record.errors, etc
  end
end
```

With ops, your controllers are essentially just connections between routes, operations, and templates.

```ruby
class UsersController < ::Api::Controller
  def sign_up

    # If the op fails, a ::Subroutine::Failure will be raised.
    op = SignupOp.submit!(params)

    # If the op succeeds, it will be returned so you can access it's information.
    render json: op.signed_up_user
  end
end
```
## Op Implementation

Ops have some fluff, but not much. The `Subroutine::Op` class' entire purpose in life is to validate user input and execute
a series of operations. To enable this we filter input params, type cast params (if desired), and execute validations. Only
after these things are complete will the `Op` perform it's operation.

#### Input Declaration

Inputs are declared via the `field` method and have just a couple of options:

```ruby
class MyOp < ::Subroutine::Op
  field :first_name
  field :age, type: :integer
  field :subscribed, type: :boolean, default: false
  # ...
end
```

* **type** - declares the type which the input should be cast to. Available types are declared in `Subroutine::TypeCaster::TYPES`
* **default** - the default value of the input if not otherwise provided. If the provided default responds to `call` (ie. proc, lambda) the result of that `call` will be used at runtime.
* **aka** - an alias (or aliases) that is checked when errors are inherited from other objects.

Since we like a clean & simple dsl, you can also declare inputs via the `values` of `Subroutine::TypeCaster::TYPES`. When declared
this way, the `:type` option is assumed.

```ruby
class MyOp < ::Subroutine::Op
  string :first_name
  date :dob
  boolean :tos, :default => false
end
```

Since ops can use other ops, sometimes it's nice to explicitly state the inputs are valid. To "inherit" all the inputs from another op, simply use `inputs_from`.

```ruby
class MyOp < ::Subroutine::Op
  string :token
  inputs_from MyOtherOp

  protected

  def perform
    verify_token!
    MyOtherOp.submit! params.except(:token)
  end

end
```

#### Validations

Since Ops include ActiveModel::Model, validations can be used just like any other ActiveModel object.

```ruby
class MyOp < ::Subroutine::Op
  field :first_name

  validates :first_name, presence: true
end
```

#### Input Usage

Inputs are accessible within the op via public accessors. You can see if an input was provided via the `field_provided?` method.

```ruby
class MyOp < ::Subroutine::Op

  field :first_name
  validate :validate_first_name_is_not_bob

  protected

  def perform
   # whatever this op does
   true
  end

  def validate_first_name_is_not_bob
    return true unless field_provided?(:first_name)

    if first_name.downcase == 'bob'
      errors.add(:first_name, 'should not be bob')
      return false
    end

    true
  end
end
```

#### Execution

Every op must implement a `perform` instance method. This is the method which will be executed if all validations pass.
The return value of this op determines whether the operation was a success or not. Truthy values are assumed to be successful,
while falsy values are assumed to be failures. In general, returning `true` at the end of the perform method is desired.

```ruby
class MyOp < ::Subroutine::Op
  field :first_name
  validates :first_name, presence: true

  protected

  def perform
    $logger.info "#{first_name} submitted this op"
    true
  end

end
```

Notice we do not declare `perform` as a public method. This is to ensure the "public" api of the op remains as `submit` or `submit!`.

#### Errors

Reporting errors is very important in Subroutine Ops since these can be used as form objects. Errors can be reported a couple different ways:

1. `errors.add(:key, :error)` That is, the way you add errors to an ActiveModel object. Then either return false from your op OR raise an error like `raise ::Subroutine::Failure.new(this)`.
2. `inherit_errors(error_object_or_activemodel_object)` Same as `errors.add`, but it iterates an existing error hash and inherits the errors. As part of this iteration,
it checks whether the key in the provided error_object matches a field (or aka of a field) in our op. If there is a match, the error will be placed on
that field, but if there is not, the error will be placed on `:base`. Again, after adding the errors to our op, we must return `false` from the perform method or raise a Subroutine::Failure.

```ruby
class MyOp < ::Subroutine::Op

  string :first_name, aka: :firstname
  string :last_name, aka: [:lastname, :surname]

  protected

  def perform

    if first_name == 'bill'
      errors.add(:first_name, 'cannot be bill')
      return false
    end

    if first_name == 'john'
      errors.add(:first_name, 'cannot be john')
      raise Subroutine::Failure.new(this)
    end

    unless _user.valid?

      # if there are :first_name or :firstname errors on _user, they will be added to our :first_name
      # if there are :last_name, :lastname, or :surname errors on _user, they will be added to our :last_name
      inherit_errors(_user)
      return false
    end

    true
  end

  def _user
    @_user ||= User.new(params)
  end
end
```


## Usage

The `Subroutine::Op` class' `submit` and `submit!` methods have identical signatures to the class' constructor, enabling a few different ways to utilize an op:

#### Via the class' `submit` method

```ruby
op = MyOp.submit({foo: 'bar'})
# if the op succeeds it will be returned, otherwise it false will be returned.
```

#### Via the class' `submit!` method

```ruby
op = MyOp.submit!({foo: 'bar'})
# if the op succeeds it will be returned, otherwise a ::Subroutine::Failure will be raised.
```

#### Via the instance's `submit` method

```ruby
op = MyOp.new({foo: 'bar'})
val = op.submit
# if the op succeeds, val will be true, otherwise false
```

#### Via the instance's `submit!` method

```ruby
op = MyOp.new({foo: 'bar'})
op.submit!
# if the op succeeds nothing will be raised, otherwise a ::Subroutine::Failure will be raised.
```

## Extending Subroutine::Op

Great, so you're sold on using ops. Let's talk about how I usually standardize their usage in my apps. The most common thing needed is `current_user`. For this reason I usually follow the rails convention of declaring an "Application" op which declares all of my common needs. I hate writing `ApplicationOp` all the time so I usually call it `BaseOp`.

```ruby
class BaseOp < ::Subroutine::Op

  attr_reader :current_user

  def initialize(*args)
    params = args.extract_options!
    @current_user = args[0]
    super(params)
  end

end
```

So now I can pass the current user as my first argument to any op constructor. The next most common case is permissions. In a common role-based system things become pretty easy. I usually just add a class method which declares the minimum required role.

```ruby
class SendInvitationOp < BaseOp
  require_role :admin
end
```

In the case of a more complex permission system, I'll usually utilize pundit but still standardize the check as a validation.

```ruby
class BaseOp < ::Subroutine::Op

  validate :validate_permissions

  protected

  # default implementation is to allow access.
  def validate_permissions
    true
  end

  def not_authorized!
    errors.add(:current_user, :not_authorized)
    false
  end
end

class SendInvitationOp < BaseOp

  protected

  def validate_permissions
    unless UserPolicy.new(current_user).send_invitations?
      return not_authorized!
    end

    true
  end

end
```

Clearly there are a ton of ways this could be implemented but that should be a good jumping-off point.

Performance monitoring is also important to me so I've added a few hooks to observe what's going on during an op's submission. I'm primarily using Skylight at the moment.

```ruby
class BaseOp < ::Subroutine::Op

  protected

  def observe_submission
    Skylight.instrument category: 'op.submission', title: "#{self.class.name}#submit" do
      yield
    end
  end

  def observe_validation
    Skylight.instrument category: 'op.validation', title: "#{self.class.name}#valid?" do
      yield
    end
  end

  def observe_perform
    Skylight.instrument category: 'op.perform', title: "#{self.class.name}#perform" do
      yield
    end
  end
end
```

## Subroutine::Factory

There is a separate gem [subroutine-factory](https://github.com/mnelson/subroutine-factory) which enables you to easily utilize factories and operations to produce
test data. It's a great replacement to FactoryGirl, as it ensures the data entering your DB is getting there via a real
world operation.

```ruby
# support/factories/signups.rb
Subroutine::Factory.define :signup do
  op ::SignupOp

  inputs :email, sequence{|n| "foo{n}@example.com" }
  inputs :password, "password123"

  # by default, the op will be returned when the factory is used.
  # this `output` returns the value of the accessor on the resulting op
  output :user
end

# signup_test.rb
user = Subroutine::Factory.create :signup
user = Subroutine::Factory.create :signup, email: "foo@bar.com"
```
