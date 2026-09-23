defmodule Ankole.WorkHierarchy.DelegationEventTest do
  use Ankole.DataCase, async: true

  alias Ankole.WorkHierarchy.DelegationEvent

  @moduledoc """
  Tests for Ankole.WorkHierarchy.DelegationEvent schema and changeset.
  """

  describe "changeset" do
    test "valid attrs produce valid changeset" do
      changeset = DelegationEvent.changeset(%DelegationEvent{}, %{
        delegation_uid: "delegation-001",
        event_type: "created"
      })

      assert changeset.valid?
    end

    test "delegation_uid is required" do
      changeset = DelegationEvent.changeset(%DelegationEvent{}, %{
        event_type: "created"
      })

      assert Enum.any?(changeset.errors, fn {:delegation_uid, _} -> true; _ -> false end)
    end

    test "event_type is required" do
      changeset = DelegationEvent.changeset(%DelegationEvent{}, %{
        delegation_uid: "delegation-001"
      })

      assert Enum.any?(changeset.errors, fn {:event_type, _} -> true; _ -> false end)
    end
  end

  describe "schema fields" do
    test "contains expected fields" do
      fields = DelegationEvent.__schema__(:fields)
      assert :id in fields
      assert :delegation_uid in fields
      assert :event_type in fields
      assert :inserted_at in fields
    end

    test "primary key is id" do
      assert DelegationEvent.__schema__(:primary_key) == [:id]
    end
  end

  describe "constraint wiring" do
    test "FK constraint on delegation_uid is wired" do
      constraints = DelegationEvent.changeset(%DelegationEvent{}, %{
        delegation_uid: "d1", event_type: "created"
      }).constraints

      assert Enum.any?(constraints, fn c -> c.field == :delegation_uid and c.type == :foreign_key end)
    end
  end

  describe "field types" do
    test "delegation_uid is stored as :string" do
      assert DelegationEvent.__schema__(:type, :delegation_uid) == :string
    end

    test "event_type is stored as :string" do
      assert DelegationEvent.__schema__(:type, :event_type) == :string
    end
  end
end
