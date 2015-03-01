# Subroutine

A gem that provides an interface for creating feature-driven operations. See the examples below, it'll be more clear.

## Usage

So you need to sign up a user? or maybe update one's account? or change a password? Not a problem, create an op for any of these use cases. Here's the signup example.

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
    User.new do |u|
      u.name = name
      u.email = email
      u.password = u.password
    end
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
    # If the op fails, an ::Subroutine::Failure will be raised.
    op = SignupOp.submit!(params)

    # If the op succeeds, it will be returned so you can access it's information.
    render json: op.signed_up_user
  end
end
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/subroutine/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
