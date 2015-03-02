# Subroutine

A gem that provides an interface for creating feature-driven operations. It loosly implements the command pattern if you're interested in nerding out a bit. See the examples below, it'll be more clear.

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
    User.new(filtered_params)
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
```ruby
# When ops are around, the point of the model is to ensure the data entering the db is 100% valid.
# So most of your models are a series of validations and common accessors, queries, etc.
class User
  validates :name, presence: true
  validates :email, email: true

  has_secure_password
end
```

#### Controller(s)
```ruby
# I've found that a great way to handle errors with ops is to allow you top level controller to appropriately
# render errors in a consisent way. This is exceptionally easy for api-driven apps.
class Api::Controller < ApplicationController
  rescue_from ::Subroutine::Failure, with: :render_op_failure

  def render_op_failure(e)
    # however you want to do this, `e` will be similar to an ActiveRecord::RecordInvalid error
    # e.record.errors, etc
  end
end

# With ops, your controllers are essentially just connections between routes, operations, and templates.
class UsersController < ::Api::Controller
  def sign_up
    # If the op fails, a ::Subroutine::Failure will be raised.
    op = SignupOp.submit!(params)

    # If the op succeeds, it will be returned so you can access it's information.
    render json: op.signed_up_user
  end
end
```

## Usage

Both the `Subroutine::Op` class and it's instances provide `submit` and `submit!` methods with identical signatures. Here are ways to invoke an op:

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

#### Fluff

Ops have some fluff. Let's see if we can cover it all with one example. I'll pretend I'm using ActiveRecord:

```ruby
class ActivateOp < ::Subroutine::Op

  # This will inherit all fields, error mappings, and default values from the SignupOp class.
  # It currently does not inherit validations
  inputs_from ::SignupOp

  # This defines new inputs for this op.
  field :invitation_token
  field :thank_you_message

  # This maps any "inherited" errors to the op's input.
  # So if one of our objects that we inherit errors from has an email_address error, it will end up on our errors as "email".
  error_map email_address: :email

  # If you wanted default values, they can be declared a couple different ways:
  # default thank_you_message: "Thanks so much"
  # field thank_you_message: "Thanks so much"
  # field :thank_you_message, default: "Thanks so much"

  # If your default values need to be evaluated at runtime, simply wrap them in a proc:
  # default thank_you_message: -> { I18n.t('thank_you') }

  # Validations are declared just like any other ActiveModel
  validates :token, presence: true
  validate :validate_invitation_available

  protected

  # This is where the actual operation takes place.
  def perform
    user = nil

    # Jump into a transaction to make sure any failure rolls back all changes.
    ActiveRecord::Base.transaction do
      user = create_user!
      associate_invitation!(user)
    end

    # Set our "success" accessors.
    @activated_user = user

    # Return a truthy value to declare success.
    true
  end

  # Use an existing op! OMG SO DRY
  # You have access to the original inputs via original_params
  def create_user!
    op = ::SignupOp.submit!(original_params)
    op.signed_up_user
  end

  # Deal with our invitation after our user is saved.
  def associate_invitation!(user)
    _invitation.user_id = user.id
    _invitation.thank_you_message = defaulted_thank_you_message
    _invitation.convert!
  end

  # Build a default value if the user didn't provide one.
  def defaulted_thank_you_message
    # You can check to see if a specific field was provided via field_provided?()
    return thank_you_message if field_provided?(:thank_you_message)
    thank_you_message.presence || I18n.t('thanks')
  end

  # Fetch the invitation via the provided token.
  def _invitation
    return @_invitation if defined?(@_invitation)
    @_invitation = token ? ::Invitation.find_by(token: token) : nil
  end

  # Verbosely validate the existence of the invitation.
  # In most cases, these validations can be written simpler.
  # The true/false return value is a style I like but not required.
  def validate_invitation_available

    # The other validation has already added a message for a blank token.
    return true if token.blank?

    # Ensure we found an invitation matching the token.
    # We could have used find_by!() in `_invitation` as well.
    unless _invitation.present?
      errors.add(:token, :not_found)
      return false
    end

    # Ensure the token is valid.
    unless _invitation.can_be_converted?
      errors.add(:token, :not_convertable)
      return false
    end

    true
  end

end
```

### Extending Subroutine::Op

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

Great, so now I can pass the current user as my first argument to any op constructor. The next most common case is permissions. In a common role-based system things become pretty easy. I usually just add a class method which declares the minimum required role.

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

## Todo

1. Enable ActiveModel 3.0-3.2 users by removing the ActiveModel::Model dependency.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/subroutine/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
