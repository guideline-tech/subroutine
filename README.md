# Subroutine

A gem that provides an interface for creating feature-driven operations. You've probably heard at least one of these terms: "service objects", "form objects", "intentions", or "commands". Subroutine calls these "ops" and really it's just about enabling clear, concise, testable, and meaningful code.

## Example

So you need to sign up a user? or maybe update one's account? or change a password? or maybe you need to sign up a business along with a user, associate them, send an email, and queue a worker in a single request? Not a problem, create an op for any of these use cases. Here's the signup example.

```ruby
class SignupOp < ::Subroutine::Op

  string :name
  string :email
  string :password

  string :company_name

  validates :name, presence: true
  validates :email, presence: true
  validates :password, presence: true
  validates :company_name, presence: true

  outputs :user
  outputs :business, type: Business # validate that output type is an instance of Business

  protected

  def perform
    u = create_user!
    b = create_business!(u)

    deliver_welcome_email(u)

    output :user, u
    output :business, b
  end

  def create_user!
    User.create!(name: name, email: email, password: password)
  end

  def create_business!(owner)
    Business.create!(company_name: company_name, owner: owner)
   end

  def deliver_welcome_email(u)
    UserMailer.welcome(u.id).deliver_later
  end
end
```

## So why use this?

- Avoid cluttering models or controllers with logic only applicable to one intention. You also don't need strong parameters because the inputs to the Op are well-defined.
- Test the Op in isolation
- Clear and concise intention in a single file
- Multi-model operations become simple

## Continue Reading

- [Implementing an Op](https://github.com/guideline-tech/subroutine/wiki/Implementing-an-Op)
- [Using an Op](https://github.com/guideline-tech/subroutine/wiki/Using-an-Op)
- [Errors](https://github.com/guideline-tech/subroutine/wiki/Errors)
- [Basic Usage in Rails](https://github.com/guideline-tech/subroutine/wiki/Rails-Usage)
