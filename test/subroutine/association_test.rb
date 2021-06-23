# frozen_string_literal: true

require "test_helper"

module Subroutine
  class AssociationTest < TestCase

    def doug
      @doug ||= ::User.new(id: 1, email_address: "doug@example.com")
    end

    def fred
      @fred ||= ::User.new(id: 2, email_address: "fred@example.com")
    end

    def account
      @account ||= ::Account.new(id: 1)
    end

    def test_it_sets_accessors_on_init
      op = SimpleAssociationOp.new user: doug
      assert_equal "User", op.user_type
      assert_equal doug.id, op.user_id
    end

    def test_it_can_be_nil
      op = SimpleAssociationOp.new user: nil
      assert_nil op.user
      assert_nil op.user_id

      op = SimpleAssociationOp.new
      assert_nil op.user
      assert_nil op.user_id
    end

    def test_it_looks_up_an_association
      all_mock = mock

      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:find_by!).with(id: 1).returns(doug)

      op = SimpleAssociationOp.new user_type: "User", user_id: doug.id
      assert_equal doug, op.user
    end

    def test_it_sanitizes_types
      all_mock = mock

      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:find_by!).with(id: 1).returns(doug)

      op = SimpleAssociationOp.new user_id: doug.id
      assert_equal doug, op.user
    end

    def test_it_allows_an_association_to_be_looked_up_without_default_scoping
      all_mock = mock
      unscoped_mock = mock

      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:unscoped).returns(unscoped_mock)
      unscoped_mock.expects(:find_by!).with(id: 1).returns(doug)

      op = UnscopedSimpleAssociationOp.new user_id: doug.id
      assert_equal doug, op.user
    end

    def test_it_allows_polymorphic_associations
      all_mock = mock
      ::User.expects(:all).never
      ::AdminUser.expects(:all).returns(all_mock)
      all_mock.expects(:find_by!).with(id: 1).returns(doug)

      op = PolymorphicAssociationOp.new(admin_type: "AdminUser", admin_id: doug.id)
      assert_equal doug, op.admin
    end

    def test_it_allows_the_class_to_be_set
      op = ::AssociationWithClassOp.new(admin: doug)
      assert_equal "AdminUser", op.admin_type
    end

    def test_it_allows_foreign_key_to_be_set
      all_mock = mock
      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:find_by!).with(id: "foobarbaz").returns(doug)

      op = ::AssociationWithForeignKeyOp.new(user_identifier: "foobarbaz")
      assert_equal doug, op.user
      assert_equal "user_identifier", op.field_configurations[:user][:foreign_key]
    end

    def test_it_allows_a_foreign_key_and_find_by_to_be_set
      all_mock = mock
      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:find_by!).with(email_address: doug.email_address).returns(doug)

      op = ::AssociationWithFindByAndForeignKeyOp.new(email_address: doug.email_address)
      assert_equal doug, op.user
      assert_equal "email_address", op.field_configurations[:user][:find_by]
    end

    def test_it_allows_a_find_by_to_be_set
      all_mock = mock
      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:find_by!).with(email_address: doug.email_address).returns(doug)

      op = ::AssociationWithFindByKeyOp.new(user_id: doug.email_address)
      assert_equal doug, op.user
      assert_equal "email_address", op.field_configurations[:user][:find_by]
    end

    def test_values_are_correct_for_find_by_usage
      op = ::AssociationWithFindByKeyOp.new(user: doug)
      assert_equal doug, op.user
      assert_equal doug.email_address, op.user_id
    end

    def test_values_are_correct_for_foreign_key_usage
      op = ::AssociationWithForeignKeyOp.new(user: doug)
      assert_equal doug, op.user
      assert_equal doug.id, op.user_identifier
    end

    def test_values_are_correct_for_both_foreign_key_and_find_by_usage
      op = ::AssociationWithFindByAndForeignKeyOp.new(user: doug)
      assert_equal doug, op.user
      assert_equal doug.email_address, op.email_address
      assert_equal false, op.respond_to?(:user_id)
    end

    def test_it_inherits_associations_via_fields_from
      all_mock = mock

      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:find_by!).with(id: 1).returns(doug)

      op = ::InheritedSimpleAssociation.new(user_type: "User", user_id: doug.id)
      assert_equal doug, op.user
      assert_equal "User", op.user_type
      assert_equal doug.id, op.user_id
    end

    def test_it_inherits_associations_via_fields_from_and_preserves_options
      all_mock = mock
      unscoped_mock = mock

      ::User.expects(:all).returns(all_mock)
      all_mock.expects(:unscoped).returns(unscoped_mock)
      unscoped_mock.expects(:find_by!).with(id: 1).returns(doug)

      op = ::InheritedUnscopedAssociation.new(user_type: "User", user_id: doug.id)
      assert_equal doug, op.user
      assert_equal "User", op.user_type
      assert_equal doug.id, op.user_id
    end

    def test_it_inherits_polymorphic_associations_via_fields_from
      all_mock = mock
      ::User.expects(:all).never
      ::AdminUser.expects(:all).returns(all_mock)
      all_mock.expects(:find_by!).with(id: 1).returns(doug)

      op = ::InheritedPolymorphicAssociationOp.new(admin_type: "AdminUser", admin_id: doug.id)
      assert_equal doug, op.admin
      assert_equal "AdminUser", op.admin_type
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

    def test_it_ensures_the_correct_type_of_resource_is_provded_to_an_association
      op = SimpleAssociationOp.new
      assert_raises ::Subroutine::AssociationFields::AssociationTypeMismatchError do
        op.user = account
      end
    end

    def test_params_does_not_contain_association_key_if_not_provided
      op = SimpleAssociationOp.new
      assert_equal [], op.params.keys
    end

    def test_getting_does_not_set_provided
      op = SimpleAssociationOp.new
      op.user
      assert_equal false, op.field_provided?(:user)
      assert_equal false, op.field_provided?(:user_id)
      assert_equal false, op.field_provided?(:user_type)

      op.user_id
      assert_equal false, op.field_provided?(:user)
      assert_equal false, op.field_provided?(:user_id)
      assert_equal false, op.field_provided?(:user_type)

      op.user_type
      assert_equal false, op.field_provided?(:user)
      assert_equal false, op.field_provided?(:user_id)
      assert_equal false, op.field_provided?(:user_type)
    end

    def test_association_class_names_can_be_declared_as_classes
      klass = Class.new(OpWithAssociation) do
        association :user, class_name: Account
      end

      account = ::Account.new(id: 1)
      op = klass.new(user: account)
      assert_equal account, op.user
    end

    def test_params_only_contain_the_id_and_type_of_associations
      user = ::User.new(id: 1)
      op = SimpleAssociationOp.new(user: user)
      op.user
      assert_equal({ "user_id" => 1 }, op.params)

      op = PolymorphicAssociationOp.new(admin: user)
      op.admin
      assert_equal({ "admin_id" => 1, "admin_type" => "User" }, op.params)
    end

    def test_params_can_be_accessed_with_associations_loaded
      user = User.new(id: 1)
      op = SimpleAssociationOp.new(user: user)

      assert_equal({ "user_id" => 1 }, op.params)
      assert_equal({ "user" => user }, op.params_with_associations)

      op = PolymorphicAssociationOp.new(admin: user)
      assert_equal({ "admin_id" => 1, "admin_type" => "User" }, op.params)
      assert_equal({ "admin" => user }, op.params_with_associations)
    end

    def test_groups_are_preserved_to_association_components
      user = ::User.new(id: 1)
      op = GroupedParamAssociationOp.new(user: user)
      assert_equal({ "user_id" => 1 }, op.params)
      assert_equal({ "user_id" => 1 }, op.info_params)
      assert_equal({}, op.without_info_params)

      op = GroupedPolymorphicParamAssociationOp.new(user: user)
      assert_equal({ "user_id" => 1, "user_type" => "User" }, op.params)
      assert_equal({ "user_id" => 1, "user_type" => "User" }, op.info_params)
      assert_equal({}, op.without_info_params)
    end

  end
end
