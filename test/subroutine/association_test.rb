require 'test_helper'

module Subroutine
  class AuthTest < TestCase

    def doug
      @doug ||= ::User.new(id: 1, email_address: "doug@example.com")
    end

    def fred
      @fred ||= ::User.new(id: 2, email_address: "fred@example.com")
    end

    def test_it_sets_accessors_on_init
      op = SimpleAssociationOp.new user: doug
      assert_equal "User", op.user_type
      assert_equal doug.id, op.user_id
    end

    def test_it_looks_up_an_association
      all_mock = mock

      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:find).with(1).returns(doug)

      op = SimpleAssociationOp.new user_type: "User", user_id: doug.id
      assert_equal doug, op.user
    end

    def test_it_allows_an_association_to_be_looked_up_without_default_scoping
      all_mock = mock
      unscoped_mock = mock

      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:unscoped).returns(unscoped_mock)
      unscoped_mock.expects(:find).with(1).returns(doug)

      op = UnscopedSimpleAssociationOp.new user_type: "User", user_id: doug.id
      assert_equal doug, op.user
    end

    def test_it_allows_polymorphic_associations
      all_mock = mock
      ::User.expects(:all).never
      ::AdminUser.expects(:all).returns(all_mock)
      all_mock.expects(:find).with(1).returns(doug)

      op = PolymorphicAssociationOp.new(admin_type: "AdminUser", admin_id: doug.id)
      assert_equal doug, op.admin
    end

    def test_it_allows_the_class_to_be_set
      op = ::AssociationWithClassOp.new(admin: doug)
      assert_equal "AdminUser", op.admin_type
    end

  end
end
