# frozen_string_literal: true

require 'test_helper'

module Subroutine
  class AuthTest < TestCase
    def doug
      @doug ||= ::User.new(id: 1, email_address: 'doug@example.com')
    end

    def fred
      @fred ||= ::User.new(id: 2, email_address: 'fred@example.com')
    end

    def test_it_sets_accessors_on_init
      op = SimpleAssociationOp.new user: doug
      assert_equal 'User', op.user_type
      assert_equal doug.id, op.user_id
    end

    def test_it_looks_up_an_association
      all_mock = mock

      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:find).with(1).returns(doug)

      op = SimpleAssociationOp.new user_type: 'User', user_id: doug.id
      assert_equal doug, op.user
    end

    def test_it_sanitizes_types
      all_mock = mock

      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:find).with(1).returns(doug)

      op = SimpleAssociationOp.new user_type: 'users', user_id: doug.id
      assert_equal doug, op.user
    end

    def test_it_allows_an_association_to_be_looked_up_without_default_scoping
      all_mock = mock
      unscoped_mock = mock

      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:unscoped).returns(unscoped_mock)
      unscoped_mock.expects(:find).with(1).returns(doug)

      op = UnscopedSimpleAssociationOp.new user_type: 'User', user_id: doug.id
      assert_equal doug, op.user
    end

    def test_it_allows_polymorphic_associations
      all_mock = mock
      ::User.expects(:all).never
      ::AdminUser.expects(:all).returns(all_mock)
      all_mock.expects(:find).with(1).returns(doug)

      op = PolymorphicAssociationOp.new(admin_type: 'AdminUser', admin_id: doug.id)
      assert_equal doug, op.admin
    end

    def test_it_allows_the_class_to_be_set
      op = ::AssociationWithClassOp.new(admin: doug)
      assert_equal 'AdminUser', op.admin_type
    end

    def test_it_inherits_associations_via_inputs_from
      all_mock = mock

      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:find).with(1).returns(doug)

      op = ::InheritedSimpleAssociation.new(user_type: 'User', user_id: doug.id)
      assert_equal doug, op.user
      assert_equal 'User', op.user_type
      assert_equal doug.id, op.user_id
    end

    def test_it_inherits_associations_via_inputs_from_and_preserves_options
      all_mock = mock
      unscoped_mock = mock

      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:unscoped).returns(unscoped_mock)
      unscoped_mock.expects(:find).with(1).returns(doug)

      op = ::InheritedUnscopedAssociation.new(user_type: 'User', user_id: doug.id)
      assert_equal doug, op.user
      assert_equal 'User', op.user_type
      assert_equal doug.id, op.user_id
    end

    def test_it_inherits_polymorphic_associations_via_inputs_from
      all_mock = mock
      ::User.expects(:all).never
      ::AdminUser.expects(:all).returns(all_mock)
      all_mock.expects(:find).with(1).returns(doug)

      op = ::InheritedPolymorphicAssociationOp.new(admin_type: 'AdminUser', admin_id: doug.id)
      assert_equal doug, op.admin
      assert_equal 'AdminUser', op.admin_type
      assert_equal doug.id, op.admin_id
    end

    def test_it_provides_answers_to_field_provided
      ::User.expects(:all).never

      op = SimpleAssociationOp.new user: doug
      assert_equal true, op.field_provided?(:user)
      assert_equal true, op.field_provided?(:user_id)
      assert_equal false, op.field_provided?(:user_type)

      op = SimpleAssociationOp.new user_id: doug.id
      assert_equal true, op.field_provided?(:user)
      assert_equal true, op.field_provided?(:user_id)
      assert_equal false, op.field_provided?(:user_type)

      op = SimpleAssociationOp.new
      assert_equal false, op.field_provided?(:user)
      assert_equal false, op.field_provided?(:user_id)
      assert_equal false, op.field_provided?(:user_type)

      op = PolymorphicAssociationOp.new admin: doug
      assert_equal true, op.field_provided?(:admin)
      assert_equal true, op.field_provided?(:admin_id)
      assert_equal true, op.field_provided?(:admin_type)

      op = PolymorphicAssociationOp.new admin_type: doug.class.name, admin_id: doug.id
      assert_equal true, op.field_provided?(:admin)
      assert_equal true, op.field_provided?(:admin_id)
      assert_equal true, op.field_provided?(:admin_type)

      op = PolymorphicAssociationOp.new admin_id: doug.id
      assert_equal false, op.field_provided?(:admin)
      assert_equal true, op.field_provided?(:admin_id)
      assert_equal false, op.field_provided?(:admin_type)

      op = PolymorphicAssociationOp.new
      assert_equal false, op.field_provided?(:admin)
      assert_equal false, op.field_provided?(:admin_id)
      assert_equal false, op.field_provided?(:admin_type)

    end
  end
end
